#!/bin/bash
# portfolio-daemon.sh v5 - WSL Bridge PF management
LOG=/tmp/portfolio-daemon.log
PIDFILE=/tmp/portfolio-daemon.pid
K8S_BASE="/home/administrator/k8s-portfolio-iac/k8s"
CLUSTER="lab-sre-denoso"
BRIDGE_SCRIPT="/home/administrator/k8s-portfolio-iac/scripts/start-pfs-bridge.sh"
BRIDGE_HOST="127.0.0.1"
BRIDGE_PORT=5555
log() { echo "[$(date "+%H:%M:%S")] $1" >> $LOG; }

bridge_alive() { echo '{"command":"ping"}' | nc -q 1 $BRIDGE_HOST $BRIDGE_PORT 2>/dev/null | grep -q pong; }

bridge_send() {
    local cmd="$1"
    local j
    j=$(python3 -c "import json,sys; print(json.dumps({'command':sys.argv[1]}))" "$cmd" 2>/dev/null) || return 1
    local r
    r=$(echo "$j" | nc -q 5 $BRIDGE_HOST $BRIDGE_PORT 2>/dev/null) || return 1
    local s
    s=$(echo "$r" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status','err'))" 2>/dev/null)
    [ "$s" = "success" ]
}

bridge_start_pf() {
    local d="$1" c="$2"
    if bridge_alive; then log "[BRIDGE] $d..."; bridge_send "$c" && log "[BRIDGE] $d OK" && return 0; fi
    return 1
}

bridge_kill_pfs() {
    if bridge_alive; then
        log "[BRIDGE] Matando PFs..."
        bridge_send "pkill -f 'kubectl.*port-forward' 2>/dev/null; pkill -f 'kubectl.*proxy.*800[12]' 2>/dev/null; echo OK"
        log "[BRIDGE] PFs mortos"; return 0
    fi
    pkill -f 'kubectl.*port-forward' 2>/dev/null; pkill -f 'kubectl.*proxy.*800[12]' 2>/dev/null
}

if [ -f "$PIDFILE" ] && kill -0 $(cat "$PIDFILE") 2>/dev/null; then
    echo "Daemon ja rodando PID $(cat $PIDFILE)"; while true; do sleep 60; done
fi
echo $$ > "$PIDFILE"
log "=== DAEMON v5 BRIDGE INICIADO ==="

recovery() {
    log "[RECOVERY] Iniciando..."
    if ! kind get clusters 2>/dev/null | grep -q $CLUSTER; then
        kind create cluster --name $CLUSTER --config /home/administrator/k8s-portfolio-iac/kind-config.yaml 2>>$LOG; sleep 30
    fi
    kubectl wait --for=condition=Ready nodes --all --timeout=120s 2>>$LOG || { log "[RECOVERY] ERRO node"; return 1; }
    for d in infrastructure security security/network-policies services/postgres services/portfolio; do
        kubectl apply -f $K8S_BASE/$d/ 2>>$LOG
    done
    for l in "app=nginx" "app=mobile-server" "app=postgres" "app=dev-server"; do
        kubectl wait --for=condition=Ready pod -l $l -n default --timeout=120s 2>>$LOG || log "[WARN] $l timeout"
    done
    kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=ingress-nginx -n ingress-nginx --timeout=120s 2>>$LOG || log "[WARN] ingress timeout"
    log "[RECOVERY] OK"; return 0
}

start_infra() {
    log "[INFRA] Iniciando servicos..."
    bridge_kill_pfs
    local svcs=(
        "proxy8001|nohup kubectl proxy --port=8001 --accept-hosts='localhost|127.0.0.1' --address='127.0.0.1' > /tmp/proxy-8001.log 2>&1 &"
        "nginx8083|nohup kubectl port-forward --address 0.0.0.0 svc/nginx-service -n default 8083:80 > /tmp/pf-nginx.log 2>&1 &"
        "grafana3000|nohup kubectl port-forward --address 127.0.0.1 svc/grafana -n monitoring 3000:80 > /tmp/pf-grafana.log 2>&1 &"
        "dev5500|nohup kubectl port-forward --address 0.0.0.0 svc/dev-server-service -n default 5500:5500 > /tmp/pf-dev.log 2>&1 &"
        "mobile5599|nohup kubectl port-forward --address 0.0.0.0 svc/mobile-server-service -n default 5599:5599 > /tmp/pf-mobile.log 2>&1 &"
    )
    for s in "${svcs[@]}"; do
        local n="${s%%|*}" c="${s#*|}"
        if bridge_alive && bridge_send "$c"; then log "[BRIDGE] $n OK"; continue; fi
        log "[NOHUP] $n..."; eval "$c"; sleep 1
        pgrep -f "$(echo "$c" | grep -oP 'port-forward.*?(?= >)')" >/dev/null 2>&1 && log "[NOHUP] $n OK" || log "[NOHUP] $n FALHOU"
    done
    log "[INFRA] OK"
}

healthcheck_pfs() {
    local fail=0
    local eps="nginx:http://localhost:8083/ k8s-proxy:http://localhost:8001/api/v1/nodes dev:http://localhost:5500/ mobile:http://localhost:5599/ grafana:http://localhost:3000/"
    for ep in $eps; do
        local n="${ep%%:*}" u="${ep#*:}"
        local c=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 --max-time 10 "$u" 2>/dev/null)
        if [ -z "$c" ] || [ "$c" = "000" ] || [ "$c" = "502" ] || [ "$c" = "503" ]; then
            log "[HC-DOWN] $n -> $c"; fail=1
        else
            log "[HC-OK] $n -> $c"
        fi
    done
    if [ $fail -eq 1 ]; then
        log "[HC] Reiniciando PFs..."; bridge_kill_pfs; sleep 1; $BRIDGE_SCRIPT start >> $LOG 2>&1
    fi
}

