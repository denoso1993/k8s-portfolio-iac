#!/bin/bash
# Portfolio Daemon Monitor - roda em background, sem abrir terminal
LOG=/tmp/portfolio-monitor.log

# Detect WSL2 host IP for kubectl proxy
detect_proxy_ip() {
    # Get the IP of the docker bridge or use localhost
    KUBECTL_IP=$(ip route get 1 2>/dev/null | head -1 | awk '{print $NF}' 2>/dev/null)
    if [ -z "$KUBECTL_IP" ]; then
        KUBECTL_IP="172.19.105.82"
    fi
    echo "$KUBECTL_IP"
}

PIDFILE=/tmp/portfolio-monitor.pid

log() {
    echo "[$(date '+%H:%M')] $1" >> $LOG
}

# Check if already running
if [ -f "$PIDFILE" ]; then
    OLD_PID=$(cat "$PIDFILE")
    if kill -0 "$OLD_PID" 2>/dev/null; then
        echo "Monitor already running (PID $OLD_PID)"
        exit 0
    fi
fi

echo $$ > "$PIDFILE"
log "Daemon started (PID $$)"
    # Start PF watchdog for dev-server if not running
    if ! pgrep -f "pf-watchdog" > /dev/null 2>&1; then
        nohup bash /home/administrator/k8s-portfolio-iac/scripts/pf-watchdog.sh > /tmp/pf-watchdog.log 2>&1 &
        log "PF watchdog started"
    fi

while true; do
    # Kill old insecure proxy if somehow running
    if pgrep -f "kubectl proxy.*--accept-hosts=\.\*" > /dev/null 2>&1; then
        sudo kill -9 $(pgrep -f "kubectl proxy.*--accept-hosts=\.\*" | head -1) 2>/dev/null || true
        log "Killed insecure proxy"
    fi

    # Check kubectl proxy
    if ! pgrep -f "kubectl proxy.*8001" > /dev/null 2>&1; then
        log "kubectl proxy DOWN - restarting..."
        nohup kubectl proxy --address=0.0.0.0 --port=8001 --accept-hosts='localhost' --accept-paths='^/api/v1/(pods|nodes)(/|$)' > /tmp/kubectl-proxy.log 2>&1 &
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

    # Check port-forward grafana (LOCALHOST only)
    if ! pgrep -f "kubectl port-forward.*grafana.*3000" > /dev/null 2>&1; then
        log "port-forward grafana DOWN - restarting..."
        nohup kubectl port-forward --address 127.0.0.1 svc/grafana -n monitoring 3000:80 > /tmp/port-forward-grafana.log 2>&1 &
        sleep 2
        log "port-forward grafana restarted"
    fi
    # Check port-forward dev-server (DEV)
    if ! pgrep -f "kubectl port-forward.*dev-server.*5500" > /dev/null 2>&1; then
        log "port-forward dev-server DOWN - restarting..."
        nohup kubectl port-forward --address 0.0.0.0 svc/dev-server-service -n default 5500:5500 > /tmp/pf-dev.log 2>&1 &
        sleep 2
        log "port-forward dev-server restarted"
    fi

    # Check cluster pods
    if ! kubectl get pods -n default -o name 2>/dev/null | grep -q nginx; then
        log "nginx pod missing - reapplying manifests..."
        kubectl apply -f /home/administrator/k8s-portfolio-iac/k8s/services/portfolio/ 2>/dev/null || true
        sleep 5
    fi

    # Check dev-server pod
    if ! kubectl get pod -n default -l app=dev-server --no-headers 2>/dev/null | grep -q Running; then
        log "dev-server pod missing - recreating..."
        kubectl apply -f /home/administrator/k8s-portfolio-iac/k8s/services/portfolio/deployment-dev-server.yaml 2>/dev/null || true
    fi
    if ! pgrep -f "kubectl port-forward.*dev-server.*5500" > /dev/null 2>&1; then
        log "dev-server port-forward DOWN - restarting..."
        nohup kubectl port-forward --address 0.0.0.0 svc/dev-server-service -n default 5500:5500 > /tmp/pf-dev.log 2>&1 &
        sleep 2
        log "dev-server port-forward restarted"
    fi

    sleep 5
done
