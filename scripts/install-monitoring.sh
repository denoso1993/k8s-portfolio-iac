#!/bin/bash
set -e
LOG=/tmp/monitoring-install.log
log() { echo "[$(date "+%H:%M:%S")] $1" | tee -a $LOG; }
log "=== Instalando Monitoring Stack ==="
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
helm repo add grafana https://grafana.github.io/helm-charts 2>/dev/null || true
helm repo update 2>/dev/null || true
kubectl create namespace monitoring 2>/dev/null || true
if ! helm list -n monitoring -q 2>/dev/null | grep -q prometheus; then
    log "Instalando Prometheus..."
    helm install prometheus prometheus-community/prometheus --namespace monitoring --values /home/administrator/k8s-portfolio-iac/wsl/cluster/monitoring/prometheus-values.yaml --wait --timeout 5m 2>>$LOG
    log "Prometheus instalado"
fi
if ! helm list -n monitoring -q 2>/dev/null | grep -q grafana; then
    log "Instalando Grafana..."
    helm install grafana grafana/grafana --namespace monitoring --set adminPassword=admin --wait --timeout 5m 2>>$LOG
    log "Grafana instalado"
fi
log "=== Monitoring Stack Pronto ==="