recovery && start_infra
log "[MONITOR] 30s ciclo"

while true; do
    kind get clusters 2>/dev/null | grep -q $CLUSTER || { log "[ALERTA] Cluster perdido"; recovery && start_infra; continue; }
    bridge_alive || { log "[WARN] Bridge offline, usando nohup direto"; }
    
    pgrep -f "port-forward.*nginx.*8083" >/dev/null 2>&1 || bridge_start_pf "nginx8083" "nohup kubectl port-forward --address 0.0.0.0 svc/nginx-service -n default 8083:80 > /tmp/pf-nginx.log 2>&1 &"
    pgrep -f "port-forward.*grafana.*3000" >/dev/null 2>&1 || bridge_start_pf "grafana3000" "nohup kubectl port-forward --address 127.0.0.1 svc/grafana -n monitoring 3000:80 > /tmp/pf-grafana.log 2>&1 &"
    pgrep -f "port-forward.*dev-server.*5500" >/dev/null 2>&1 || bridge_start_pf "dev5500" "nohup kubectl port-forward --address 0.0.0.0 svc/dev-server-service -n default 5500:5500 > /tmp/pf-dev.log 2>&1 &"
    pgrep -f "port-forward.*mobile.*5599" >/dev/null 2>&1 || bridge_start_pf "mobile5599" "nohup kubectl port-forward --address 0.0.0.0 svc/mobile-server-service -n default 5599:5599 > /tmp/pf-mobile.log 2>&1 &"
    pgrep -f "kubectl.*proxy.*8001" >/dev/null 2>&1 || bridge_start_pf "proxy8001" "nohup kubectl proxy --port=8001 --accept-hosts='localhost|127.0.0.1' --address='127.0.0.1' > /tmp/proxy-8001.log 2>&1 &"
    
    if [ $((SECONDS % 90)) -lt 30 ]; then healthcheck_pfs; fi
    
    kubectl get pod -l app=nginx -n default --no-headers 2>/dev/null | grep -q Running || { kubectl apply -f $K8S_BASE/services/portfolio/ 2>>$LOG; log "[FIX] nginx pod"; }
    sleep 30
done
