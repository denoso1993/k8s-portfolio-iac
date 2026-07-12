#!/bin/bash
# setup.sh - Configura o cluster do zero (executar dentro do WSL)
set -e

echo "=== K8s Portfolio IAC - Setup ==="
echo "[1/6] Instalando dependencias..."
sudo apt-get update -qq
sudo apt-get install -y -qq docker.io curl socat git

echo "[2/6] Iniciando Docker..."
sudo systemctl enable docker.service
sudo systemctl start docker.service

echo "[3/6] Instalando Kind..."
curl -Lo /tmp/kind https://kind.sigs.k8s.io/dl/latest/kind-linux-amd64
sudo mv /tmp/kind /usr/local/bin/kind && sudo chmod +x /usr/local/bin/kind

echo "[4/6] Instalando kubectl..."
curl -LO https://dl.k8s.io/release/v1.27.3/bin/linux/amd64/kubectl
chmod +x kubectl && sudo mv kubectl /usr/local/bin/

echo "[5/6] Instalando cloudflared..."
curl -sL https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o /tmp/cloudflared
chmod +x /tmp/cloudflared && sudo mv /tmp/cloudflared /usr/local/bin/

echo "[6/6] Instalando servicos systemd..."
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
for svc in systemd/*.service; do
  sudo cp "$svc" /etc/systemd/system/
  sudo systemctl enable "$(basename "$svc")"
done
sudo systemctl daemon-reload

echo "=== Setup concluido! Execute: bash $REPO_DIR/wsl/scripts/ensure-cluster.sh ==="
