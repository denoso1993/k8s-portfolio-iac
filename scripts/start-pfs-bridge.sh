#!/bin/bash
# start-pfs-bridge.sh - Inicia PFs via WSL Bridge (sessao persistente)
# Uso: ./start-pfs-bridge.sh [--kill-only] [--status]
# ============================================================
# WSL Bridge TCP server em 127.0.0.1:5555 mantem sessoes alive
# mesmo quando o terminal pai morre. Ideal para port-forwards.
# ============================================================

BRIDGE_HOST="127.0.0.1"
BRIDGE_PORT=5555
LOG=/tmp/start-pfs-bridge.log

log() { echo "[$(date "+%H:%M:%S")] $*" | tee -a "$LOG"; }

# Envia comando para o bridge e retorna 0 se sucesso.
# Usa -q 2 para nc fechar conexao 2s apos stdin EOF (evita hang 30s do -w).
bridge_send() {
    local cmd="$1"
    local json_cmd
    json_cmd=$(python3 -c "import json,sys; print(json.dumps({'command': sys.argv[1]}))" "$cmd" 2>/dev/null)
    [ -z "$json_cmd" ] && { log "ERRO: falha ao codificar JSON"; return 1; }

    local result
    result=$(echo "$json_cmd" | nc -q 2 "$BRIDGE_HOST" "$BRIDGE_PORT" 2>/dev/null)
    local rc=$?
    if [ $rc -ne 0 ] || [ -z "$result" ]; then
        log "ERRO: bridge sem resposta (rc=$rc)"
        return 1
    fi

    local status
    status=$(echo "$result" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status','error'))" 2>/dev/null)
    if [ "$status" != "success" ]; then
        local err
        err=$(echo "$result" | python3 -c "import sys,json; print(json.load(sys.stdin).get('error','unknown'))" 2>/dev/null)
        log "ERRO bridge: $err"
        return 1
    fi
    return 0
}

# Mata todos os PFs existentes via bridge
kill_pfs() {
    log "Matando PFs existentes..."
    bridge_send "pkill -f 'kubectl.*port-forward' 2>/dev/null; pkill -f 'kubectl.*proxy.*800[12]' 2>/dev/null; sleep 1; echo OK"
    log "PFs mortos"
}

# Inicia todos os PFs via bridge (cada um em nohup separado)
start_pfs() {
    log "Iniciando PFs via bridge..."
    bridge_send "nohup kubectl port-forward --address 0.0.0.0 svc/nginx-service -n default 8083:80 > /tmp/pf-nginx.log 2>&1 &"
    log "  nginx -> 8083"
    bridge_send "nohup kubectl port-forward --address 0.0.0.0 svc/dev-server-service -n default 5500:5500 > /tmp/pf-dev.log 2>&1 &"
    log "  dev-server -> 5500"
    bridge_send "nohup kubectl port-forward --address 0.0.0.0 svc/mobile-server-service -n default 5599:5599 > /tmp/pf-mobile.log 2>&1 &"
    log "  mobile-server -> 5599"
    bridge_send "nohup kubectl port-forward --address 127.0.0.1 svc/grafana -n monitoring 3000:80 > /tmp/pf-grafana.log 2>&1 &"
    log "  grafana -> 3000"
    bridge_send "nohup kubectl proxy --port=8001 --accept-hosts='.*' --address='0.0.0.0' > /tmp/proxy-8001.log 2>&1 &"
    log "  k8s proxy -> 8001"
    log "Todos PFs iniciados via bridge"
}

# Status dos PFs
status_pfs() {
    log "PFs ativos no bridge:"
    bridge_send "ps aux | grep -E 'port-forward|kubectl.*proxy' | grep -v grep"
}

case "${1:-start}" in
    --kill-only|kill) kill_pfs ;;
    --status|status) status_pfs ;;
    start) kill_pfs; sleep 1; start_pfs ;;
    *) echo "Uso: $0 [--kill-only|--status|start]"; exit 1 ;;
esac
