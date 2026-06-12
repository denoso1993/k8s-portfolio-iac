#!/bin/bash
# ensure-configmaps.sh - Garante que todos os ConfigMaps existem
set -e

echo '=== Ensuring ConfigMaps and Secrets ==='

kubectl create configmap nginx-html-config -n default   --from-file=index.html=/home/administrator/k8s-portfolio-iac/k8s/services/portfolio/configmap-nginx.yaml   --dry-run=client -o yaml | kubectl apply --server-side -f - 2>/dev/null || true

kubectl create configmap dev-html-config -n default   --from-file=index.html=/dev/null --dry-run=client -o yaml | kubectl apply --server-side -f - 2>/dev/null || true

kubectl create configmap mobile-html-config -n default   --from-file=index.html=/dev/null --dry-run=client -o yaml | kubectl apply --server-side -f - 2>/dev/null || true

kubectl create secret generic postgres-secret -n default   --from-literal=POSTGRES_PASSWORD=postgres123   --from-literal=POSTGRES_USER=postgres   --dry-run=client -o yaml | kubectl apply --server-side -f - 2>/dev/null || true

echo '=== Current ConfigMaps ==='
kubectl get configmap -n default

echo '=== Current Secrets ==='
kubectl get secrets -n default

echo 'ConfigMaps OK'
