#!/bin/bash
# ensure-configmaps.sh - Garante que todos os ConfigMaps existem
set -e

echo '=== Ensuring ConfigMaps and Secrets ==='

kubectl create configmap nginx-html-config -n default   --from-file=index.html=/home/administrator/k8s-portfolio-iac/wsl/cluster/services/portfolio/configmap-nginx.yaml   --dry-run=client -o yaml | kubectl apply --server-side -f - 2>/dev/null || true

kubectl create configmap dev-html-config -n default   --from-file=index.html=/dev/null --dry-run=client -o yaml | kubectl apply --server-side -f - 2>/dev/null || true

kubectl create configmap mobile-html-config -n default   --from-file=index.html=/dev/null --dry-run=client -o yaml | kubectl apply --server-side -f - 2>/dev/null || true

# Se o secret já existe, usa o que está no cluster
# Se não existe, gera uma senha aleatória
if ! kubectl get secret postgres-secret -n default &>/dev/null; then
    POSTGRES_PASSWORD=$(openssl rand -base64 16)
    kubectl create secret generic postgres-secret -n default \
        --from-literal=POSTGRES_PASSWORD="$POSTGRES_PASSWORD" \
        --from-literal=POSTGRES_USER=postgres \
        --from-literal=POSTGRES_DB=portfolio
    echo "Secret postgres-secret criado com senha aleatória"
else
    echo "Secret postgres-secret já existe — mantendo senha atual"
fi

echo '=== Current ConfigMaps ==='
kubectl get configmap -n default

echo '=== Current Secrets ==='
kubectl get secrets -n default

echo 'ConfigMaps OK'
