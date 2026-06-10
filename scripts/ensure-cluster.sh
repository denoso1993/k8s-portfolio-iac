#!/bin/bash
# ensure-cluster.sh - Garante que o cluster e servicos estao rodando
# Uso: bash ensure-cluster.sh
# Pode ser chamado por tarefa agendada ou manualmente

LOG=/tmp/ensure-cluster.log
log() { echo "[$(date "+%H:%M")] $1" | tee -a $LOG; }

# Check Docker
if ! docker info >/dev/null 2>&1; then
    log "Docker not running - attempting start..."
    sudo service docker start 2>/dev/null || true
    sleep 10
    if ! docker info >/dev/null 2>&1; then
        log "FATAL: Docker cannot start"
        exit 1
    fi
fi
log "Docker OK"

# Check Kind cluster
if ! kind get clusters 2>/dev/null | grep -q lab-sre-denoso; then
    log "Kind cluster not found - creating..."
    kind create cluster --name lab-sre-denoso --config /home/administrator/k8s-portfolio-iac/kind-config.yaml
    sleep 30
    log "Applying manifests..."
    kubectl apply -f /home/administrator/k8s-portfolio-iac/k8s/services/portfolio/
    kubectl apply -f /home/administrator/k8s-portfolio-iac/k8s/security/network-policies/
else
    log "Kind cluster OK"
fi

# Kill old insecure proxy
if pgrep -f "kubectl proxy.*--accept-hosts=\\.\\*" >/dev/null 2>&1; then
    sudo kill -9 $(pgrep -f "kubectl proxy.*--accept-hosts=\\.\\*" | head -1) 2>/dev/null || true
fi

# Kubectl proxy
if ! pgrep -f "kubectl proxy.*8001" >/dev/null 2>&1; then
    log "Starting kubectl proxy..."
    nohup kubectl proxy --address=0.0.0.0 --port=8001 --accept-hosts='localhost' --accept-paths='^/api/v1/(pods|nodes)(/|$)' > /tmp/kubectl-proxy.log 2>&1 &
fi

# Port-forward nginx
if ! pgrep -f "kubectl port-forward.*nginx.*8083" >/dev/null 2>&1; then
    log "Starting port-forward nginx:8083..."
    nohup kubectl port-forward --address 0.0.0.0 svc/nginx-service -n default 8083:80 > /tmp/port-forward-nginx.log 2>&1 &
fi

# Port-forward grafana (localhost only)
if ! pgrep -f "kubectl port-forward.*grafana.*3000" >/dev/null 2>&1; then
    log "Starting port-forward grafana:3000 (localhost)..."
    nohup kubectl port-forward --address 127.0.0.1 svc/grafana -n monitoring 3000:80 > /tmp/port-forward-grafana.log 2>&1 &
fi

# Daemon
if ! pgrep -f "portfolio-daemon.sh" >/dev/null 2>&1; then
    log "Starting portfolio daemon..."
    nohup bash /home/administrator/k8s-portfolio-iac/scripts/portfolio-daemon.sh > /tmp/daemon.log 2>&1 &
fi

log "=== All services OK ==="
