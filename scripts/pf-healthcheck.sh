#!/bin/bash
# pf-healthcheck.sh - Verifica saude dos PFs a cada 30s e reinicia via bridge se necessario
# Uso: ./pf-healthcheck.sh [--daemon] [--once]
# ============================================================
# Roda em background como parte do portfolio-daemon ou standalone.
# Verifica endpoints HTTP e processos, reinicia via bridge se algo cair.
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BRIDGE_SCRIPT="$SCRIPT_DIR/start-pfs-bridge.sh"
LOG=/tmp/pf-healthcheck.log

log() { echo "[$(date "+%H:%M:%S")] $*" >> "$LOG"; }

# Lista de PFs para verificar: NOME|PORTA|URL_CHECK|PGRRE_PATTERN
PFS=(
    "nginx|8083|http://localhost:8083/|port-forward.*nginx.*8083"
    "dev-server|5500|http://localhost:5500/|port-forward.*dev-server.*5500"
    "mobile-server|5599|http://localhost:5599/health|port-forward.*mobile.*5599"
    "grafana|3000|http://localhost:3000/|port-forward.*grafana.*3000"
    "k8s-proxy|8001|http://localhost:8001/api/v1/nodes|kubectl.*proxy.*8001"
)

check_pf() {
    local name="$1"
    local port="$2"
    local url="$3"
    local pattern="$4"
    local failed=0

    # 1. Verifica se o processo existe
    if ! pgrep -f "$pattern" >/dev/null 2>&1; then
        log "[DOWN] $name - processo nao encontrado"
        return 1
    fi

    # 2. Verifica se a porta esta escutando
    if ! ss -tlnp 2>/dev/null | grep -q ":$port "; then
        if ! netstat -an 2>/dev/null | grep -q ":$port .*LISTEN"; then
            log "[DOWN] $name - porta $port nao escutando"
            return 1
        fi
    fi

    # 3. Verifica se o endpoint HTTP responde
    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 --max-time 10 "$url" 2>/dev/null)
    if [ -z "$http_code" ] || [ "$http_code" = "000" ]; then
        log "[DOWN] $name - HTTP sem resposta (URL: $url)"
        return 1
    fi

    # 4. Verifica se nao e codigo de erro 502/503/504
    if [ "$http_code" = "502" ] || [ "$http_code" = "503" ] || [ "$http_code" = "504" ]; then
        log "[WARN] $name - HTTP $http_code (pode ser restart temporario)"
        return 1
    fi

    log "[OK] $name -> $http_code"
    return 0
}

healthcheck() {
    local all_ok=0
    local restart_needed=0

    log "=== Healthcheck ==="

    for pf in "${PFS[@]}"; do
        IFS='|' read -r name port url pattern <<< "$pf"
        if ! check_pf "$name" "$port" "$url" "$pattern"; then
            restart_needed=1
        fi
    done

    if [ $restart_needed -eq 1 ]; then
        log "ALERTA: Reiniciando PFs via bridge..."
        if [ -x "$BRIDGE_SCRIPT" ]; then
            "$BRIDGE_SCRIPT" start >> "$LOG" 2>&1
            log "Bridge restart concluido"
            # Aguarda servicos subirem
            sleep 5
        else
            log "ERRO: $BRIDGE_SCRIPT nao encontrado"
        fi
    fi

    log "=== Healthcheck fim ==="
}

daemon_loop() {
    log "=== PF-HEALTHCHECK DAEMON INICIADO ==="
    while true; do
        healthcheck
        sleep 30
    done
}

case "${1:---once}" in
    --daemon)
        daemon_loop
        ;;
    --once|*)
        healthcheck
        ;;
esac
