#!/bin/bash
# ensure-cluster.sh - Idempotent Kind cluster creation with graceful error handling
set -o pipefail

CLUSTER_NAME="lab-sre-denoso"
KIND_CONFIG="/home/administrator/k8s-portfolio-iac/kind-config.yaml"

# Check if cluster already exists
if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
    echo "Cluster ${CLUSTER_NAME} already exists"
    # Make sure restart policy is set
    docker update --restart=always ${CLUSTER_NAME}-control-plane 2>/dev/null || true
    kubectl wait --for=condition=Ready nodes --all --timeout=60s 2>/dev/null || true
    exit 0
fi

echo "Creating cluster ${CLUSTER_NAME}..."
kind create cluster --name "${CLUSTER_NAME}" --config "${KIND_CONFIG}"
kubectl wait --for=condition=Ready nodes --all --timeout=120s

# Apply manifests - continue even if some fail
kubectl apply -f /home/administrator/k8s-portfolio-iac/wsl/cluster/services/portfolio/ 2>/dev/null || true
kubectl apply -f /home/administrator/k8s-portfolio-iac/wsl/cluster/services/postgres/ 2>/dev/null || true
kubectl apply -f /home/administrator/k8s-portfolio-iac/wsl/cluster/monitoring/ 2>/dev/null || true

# Create large ConfigMaps via --from-file (bypasses annotation limit)
kubectl create configmap nginx-html-config --from-file=index.html=/home/administrator/k8s-portfolio-iac/wsl/cluster/services/portfolio/configmap-nginx.yaml -n default 2>/dev/null || true
kubectl create configmap dev-html-config --from-file=index.html=/home/administrator/k8s-portfolio-iac/wsl/cluster/services/portfolio/configmap-mobile.yaml -n default 2>/dev/null || true

kubectl wait --for=condition=Ready pods -n default --all --timeout=120s 2>/dev/null || true

# Ensure Docker auto-restarts the container
docker update --restart=always "${CLUSTER_NAME}-control-plane" 2>/dev/null || true
echo "Cluster ready!"