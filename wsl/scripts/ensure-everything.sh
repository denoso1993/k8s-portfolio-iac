#!/bin/bash
set -o pipefail

CLUSTER_NAME="lab-sre-denoso"
REPO_DIR="/home/administrator/k8s-portfolio-iac"
LOG="/var/log/ensure-everything.log"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a $LOG; }

# 1. Verificar cluster
if ! kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
    log "[CLUSTER] Criando cluster..."
    cd "$REPO_DIR" && kind create cluster --name "${CLUSTER_NAME}" --config kind-config.yaml
    kubectl wait --for=condition=Ready nodes --all --timeout=120s || true
else
    log "[CLUSTER] Cluster $CLUSTER_NAME existe — verificando saude..."
    kubectl wait --for=condition=Ready nodes --all --timeout=30s 2>/dev/null || log "[CLUSTER] Aviso: node nao respondeu"
fi

# Garantir restart policy
docker update --restart=always "${CLUSTER_NAME}-control-plane" 2>/dev/null || true

# 2. Aplicar manifests (sempre, mesmo que cluster exista)
log "[MANIFESTS] Aplicando..."
for dir in infrastructure services/portfolio services/postgres security security/network-policies platform monitoring; do
    if [ -d "$REPO_DIR/wsl/cluster/$dir" ]; then
        kubectl apply -f "$REPO_DIR/wsl/cluster/$dir/" 2>>$LOG || log "[WARN] Falha em $dir"
    fi
done

# 3. Postgres secret se nao existir
if ! kubectl get secret postgres-secret -n default &>/dev/null; then
    log "[SECRET] Criando postgres-secret..."
    kubectl create secret generic postgres-secret -n default \
        --from-literal=postgres-password="postgres" \
        --from-literal=postgres-user="postgres" 2>>$LOG || log "[WARN] Secret postgres ja existe"
fi

# 4. metrics-server ServiceAccount se nao existir
if ! kubectl get serviceaccount metrics-server -n kube-system &>/dev/null; then
    log "[METRICS] Criando ServiceAccount metrics-server..."
    kubectl create serviceaccount metrics-server -n kube-system 2>>$LOG || true
    kubectl apply -f "$REPO_DIR/wsl/cluster/infrastructure/metrics-server.yaml" 2>>$LOG || log "[WARN] metrics-server manifest"
fi

# 5. Redirecionar ingress (nginx ingress controller ausente? criar se nao existir)
if ! kubectl get ingressclass nginx &>/dev/null; then
    log "[INGRESS] Instalando ingress-nginx..."
    kubectl apply -f "$REPO_DIR/wsl/cluster/infrastructure/ingress-controller.yaml" 2>>$LOG || true
fi

# 6. Ingress
kubectl apply -f "$REPO_DIR/wsl/cluster/services/portfolio/ingress-deniso.yaml" 2>>$LOG || true

# 7. ConfigMaps de HTML via apply (sem delete)
HTML_DIR="$REPO_DIR/wsl/cluster/services/portfolio/html"
if [ -f "$HTML_DIR/prod-index.html" ]; then
    kubectl create configmap nginx-html-config --from-file=index.html="$HTML_DIR/prod-index.html" -n default --dry-run=client -o yaml | kubectl apply -f - 2>>$LOG || true
fi
if [ -f "$HTML_DIR/mobile-index.html" ]; then
    kubectl create configmap mobile-html-config --from-file=index.html="$HTML_DIR/mobile-index.html" -n default --dry-run=client -o yaml | kubectl apply -f - 2>>$LOG || true
fi
if [ -f "$HTML_DIR/dev-index.html" ]; then
    kubectl create configmap dev-html-config --from-file=index.html="$HTML_DIR/dev-index.html" -n default --dry-run=client -o yaml | kubectl apply -f - 2>>$LOG || true
fi
if [ -f "$HTML_DIR/dev-mobile-index.html" ]; then
    kubectl create configmap dev-mobile-html-config --from-file=index.html="$HTML_DIR/dev-mobile-index.html" -n default --dry-run=client -o yaml | kubectl apply -f - 2>>$LOG || true
fi

# 8. Socat services - garantir que estao rodando
for svc in socat-8084 socat-5500 socat-5599 socat-5598 socat-3000; do
    systemctl is-active --quiet "$svc.service" 2>/dev/null || sudo systemctl restart "$svc.service" 2>/dev/null || true
done

# 9. Cloudflared tunnel (se token existir)
if [ -f /etc/cloudflared-token ] && ! pgrep -f "cloudflared tunnel" > /dev/null 2>&1; then
    log "[TUNNEL] Iniciando cloudflared..."
    nohup cloudflared tunnel run --token-file /etc/cloudflared-token > /tmp/cloudflared.log 2>&1 &
fi

log "[DONE] Ensure complete"
kubectl get pods -A 2>/dev/null | awk '{print $1, $2, $3}' | head -30
