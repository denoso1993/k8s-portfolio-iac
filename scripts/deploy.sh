#!/bin/bash
set -e
ENV=$1
K8S_DIR="/home/administrator/k8s-portfolio-iac/wsl/cluster/services/portfolio"
[ -z "$ENV" ] && echo "Uso: bash deploy.sh [desktop-prod|desktop-dev|mobile-prod|mobile-dev]" && exit 1
echo "=== AMDIENTE: $ENV ==="
echo -n "Confirma? (s/N): "; read CONFIRM
[ "$CONFIRM" != "s" ] && [ "$CONFIRM" != "S" ] && echo "Cancelado." && exit 0
case $ENV in
  desktop-prod) kubectl apply -f $K8S_DIR/configmap-nginx.yaml 2>/dev/null; kubectl rollout restart deployment nginx-deployment -n default 2>/dev/null; echo "OK" ;;
  desktop-dev) kubectl delete configmap dev-html-config -n default 2>/dev/null; kubectl create configmap dev-html-config -n default --from-file=index.html=$KNS_DIR/configmap-nginx.yaml 2>/dev/null; kubectl rollout restart deployment dev-server -n default 2>/dev/null; echo "OK" ;;
  mobile-prod) kubectl delete configmap mobile-html-config -n default 2>/dev/null; kubectl create configmap mobile-html-config -n default --from-file=index.html=$K8S_DIR/configmap-nginx.yaml 2>/dev/null; kubectl rollout restart deployment mobile-server -n default 2>/dev/null; echo "OK" ;;
  mobile-dev) kubectl delete configmap dev-mobile-html-config -n default 2>/dev/null; kubectl create configmap dev-mobile-html-config -n default --from-file=index.html=$K8S_DIR/configmap-nginx.yaml 2>/dev/null; kubectl rollout restart deployment mobile-dev-server -n default 2>/dev/null; echo "OK" ;;
  *) echo "Erro: invalido"; exit 1 ;;
esac
