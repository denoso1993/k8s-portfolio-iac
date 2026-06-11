#!/bin/bash
LOG=/tmp/portfolio-daemon.log
PIDFILE=/tmp/portfolio-daemon.pid
K8S_BASE="/home/administrator/k8s-portfolio-iac/k8s"
CLUSTER="lab-sre-denoso"

log() { echo "[$(date "+%H:%M:%S")] $1" >> $LOG; }

if [ -f "$PIDFILE" ] && kill -0 $(cat "$PIDFILE") 2>/dev/null; then
    echo "Daemon ja rodando PID $(cat $PIDFILE)"
    while true; do sleep 60; done
fi
echo $$ > "$PIDFILE"
log "=== DAEMON v4 INICIADO ==="

recovery() {
    log "[RECOVERY] Iniciando recovery completo..."

    if ! kind get clusters 2>/dev/null | grep -q $CLUSTER; then
        log "[RECOVERY] Recriando cluster Kind..."
        kind create cluster --name $CLUSTER --config /home/administrator/k8s-portfolio-iac/kind-config.yaml 2>>$LOG
        sleep 30
    fi

    kubectl wait --for=condition=Ready nodes --all --timeout=120s 2>>$LOG || { log "[RECOVERY] ERRO node"; return 1; }

    log "[RECOVERY] Aplicando infrastructure..."
    kubectl apply -f $K8S_BASE/infrastructure/ 2>>$LOG
    log "[RECOVERY] Aplicando security..."
    kubectl apply -f $K8S_BASE/security/ 2>>$LOG
    kubectl apply -f $K8S_BASE/security/network-policies/ 2>>$LOG
    log "[RECOVERY] Aplicando postgres..."
    kubectl apply -f $K8S_BASE/services/postgres/ 2>>$LOG
    log "[RECOVERY] Aplicando portfolio..."
    kubectl apply -f $K8S_BASE/services/portfolio/ 2>>$LOG

    log "[RECOVERY] Aguardando pods essenciais..."
    for label in "app=nginx" "app=mobile-server" "app=postgres" "app=dev-server"; do
        kubectl wait --for=condition=Ready pod -l $label -n default --timeout=120s 2>>$LOG || log "[WARN] $label timeout"
    done
    kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=ingress-nginx -n ingress-nginx --timeout=120s 2>>$LOG || log "[WARN] ingress timeout"

    log "[RECOVERY] Cluster pronto"
    return 0
}

start_infra() {
    log "[INFRA] Iniciando servicos..."

    for p in "kubectl proxy.*8001" "kubectl proxy.*8002" "port-forward.*nginx.*8083" "port-forward.*grafana.*3000" "port-forward.*dev-server.*5500" "port-forward.*mobile.*5599"; do
        case "$p" in
            *8001) pgrep -f "$p" >/dev/null 2>&1 || kubectl proxy --address=0.0.0.0 --port=8001 > /tmp/proxy-8001.log 2>&1 & ;;
            *8002) pgrep -f "$p" >/dev/null 2>&1 || kubectl proxy --port=8002 --accept-hosts=".*" --address="0.0.0.0" > /tmp/proxy-8002.log 2>&1 & ;;
            *8083) pgrep -f "$p" >/dev/null 2>&1 || nohup kubectl port-forward --address 0.0.0.0 svc/nginx-service -n default 8083:80 > /tmp/pf-nginx.log 2>&1 & ;;
            *3000) pgrep -f "$p" >/dev/null 2>&1 || nohup kubectl port-forward --address 127.0.0.1 svc/grafana -n monitoring 3000:80 > /tmp/pf-grafana.log 2>&1 & ;;
            *5500) pgrep -f "$p" >/dev/null 2>&1 || nohup kubectl port-forward --address 0.0.0.0 svc/dev-server-service -n default 5500:5500 > /tmp/pf-dev.log 2>&1 & ;;
            *5599) pgrep -f "$p" >/dev/null 2>&1 || nohup kubectl port-forward --address 0.0.0.0 svc/mobile-server-service -n default 5599:5599 > /tmp/pf-mobile.log 2>&1 & ;;
        esac
    done
    log "[INFRA] Todos servicos iniciados"
}

recovery && start_infra
log "[MONITOR] Monitorando (15s)"

while true; do
    kind get clusters 2>/dev/null | grep -q $CLUSTER || { log "[ALERTA] Cluster perdido"; recovery && start_infra; continue; }

    pgrep -f "port-forward.*nginx.*8083" > /dev/null 2>&1 || { nohup kubectl port-forward --address 0.0.0.0 svc/nginx-service -n default 8083:80 > /tmp/pf-nginx.log 2>&1 & log "[FIX] nginx"; }
    pgrep -f "kubectl proxy.*8002" > /dev/null 2>&1 || { kubectl proxy --port=8002 --accept-hosts=".*" --address="0.0.0.0" > /tmp/proxy-8002.log 2>&1 & log "[FIX] proxy 8002"; }
    pgrep -f "port-forward.*grafana.*3000" > /dev/null 2>&1 || { nohup kubectl port-forward --address 127.0.0.1 svc/grafana -n monitoring 3000:80 > /tmp/pf-grafana.log 2>&1 & log "[FIX] grafana"; }
    pgrep -f "port-forward.*dev-server.*5500" > /dev/null 2>&1 || { nohup kubectl port-forward --address 0.0.0.0 svc/dev-server-service -n default 5500:5500 > /tmp/pf-dev.log 2>&1 & log "[FIX] dev"; }
    pgrep -f "port-forward.*mobile.*5599" > /dev/null 2>&1 || { nohup kubectl port-forward --address 0.0.0.0 svc/mobile-server-service -n default 5599:5599 > /tmp/pf-mobile.log 2>&1 & log "[FIX] mobile"; }

    kubectl get pod -l app=nginx -n default --no-headers 2>/dev/null | grep -q Running || { kubectl apply -f $K8S_BASE/services/portfolio/ 2>>$LOG; log "[FIX] nginx pod"; }
    curl -s -o /dev/null -w "%{http_code}" http://localhost:8083/ 2>/dev/null | grep -q 200 || log "[ALERTA] Site DOWN"

    sleep 15
done