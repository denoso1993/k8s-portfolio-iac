#!/bin/bash
LOG=/tmp/portfolio-daemon.log
PIDFILE=/tmp/portfolio-daemon.pid
K8S_DIR="/home/administrator/k8s-portfolio-iac/k8s/services/portfolio"
CLUSTER="lab-sre-denoso"

log() { echo "[$(date "+%H:%M:%S")] $1" >> $LOG; }

if [ -f "$PIDFILE" ] && kill -0 $(cat "$PIDFILE") 2>/dev/null; then
    echo "Daemon ja rodando PID $(cat $PIDFILE)"
    while true; do sleep 60; done
fi
echo $$ > "$PIDFILE"
log "=== Daemon v3 INICIADO ==="

recovery() {
    log "[RECOVERY] Iniciando..."
    if ! kind get clusters 2>/dev/null | grep -q $CLUSTER; then
        log "[RECOVERY] Recriando cluster..."
        kind create cluster --name $CLUSTER --config /home/administrator/k8s-portfolio-iac/kind-config.yaml 2>>$LOG
        sleep 30
    fi
    kubectl wait --for=condition=Ready nodes --all --timeout=120s 2>>$LOG || { log "[RECOVERY] ERRO node"; return 1; }
    kubectl apply -f $K8S_DIR/ 2>>$LOG
    kubectl wait --for=condition=Ready pod -l app=nginx -n default --timeout=60s 2>>$LOG
    log "[RECOVERY] Pronto"
}

infra() {
    pgrep -f "kubectl proxy.*8002" > /dev/null 2>&1 || kubectl proxy --port=8002 --accept-hosts=".*" --address="0.0.0.0" > /tmp/proxy-8002.log 2>&1 &
    pgrep -f "port-forward.*nginx.*8083" > /dev/null 2>&1 || nohup kubectl port-forward --address 0.0.0.0 svc/nginx-service -n default 8083:80 > /tmp/pf-nginx.log 2>&1 &
    log "[INFRA] OK"
}

recovery && infra
log "[MONITOR] Ativo"

while true; do
    kind get clusters 2>/dev/null | grep -q $CLUSTER || { log "[WARN] Cluster perdido"; recovery && infra; }
    pgrep -f "port-forward.*nginx.*8083" > /dev/null 2>&1 || { nohup kubectl port-forward --address 0.0.0.0 svc/nginx-service -n default 8083:80 > /tmp/pf-nginx.log 2>&1 & log "[FIX] pf 8083"; }
    pgrep -f "kubectl proxy.*8002" > /dev/null 2>&1 || { kubectl proxy --port=8002 --accept-hosts=".*" --address="0.0.0.0" > /tmp/proxy-8002.log 2>&1 & log "[FIX] proxy 8002"; }
    kubectl get pod -l app=nginx -n default --no-headers 2>/dev/null | grep -q Running || { kubectl apply -f $K8S_DIR/ 2>>$LOG; log "[FIX] Nginx"; }
    sleep 15
done