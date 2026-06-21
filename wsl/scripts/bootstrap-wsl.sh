#!/bin/bash
set -o pipefail
REPO_DIR="/home/administrator/k8s-portfolio-iac"

echo "=== Bootstrap WSL - k8s-portfolio-iac ==="
echo ""

# 1. Install dependencies
echo "[1/8] Instalando dependencias..."
sudo apt-get update -qq && sudo apt-get install -y -qq socat curl jq 2>/dev/null || true

# Docker Engine nativo (sem Docker Desktop)
if ! command -v docker &>/dev/null; then
    echo "[1.5/8] Instalando Docker Engine nativo no WSL..."
    sudo apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    sudo apt-get update -qq
    sudo apt-get install -y -qq ca-certificates curl gnupg lsb-release
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update -qq
    sudo apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    sudo mkdir -p /etc/docker
    echo '{"exec-opts":["native.cgroupdriver=cgroupfs"]}' | sudo tee /etc/docker/daemon.json
    sudo usermod -aG docker $USER
    sudo systemctl enable docker
    sudo systemctl start docker
    echo "  ✅ Docker Engine $(docker --version) instalado nativamente no WSL"
else
    echo "  ✅ Docker ja instalado: $(docker --version)"
fi

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
