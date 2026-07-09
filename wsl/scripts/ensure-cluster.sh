#!/bin/bash
# ensure-cluster.sh v5 — Idempotent + WAIT Docker + KUBECONFIG SEMPRE ATUALIZADO
set -o pipefail

CLUSTER_NAME="lab-sre-denoso"
KIND_CONFIG="/home/administrator/k8s-portfolio-iac/kind-config.yaml"
REPO_DIR="/home/administrator/k8s-portfolio-iac"
MAX_RETRIES=5
RETRY_DELAY=20

log() { echo "[$(date '+%H:%M:%S')] $*"; }

# ===== PASSO 0: KUBECONFIG — ESSENCIAL! A PORTA DA API MUDA A CADA RESTART =====
log "[KUBECONFIG] Atualizando para porta atual do Kind..."
kind get kubeconfig --name "${CLUSTER_NAME}" 2>/dev/null > ~/.kube/config 2>/dev/null && chmod 600 ~/.kube/config
if [ $? -ne 0 ]; then
    log "[KUBECONFIG] ERRO: Nao foi possivel obter kubeconfig — cluster pode nao existir"
else
    log "[KUBECONFIG] OK: $(grep server ~/.kube/config 2>/dev/null | head -1)"
fi

# ===== FUNCAO DE APPLY =====
apply_manifests() {
    log "[MANIFESTS] Aplicando recursos..."
    kubectl apply -f "$REPO_DIR/wsl/cluster/services/portfolio/" 2>/dev/null || true
    kubectl apply -f "$REPO_DIR/wsl/cluster/services/postgres/" 2>/dev/null || true
    kubectl create namespace monitoring 2>/dev/null || true
    kubectl apply -f "$REPO_DIR/wsl/cluster/monitoring/prometheus-manifests.yaml" 2>/dev/null || true
    kubectl apply -f "$REPO_DIR/wsl/cluster/monitoring/grafana-manifests.yaml" 2>/dev/null || true
    kubectl apply -f "$REPO_DIR/wsl/cluster/monitoring/loki-manifests.yaml" 2>/dev/null || true
    kubectl apply -f "$REPO_DIR/wsl/cluster/infrastructure/" 2>/dev/null || true
    kubectl apply -f "$REPO_DIR/wsl/cluster/security/" 2>/dev/null || true
    kubectl apply -f "$REPO_DIR/wsl/cluster/security/network-policies/" 2>/dev/null || true
    kubectl apply -f "$REPO_DIR/wsl/cluster/platform/" 2>/dev/null || true
    kubectl create secret generic postgres-secret -n default \
        --from-literal=POSTGRES_PASSWORD=postgres \
        --from-literal=POSTGRES_USER=postgres \
        --from-literal=POSTGRES_DB=portfolio 2>/dev/null || true
    kubectl create serviceaccount metrics-server -n kube-system 2>/dev/null || true
    log "[MANIFESTS] Pronto!"
    kubectl get pods -A 2>/dev/null | awk '{print $1, $2, $3}' | head -20
}

# ===== WAIT DOCKER =====
log "Aguardando Docker Engine..."
for i in $(seq 1 30); do
    if docker info &>/dev/null; then log "Docker OK"; break; fi
    if [ "$i" -eq 30 ]; then log "ERRO: Docker nao respondeu"; exit 1; fi
    sleep 2
done
sleep 3

# ===== GARANTIR RESTART POLICY =====
docker update --restart=always "${CLUSTER_NAME}-control-plane" 2>/dev/null || true

# ===== VERIFICAR CLUSTER =====
if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
    log "Cluster ${CLUSTER_NAME} existe — atualizando kubeconfig e aplicando manifests..."
    # ATUALIZAR KUBECONFIG NOVAMENTE (por precaucao)
    kind get kubeconfig --name "${CLUSTER_NAME}" > ~/.kube/config 2>/dev/null && chmod 600 ~/.kube/config
    kubectl wait --for=condition=Ready nodes --all --timeout=60s 2>/dev/null || true
    apply_manifests
    log "Cluster OK (recovery)"
    exit 0
fi

# ===== CRIAR CLUSTER =====
log "Criando cluster ${CLUSTER_NAME}..."
for attempt in $(seq 1 $MAX_RETRIES); do
    log "Tentativa $attempt de $MAX_RETRIES..."
    if kind create cluster --name "${CLUSTER_NAME}" --config "${KIND_CONFIG}" 2>&1; then
        log "Cluster criado!"
        # ATUALIZAR KUBECONFIG IMEDIATAMENTE
        kind get kubeconfig --name "${CLUSTER_NAME}" > ~/.kube/config 2>/dev/null && chmod 600 ~/.kube/config
        break
    fi
    if [ "$attempt" -eq "$MAX_RETRIES" ]; then log "ERRO: Falha apos $MAX_RETRIES tentativas"; exit 1; fi
    sleep $RETRY_DELAY
done

kubectl wait --for=condition=Ready nodes --all --timeout=120s || exit 1
sleep 5
apply_manifests
docker update --restart=always "${CLUSTER_NAME}-control-plane" 2>/dev/null || true
log "Cluster PRONTO!"
