#!/bin/bash
# ultimate-watchdog.sh — Watchdog ÚNICO do cluster k8s-portfolio-iac
# Chamado pelo systemd: ultimate-watchdog.service (a cada 30s)
# Funções: recovery de cluster, port-forwards, healthcheck, bridge
# Integra: daemon-watchdog.sh + portfolio-daemon.sh + monitor.sh

REPO_DIR="/home/administrator/k8s-portfolio-iac"
CLUSTER_NAME="lab-sre-denoso"
LOG="/var/log/ultimate-watchdog.log"
PIDFILE="/tmp/ultimate-watchdog.pid"

log() { echo "[$(date "+%Y-%m-%d %H:%M:%S")] $*" >> $LOG; }

# ===== PORT-FORWARD MANAGEMENT =====
ensure_pf() {
    local desc="$1" port="$2" svc="$3" target="$4" ns="$5" address="$6"
    if pgrep -f "port-forward.*${svc}.*${port}:${target}" >/dev/null 2>&1; then
        return 0
    fi
    log "[PF] Iniciando $desc ($port → $svc:$target)"
    nohup kubectl port-forward --address "$address" "svc/$svc" -n "$ns" "$port:$target" > "/tmp/pf-${desc}.log" 2>&1 &
    sleep 1
    if pgrep -f "port-forward.*${svc}.*${port}:${target}" >/dev/null 2>&1; then
        log "[PF] $desc OK"
    else
        log "[PF] $desc FALHOU"
    fi
}

# ===== HEALTH CHECK =====
healthcheck() {
    local fail=0
    local checks="nginx:http://localhost:8083/ dev:http://localhost:5500/ mobile:http://localhost:5599/ grafana:http://localhost:3000/ api:http://localhost:8001/api/v1/nodes"
    for check in $checks; do
        local name="${check%%:*}" url="${check#*:}"
        local code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 --max-time 10 "$url" 2>/dev/null)
        if [ -z "$code" ] || [ "$code" = "000" ] || [ "$code" = "502" ] || [ "$code" = "503" ]; then
            log "[HC] $name → $code (DOWN)"
            fail=1
        else
            log "[HC] $name → $code (OK)"
        fi
    done
    return $fail
}

# ===== BRIDGE MANAGEMENT =====
bridge_alive() {
    echo '{"command":"ping"}' | nc -q 1 127.0.0.1 5555 2>/dev/null | grep -q pong
}

# ===== MAIN LOOP =====
log "=== WATCHDOG INICIADO ==="

# 1. Verificar cluster
if ! kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
    log "[CLUSTER] Cluster perdido — recriando..."
    bash "$REPO_DIR/wsl/scripts/ensure-everything.sh" 2>&1 >> $LOG
fi

# 2. Verificar pods essenciais
ESSENTIAL_DEPLOYS="nginx-deployment dev-server mobile-server"
for dep in $ESSENTIAL_DEPLOYS; do
    if ! kubectl get deployment "$dep" -n default &>/dev/null; then
        log "[DEPLOY] $dep ausente — aplicando manifests..."
        kubectl apply -f "$REPO_DIR/wsl/cluster/services/portfolio/" 2>&1 >> $LOG
        break
    fi
done

# 3. Garantir port-forwards
ensure_pf "nginx" 8083 "nginx-service" 80 "default" "0.0.0.0"
ensure_pf "grafana" 3000 "grafana" 80 "monitoring" "127.0.0.1"
ensure_pf "dev" 5500 "dev-server-service" 5500 "default" "0.0.0.0"
ensure_pf "mobile" 5599 "mobile-server-service" 5599 "default" "0.0.0.0"

# 4. Garantir kubectl proxy
if ! pgrep -f "kubectl proxy.*8001" >/dev/null 2>&1; then
    log "[PROXY] Iniciando kubectl proxy na 8001..."
    nohup kubectl proxy --port=8001 --accept-hosts='localhost|127.0.0.1' --address='127.0.0.1' > /tmp/kubectl-proxy.log 2>&1 &
    sleep 1
fi

# 5. Verificar bridge WSL
if bridge_alive; then
    log "[BRIDGE] WSL Bridge ativa na porta 5555"
else
    log "[BRIDGE] WSL Bridge offline (esperado se não iniciada)"
fi

# 6. Healthcheck periódico (a cada 3 ciclos = ~90s)
CYCLE_FILE="/tmp/watchdog-cycle"
if [ ! -f "$CYCLE_FILE" ]; then
    echo "0" > "$CYCLE_FILE"
fi
CYCLE=$(cat "$CYCLE_FILE")
CYCLE=$(( (CYCLE + 1) % 3 ))
echo "$CYCLE" > "$CYCLE_FILE"
if [ "$CYCLE" -eq 0 ]; then
    if ! healthcheck; then
        log "[HC] Healthcheck falhou — reiniciando port-forwards..."
        pkill -f "kubectl.*port-forward" 2>/dev/null
        sleep 2
    fi
fi

# 7. Verificar insecure kubectl proxy
if pgrep -f "kubectl proxy.*--accept-hosts=\.\*" >/dev/null 2>&1; then
    log "[SEGURANCA] Proxy inseguro detectado — removendo..."
    kill -9 $(pgrep -f "kubectl proxy.*--accept-hosts=\.\*" | head -1) 2>/dev/null || true
fi

log "=== CICLO COMPLETO ==="
