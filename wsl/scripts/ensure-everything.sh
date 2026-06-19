#!/bin/bash
set -o pipefail

CLUSTER_NAME="lab-sre-denoso"
REPO_DIR="/home/administrator/k8s-portfolio-iac"

if ! kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
    echo "[$(date)] Cluster down - recreating..."
    cd "$REPO_DIR" && kind create cluster --name "${CLUSTER_NAME}" --config kind-config.yaml
    kubectl wait --for=condition=Ready nodes --all --timeout=120s || true
fi
docker update --restart=always "${CLUSTER_NAME}-control-plane" 2>/dev/null || true

echo "[$(date)] Applying manifests..."
kubectl apply -f "$REPO_DIR/wsl/cluster/services/portfolio/" --server-side 2>/dev/null || true
kubectl apply -f "$REPO_DIR/wsl/cluster/services/postgres/" 2>/dev/null || true
kubectl apply -f "$REPO_DIR/wsl/cluster/monitoring/" 2>/dev/null || true
kubectl apply -f "$REPO_DIR/wsl/cluster/infrastructure/" 2>/dev/null || true

kubectl create configmap nginx-html-config --from-file=index.html="$REPO_DIR/wsl/cluster/services/portfolio/configmap-nginx.yaml" -n default --dry-run=client -o yaml | kubectl apply -f - 2>/dev/null || true
kubectl create configmap mobile-html-config --from-file=index.html="$REPO_DIR/wsl/cluster/services/portfolio/configmap-mobile.yaml" -n default --dry-run=client -o yaml | kubectl apply -f - 2>/dev/null || true
kubectl create configmap dev-html-config --from-file=index.html="$REPO_DIR/wsl/cluster/services/portfolio/configmap-mobile.yaml" -n default --dry-run=client -o yaml | kubectl apply -f - 2>/dev/null || true
kubectl create configmap dev-mobile-html-config --from-file=index.html="$REPO_DIR/wsl/cluster/services/portfolio/configmap-mobile.yaml" -n default --dry-run=client -o yaml | kubectl apply -f - 2>/dev/null || true

if ! kubectl get deployment kubectl-proxy -n default 2>/dev/null; then
    kubectl create deployment kubectl-proxy -n default --image=bitnami/kubectl:latest 2>/dev/null || true
    kubectl expose deployment kubectl-proxy -n default --port=8001 --target-port=8001 --name=kubectl-proxy 2>/dev/null || true
fi

if ! kubectl get ingress denisdeoliveira -n default 2>/dev/null; then
    kubectl apply -f "$REPO_DIR/wsl/cluster/services/portfolio/ingress-deniso.yaml" 2>/dev/null || true
fi

for svc in socat-8084 socat-5500 socat-5599 socat-5598 socat-3000; do
    systemctl is-active --quiet "$svc.service" 2>/dev/null || sudo systemctl restart "$svc.service" 2>/dev/null || true
done

if ! pgrep -f "cloudflared tunnel" > /dev/null 2>&1; then
    nohup cloudflared tunnel run --token-file /etc/cloudflared-token > /tmp/cloudflared.log 2>&1 &
fi

echo "[$(date)] Done"
