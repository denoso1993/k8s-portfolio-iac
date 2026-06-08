#!/bin/bash
#===================================================================
# WSL + K8s Portfolio - Setup P?s-Formata??o
# Local: scripts/setup/bootstrap-wsl.sh
# Uso:  wsl -u root -d Ubuntu -e bash bootstrap-wsl.sh
#   ou: bash scripts/setup/bootstrap-wsl.sh
#===================================================================
set -e

REPO_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
SETUP_DIR="$REPO_DIR/scripts/setup"

echo "============================================="
echo " WSL + K8s Portfolio - Setup Completo"
echo " Repo: $REPO_DIR"
echo "============================================="

echo "[1/8] Configurando WSL..."
cp "$SETUP_DIR/.wslconfig" "$HOME/.wslconfig" 2>/dev/null || true
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 1.1.1.1" >> /etc/resolv.conf
chattr +i /etc/resolv.conf 2>/dev/null || true

echo "[2/8] Otimiza??es de kernel..."
cp "$SETUP_DIR/99-wsl-memory.conf" /etc/sysctl.d/
cp "$SETUP_DIR/99-wsl-network.conf" /etc/sysctl.d/
sysctl --system

echo "[3/8] Instalando watchdog..."
cp "$SETUP_DIR/wsl-watchdog.sh" /usr/local/bin/wsl-watchdog.sh
chmod +x /usr/local/bin/wsl-watchdog.sh
cp "$SETUP_DIR/wsl-watchdog.service" /etc/systemd/system/
cp "$SETUP_DIR/wsl-watchdog.timer" /etc/systemd/system/
systemctl daemon-reload
systemctl enable wsl-watchdog.timer --now

echo "[4/8] Instalando Docker + Kind + kubectl + Helm..."
curl -fsSL https://get.docker.com | sh
usermod -aG docker administrator
curl -Lo /usr/local/bin/kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x /usr/local/bin/kind
curl -LO https://dl.k8s.io/release/v1.27.3/bin/linux/amd64/kubectl
chmod +x kubectl && mv kubectl /usr/local/bin/kubectl
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

echo "[5/8] Criando cluster Kubernetes..."
cd "$REPO_DIR"
kind delete cluster --name lab-sre-denoso 2>/dev/null || true
kind create cluster --name lab-sre-denoso --config kind-config.yaml
kubectl wait --for=condition=Ready node/lab-sre-denoso-control-plane --timeout=180s

echo "[6/8] Deployando servi?os..."
kubectl create ns ingress-nginx --dry-run=client -o yaml | kubectl apply -f -
kubectl create ns cert-manager --dry-run=client -o yaml | kubectl apply -f -
helm upgrade --install cert-manager jetstack/cert-manager --namespace cert-manager --set installCRDs=true --wait --timeout=5m
kubectl apply -f k8s/infrastructure/metrics-server.yaml
kubectl apply -f k8s/infrastructure/ingress-controller.yaml
sleep 15
kubectl patch validatingwebhookconfiguration ingress-nginx-admission --type=json -p='[{"op":"replace","path":"/webhooks/0/failurePolicy","value":"Ignore"}]' 2>/dev/null || true
kubectl apply -f k8s/security/
kubectl apply -f k8s/services/portfolio/
kubectl apply -f k8s/services/postgres/
kubectl apply -f k8s/infrastructure/nginx-ingress.yaml

echo "[7/8] Otimizando recursos..."
kubectl set resources deployment nginx-deployment -n default --requests=cpu=50m,memory=64Mi --limits=cpu=100m,memory=128Mi
kubectl scale deployment ingress-nginx-controller -n ingress-nginx --replicas=1

echo "[8/8] Iniciando port-forward..."
nohup kubectl port-forward --address 0.0.0.0 svc/nginx-service -n default 8083:80 > /tmp/fwd.log 2>&1 &

sleep 5
echo ""
echo "============================================="
echo " SETUP COMPLETO!"
WSLIP=$(hostname -I | cut -d" " -f1)
echo " Portfolio: http://$WSLIP:8083/"
echo " Watchdog:  $(systemctl is-active wsl-watchdog.timer)"
echo " Mem?ria:   3GB (limite)"
echo "============================================="
