#!/bin/bash
LOG=/tmp/portfolio-monitor.log

log() {
    echo "[$(date "+%H:%M")] $1" >> $LOG
}

# Check kubectl proxy
if ! pgrep -f "kubectl proxy.*8001" > /dev/null 2>&1; then
    log "kubectl proxy DOWN - restarting..."
    nohup kubectl proxy --address=0.0.0.0 --port=8001 --accept-hosts=.* > /tmp/kubectl-proxy.log 2>&1 &
    sleep 2
    log "kubectl proxy restarted"
fi

# Check port-forward nginx
if ! pgrep -f "kubectl port-forward.*nginx.*8083" > /dev/null 2>&1; then
    log "port-forward nginx DOWN - restarting..."
    nohup kubectl port-forward --address 0.0.0.0 svc/nginx-service -n default 8083:80 > /tmp/port-forward-nginx.log 2>&1 &
    sleep 2
    log "port-forward nginx restarted"
fi

# Check port-forward grafana
if ! pgrep -f "kubectl port-forward.*grafana.*3000" > /dev/null 2>&1; then
    log "port-forward grafana DOWN - restarting..."
    nohup kubectl port-forward --address 0.0.0.0 svc/grafana -n monitoring 3000:80 > /tmp/port-forward-grafana.log 2>&1 &
    sleep 2
    log "port-forward grafana restarted"
fi

# Check cluster pods
if kubectl get pods -n default -o name 2>/dev/null | grep -q nginx; then
    :
else
    log "nginx pod missing - reapplying manifests..."
    kubectl apply -f /home/administrator/k8s-portfolio-iac/k8s/services/portfolio/ 2>/dev/null || true
    log "manifests reapplied"
fi
