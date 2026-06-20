#!/bin/bash
# setup-cloudflared-token.sh — Gerencia token do Cloudflare Tunnel
# Uso: setup-cloudflared-token.sh [--check | --set]

TOKEN_FILE="/etc/cloudflared-token"
SERVICE_NAME="cloudflared-tunnel.service"

check_token() {
    if [ ! -f "$TOKEN_FILE" ]; then
        echo "❌ Token do Cloudflare NÃO configurado"
        echo ""
        echo "Para configurar:"
        echo "  1. Acesse https://dash.cloudflare.com/"
        echo "  2. Vá em Zero Trust → Networks → Tunnels"
        echo "  3. Crie ou copie o token do tunnel"
        echo "  4. Execute: echo 'SEU_TOKEN_AQUI' | sudo tee $TOKEN_FILE"
        echo "  5. Execute: sudo systemctl restart $SERVICE_NAME"
        return 1
    fi

    TOKEN=$(cat "$TOKEN_FILE" | tr -d '\n\r ')
    if [ ${#TOKEN} -lt 10 ]; then
        echo "❌ Token do Cloudflare parece inválido (muito curto)"
        echo "   Tamanho atual: ${#TOKEN} caracteres"
        echo "   Reconfigure com: echo 'TOKEN_VALIDO' | sudo tee $TOKEN_FILE"
        return 1
    fi

    echo "✅ Token do Cloudflare configurado (${#TOKEN} caracteres)"

    # Verificar se o service está rodando
    if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
        echo "✅ $SERVICE_NAME está ativo"
    else
        echo "⚠️  $SERVICE_NAME não está rodando"
        echo "   Execute: sudo systemctl restart $SERVICE_NAME"
    fi

    # Testar conectividade com Cloudflare
    if curl -s -o /dev/null -w '' --connect-timeout 5 https://api.cloudflare.com 2>/dev/null; then
        echo "✅ Conectividade com Cloudflare API OK"
    else
        echo "⚠️  Sem conectividade com Cloudflare (esperado se offline)"
    fi

    return 0
}

set_token() {
    if [ -z "$2" ]; then
        echo "Uso: $0 --set SEU_TOKEN"
        exit 1
    fi
    echo "$2" | sudo tee "$TOKEN_FILE" > /dev/null
    sudo chmod 600 "$TOKEN_FILE"
    echo "✅ Token salvo em $TOKEN_FILE"
    sudo systemctl restart "$SERVICE_NAME" 2>/dev/null || true
}

case "${1:-}" in
    --check)
        check_token
        ;;
    --set)
        set_token "$@"
        ;;
    *)
        echo "Uso: $0 [--check | --set TOKEN]"
        echo "  --check              Verifica status do token (usa no bootstrap)"
        echo "  --set TOKEN          Salva token e reinicia tunnel"
        ;;
esac
