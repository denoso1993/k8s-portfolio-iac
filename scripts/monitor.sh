#!/bin/bash
# ⚠️ OBSOLETO — Use wsl/scripts/ultimate-watchdog.sh em vez deste
# Mantido apenas para referência histórica
# Última atualização: 2026-06-20
LOG=/tmp/portfolio-monitor.log

log() {
    echo "[$(date '+%H:%M')] $1" >> $LOG
}

# Kill old insecure kubectl proxy (root) if running
if pgrep -f "kubectl proxy.*--accept-hosts=\.\*" > /dev/null 2>&1; then
    log "Insecure kubectl proxy detected - attempting kill..."
    sudo kill -9 $(pgrep -f "kubectl proxy.*--accept-hosts=\.\*" | head -1) 2>/dev/null || true
fi

# Check kubectl proxy (secure)
if ! pgrep -f "kubectl proxy.*8001" > /dev/null 2>&1; then
    log "kubectl proxy DOWN - restarting secure version..."
    nohup kubectl proxy --address=0.0.0.0 --port=8001 --accept-hosts='localhost' --accept-paths='^/api/v1/(pods|nodes|services|namespaces)(/|$)' > /tmp/kubectl-proxy.log 2>&1 &
    sleep 2
    log "kubectl proxy restarted (SECURE - pods/nodes only)"
fi

# Check port-forward nginx (public)
if ! pgrep -f "kubectl port-forward.*nginx.*8083" > /dev/null 2>&1; then
    log "port-forward nginx DOWN - restarting..."
    nohup kubectl port-forward --address 0.0.0.0 svc/nginx-service -n default 8083:80 > /tmp/port-forward-nginx.log 2>&1 &
    sleep 2
    log "port-forward nginx restarted"
fi

# Check port-forward grafana (LOCALHOST only)
if ! pgrep -f "kubectl port-forward.*grafana.*3000" > /dev/null 2>&1; then
    log "port-forward grafana DOWN - restarting (LOCALHOST only)..."
    nohup kubectl port-forward --address 127.0.0.1 svc/grafana -n monitoring 3000:80 > /tmp/port-forward-grafana.log 2>&1 &
    sleep 2
    log "port-forward grafana restarted (LOCALHOST ONLY)"
fi

# Check cluster pods
if kubectl get pods -n default -o name 2>/dev/null | grep -q nginx; then
    :
else
    log "nginx pod missing - reapplying manifests..."
    kubectl apply -f /home/administrator/k8s-portfolio-iac/wsl/cluster/services/portfolio/ 2>/dev/null || true
    log "manifests reapplied"
fi
