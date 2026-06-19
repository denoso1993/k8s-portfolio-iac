#!/bin/bash
set -o pipefail
REPO_DIR="/home/administrator/k8s-portfolio-iac"

echo "=== Bootstrap WSL - k8s-portfolio-iac ==="
echo ""

# 1. Install dependencies
echo "[1/8] Instalando dependencias..."
sudo apt-get update -qq && sudo apt-get install -y -qq socat curl jq 2>/dev/null || true

# 2. Copy systemd services
echo "[2/8] Instalando systemd services..."
sudo cp -r "$REPO_DIR/wsl/services/"* /etc/systemd/system/ 2>/dev/null || true
sudo systemctl daemon-reload

# 3. Enable all services
echo "[3/8] Habilitando services..."
sudo systemctl enable ultimate-watchdog.service ensure-cluster.service 2>/dev/null || true
sudo systemctl enable cloudflared-tunnel.service 2>/dev/null || true

# 4. Create Docker daemon config (cgroupfs for WSL stability)
echo "[4/8] Configurando Docker..."
sudo mkdir -p /etc/docker
echo '{"exec-opts":["native.cgroupdriver=cgroupfs"]}' | sudo tee /etc/docker/daemon.json
sudo systemctl restart docker 2>/dev/null || true
sleep 5

# 5. Start the cluster
echo "[5/8] Iniciando cluster..."
bash "$REPO_DIR/wsl/scripts/ensure-everything.sh"

# 6. Start watchdog
echo "[6/8] Iniciando watchdog..."
sudo systemctl restart ultimate-watchdog.service 2>/dev/null || true

# 7. Verify
echo "[7/8] Verificando..."
sleep 10
for p in 8083 8084 5500 5599 5598 3000; do
    code=$(curl -s --connect-timeout 3 -o /dev/null -w '%{http_code}' http://localhost:$p/ 2>/dev/null || echo "000")
    echo "  localhost:$p -> $code"
done

echo ""
echo "[8/8] Bootstrap completo!"
echo "Acesse: https://denisdeoliveira.com.br"
