#!/bin/bash
# ensure-everything-fixed.sh — Idempotent full cluster recovery + ConfigMaps
set -o pipefail

CLUSTER_NAME="lab-sre-denoso"
REPO_DIR="/home/administrator/k8s-portfolio-iac"
LOG="/var/log/ensure-everything.log"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG"; }

# Wait for Docker
log "Aguardando Docker Engine..."
for i in $(seq 1 30); do
    if docker info &>/dev/null; then
        log "Docker OK"
        break
    fi
    if [ "$i" -eq 30 ]; then echo "ERRO: Docker nao respondeu"; exit 1; fi
    sleep 2
done
sleep 3

# 1. Ensure cluster exists via ensure-cluster.sh
log "[CLUSTER] Verificando cluster..."
bash "$REPO_DIR/wsl/scripts/ensure-cluster.sh" 2>&1 | tee -a "$LOG"

# 2. Apply manifests (always, even if cluster existed)
log "[MANIFESTS] Aplicando manifests..."
for dir in infrastructure services/portfolio services/postgres security security/network-policies platform monitoring; do
    if [ -d "$REPO_DIR/wsl/cluster/$dir" ]; then
        kubectl apply -f "$REPO_DIR/wsl/cluster/$dir/" 2>>"$LOG" || log "[WARN] Falha em $dir"
    fi
done

# 3. Postgres secret
if ! kubectl get secret postgres-secret -n default &>/dev/null; then
    log "[SECRET] Criando postgres-secret..."
    kubectl create secret generic postgres-secret -n default \
        --from-literal=postgres-password="postgres" \
        --from-literal=postgres-user="postgres" 2>>"$LOG" || true
fi

# 4. metrics-server ServiceAccount
if ! kubectl get serviceaccount metrics-server -n kube-system &>/dev/null; then
    log "[METRICS] Criando ServiceAccount metrics-server..."
    kubectl create serviceaccount metrics-server -n kube-system 2>>"$LOG" || true
    kubectl apply -f "$REPO_DIR/wsl/cluster/infrastructure/metrics-server.yaml" 2>>"$LOG" || true
fi

# 5. Ingress (nginx ingress class ausente? cria se nao existir)
if ! kubectl get ingressclass nginx &>/dev/null; then
    log "[INGRESS] Instalando ingress-nginx..."
    kubectl apply -f "$REPO_DIR/wsl/cluster/infrastructure/ingress-controller.yaml" 2>>"$LOG" || true
fi

# 6. Ingress denis
log "[INGRESS] Aplicando ingress..."
kubectl apply -f "$REPO_DIR/wsl/cluster/services/portfolio/ingress-deniso.yaml" 2>>"$LOG" || true

# 7. ConfigMaps de HTML via apply (sem delete)
HTML_DIR="$REPO_DIR/wsl/cluster/services/portfolio/html"
if [ -f "$HTML_DIR/prod-index.html" ]; then
    kubectl create configmap nginx-html-config --from-file=index.html="$HTML_DIR/prod-index.html" -n default --dry-run=client -o yaml | kubectl apply -f - 2>>"$LOG" || true
fi
if [ -f "$HTML_DIR/mobile-index.html" ]; then
    kubectl create configmap mobile-html-config --from-file=index.html="$HTML_DIR/mobile-index.html" -n default --dry-run=client -o yaml | kubectl apply -f - 2>>"$LOG" || true
fi
if [ -f "$HTML_DIR/dev-index.html" ]; then
    kubectl create configmap dev-html-config --from-file=index.html="$HTML_DIR/dev-index.html" -n default --dry-run=client -o yaml | kubectl apply -f - 2>>"$LOG" || true
fi
if [ -f "$HTML_DIR/dev-mobile-index.html" ]; then
    kubectl create configmap dev-mobile-html-config --from-file=index.html="$HTML_DIR/dev-mobile-index.html" -n default --dry-run=client -o yaml | kubectl apply -f - 2>>"$LOG" || true
fi

# 8. Socat services — ensure running
for svc in socat-8084 socat-5500 socat-5599 socat-5598 socat-3000; do
    systemctl is-active --quiet "$svc.service" 2>/dev/null || sudo systemctl restart "$svc.service" 2>/dev/null || true
done

# 9. Cloudflared tunnel
if [ -f /etc/cloudflared-token ] && ! pgrep -f "cloudflared tunnel" > /dev/null 2>&1; then
    log "[TUNNEL] Iniciando cloudflared..."
    nohup cloudflared tunnel run --token-file /etc/cloudflared-token > /tmp/cloudflared.log 2>&1 &
fi

# 10. Port-forward nginx
log "[PORT-FWD] Configurando port-forward nginx..."
nohup kubectl port-forward --address 0.0.0.0 svc/nginx-service -n default 8083:80 > /tmp/pf-nginx-8083.log 2>&1 &

# 11. Grafana
log "[PORT-FWD] Configurando port-forward grafana..."
nohup kubectl port-forward --address 0.0.0.0 svc/grafana -n monitoring 3000:80 > /tmp/pf-grafana.log 2>&1 &

log "[DONE] Ensure complete"
kubectl get pods -A 2>/dev/null | awk '{print $1, $2, $3}' | head -30

