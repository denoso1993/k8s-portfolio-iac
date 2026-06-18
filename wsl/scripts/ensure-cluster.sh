#!/bin/bash
set -e

CLUSTER_NAME="lab-sre-denoso"
KIND_CONFIG="/home/administrator/k8s-portfolio-iac/kind-config.yaml"

if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
    echo "Cluster ${CLUSTER_NAME} already exists"
    exit 0
fi

echo "Creating cluster ${CLUSTER_NAME}..."
kind create cluster --name "${CLUSTER_NAME}" --config "${KIND_CONFIG}"
kubectl wait --for=condition=Ready nodes --all --timeout=120s

kubectl apply -f /home/administrator/k8s-portfolio-iac/wsl/cluster/services/portfolio/
kubectl apply -f /home/administrator/k8s-portfolio-iac/wsl/cluster/services/postgres/
kubectl apply -f /home/administrator/k8s-portfolio-iac/wsl/cluster/monitoring/

kubectl wait --for=condition=Ready pods -n default --all --timeout=120s
kubectl wait --for=condition=Ready pods -n monitoring --all --timeout=120s 2>/dev/null || true

echo "Cluster ready!"