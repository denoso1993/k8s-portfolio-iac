#!/bin/bash
# preflight-check.sh — Verifica dependências antes do bootstrap
# Exit 0 = tudo pronto | Exit 1 = algo faltando

set -e
MISSING=0

echo "=== PRE-FLIGHT CHECK ==="
echo ""

check_dep() {
    local cmd="$1"
    local name="$2"
    local install_hint="$3"
    if command -v "$cmd" &>/dev/null; then
        echo "  ✅ $name ($(command -v $cmd))"
    else
        echo "  ❌ $name — NÃO ENCONTRADO"
        echo "     Instale: $install_hint"
        MISSING=1
    fi
}

echo "[Dependências do Sistema]"
check_dep "docker" "Docker" "curl -fsSL https://get.docker.com | sh"
check_dep "kind" "Kind" "curl -Lo /usr/local/bin/kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64 && chmod +x /usr/local/bin/kind"
check_dep "kubectl" "kubectl" "curl -LO https://dl.k8s.io/release/v1.27.3/bin/linux/amd64/kubectl && chmod +x kubectl && sudo mv kubectl /usr/local/bin/"
check_dep "helm" "Helm" "curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash"
check_dep "cloudflared" "cloudflared" "curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o /usr/local/bin/cloudflared && chmod +x /usr/local/bin/cloudflared"
check_dep "python3" "Python 3" "sudo apt-get install -y python3"
check_dep "socat" "socat" "sudo apt-get install -y socat"
check_dep "curl" "curl" "sudo apt-get install -y curl"
check_dep "jq" "jq" "sudo apt-get install -y jq"
check_dep "openssl" "OpenSSL" "sudo apt-get install -y openssl"
check_dep "git" "Git" "sudo apt-get install -y git"

echo ""
echo "[Configuração]"
# Verificar se WSL está rodando
if grep -q Microsoft /proc/version 2>/dev/null; then
    echo "  ✅ WSL2 detectado"
else
    echo "  ❌ WSL2 — Não parece estar rodando em WSL"
    echo "     Este script deve ser executado DENTRO do WSL2 (Ubuntu)"
    MISSING=1
fi

# Verificar se Docker está rodando
if docker info &>/dev/null; then
    echo "  ✅ Docker Engine rodando"
    # Verificar cgroupfs
    if docker info 2>/dev/null | grep -q cgroupfs; then
        echo "  ✅ Docker cgroupfs configurado (estável para WSL)"
    else
        echo "  ⚠️ Docker não está usando cgroupfs — pode causar instabilidade no WSL"
    fi
else
    echo "  ❌ Docker Engine — não está rodando"
    echo "     Execute: sudo systemctl start docker"
    MISSING=1
fi

# Verificar cloudflared token
if [ -f /etc/cloudflared-token ]; then
    echo "  ✅ Cloudflare token configurado"
else
    echo "  ⚠️ Cloudflare token NÃO configurado"
    echo "     Após o bootstrap, execute: echo 'SEU_TOKEN' | sudo tee /etc/cloudflared-token"
    echo "     Token pode ser obtido em: https://dash.cloudflare.com/ (Zero Trust → Tunnels)"
fi

# Verificar repo está clonado
REPO_DIR="/home/administrator/k8s-portfolio-iac"
if [ -d "$REPO_DIR/.git" ]; then
    echo "  ✅ Repositório clonado em $REPO_DIR"
else
    echo "  ❌ Repositório NÃO encontrado em $REPO_DIR"
    echo "     Execute: git clone https://github.com/denoso1993/k8s-portfolio-iac.git $REPO_DIR"
    MISSING=1
fi

# Verificar arquivos essenciais
ESSENTIAL_FILES=(
    "$REPO_DIR/wsl/scripts/bootstrap-wsl.sh"
    "$REPO_DIR/wsl/scripts/ensure-everything.sh"
    "$REPO_DIR/wsl/services/cluster.target"
    "$REPO_DIR/kind-config.yaml"
)
for f in "${ESSENTIAL_FILES[@]}"; do
    if [ -f "$f" ]; then
        echo "  ✅ $(basename $f) encontrado"
    else
        echo "  ❌ $(basename $f) — NÃO encontrado em $f"
        echo "     O repositório pode estar corrompido ou incompleto"
        MISSING=1
    fi
done

# Recursos do sistema
echo ""
echo "[Recursos do Sistema]"
MEM_TOTAL=$(free -m | awk '/^Mem:/{print $2}')
echo "  💾 RAM total: ${MEM_TOTAL}MB"
if [ "$MEM_TOTAL" -lt 2048 ]; then
    echo "  ⚠️ Menos de 2GB RAM — o cluster pode ficar lento"
fi
DISK_FREE=$(df -h / | awk 'NR==2{print $4}')
echo "  💽 Disco livre: $DISK_FREE"

echo ""
if [ "$MISSING" -eq 0 ]; then
    echo "✅ PRE-FLIGHT PASSED — Tudo pronto para o bootstrap!"
else
    echo "❌ PRE-FLIGHT FAILED — Corrija os itens acima antes de continuar"
fi
exit $MISSING