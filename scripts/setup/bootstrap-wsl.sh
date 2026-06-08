#!/bin/bash
#==========================================================================
# WSL + K8s Portfolio - Bootstrap Din?mico
# Este script NUNCA deve ter valores fixos al?m do essencial.
# Toda config vem dos manifests atuais do reposit?rio.
#==========================================================================
set -e

REPO_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
echo "Repo: $REPO_DIR"

echo "[1/5] WSL + Kernel..."
cp "$REPO_DIR/scripts/setup/.wslconfig" "$HOME/.wslconfig" 2>/dev/null || true
printf "nameserver 8.8.8.8\nnameserver 1.1.1.1\n" > /etc/resolv.conf
chattr +i /etc/resolv.conf 2>/dev/null || true
cp "$REPO_DIR/scripts/setup/99-wsl-memory.conf" /etc/sysctl.d/ 2>/dev/null || true
cp "$REPO_DIR/scripts/setup/99-wsl-network.conf" /etc/sysctl.d/ 2>/dev/null || true
sysctl --system

echo "[2/5] Watchdog..."
cp "$REPO_DIR/scripts/setup/wsl-watchdog.sh" /usr/local/bin/wsl-watchdog.sh
chmod +x /usr/local/bin/wsl-watchdog.sh
cp "$REPO_DIR/scripts/setup/wsl-watchdog.service" /etc/systemd/system/
cp "$REPO_DIR/scripts/setup/wsl-watchdog.timer" /etc/systemd/system/
systemctl daemon-reload
systemctl enable wsl-watchdog.timer --now

echo "[3/5] Docker + Kind + kubectl + Helm (sempre latest)..."
curl -fsSL https://get.docker.com | sh
usermod -aG docker administrator
curl -Lo /usr/local/bin/kind https://kind.sigs.k8s.io/dl/$(curl -s https://api.github.com/repos/kubernetes-sigs/kind/releases/latest | grep tag_name | cut -d'"' -f4)/kind-linux-amd64
chmod +x /usr/local/bin/kind
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl && mv kubectl /usr/local/bin/kubectl
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

echo "[4/5] Cluster + servi?os (do reposit?rio)..."
cd "$REPO_DIR"
kind delete cluster --name lab-sre-denoso 2>/dev/null || true
kind create cluster --name lab-sre-denoso --config kind-config.yaml
kubectl wait --for=condition=Ready node/lab-sre-denoso-control-plane --timeout=180s

# Aplica TUDO que est? em k8s/ (adiciona pastas novas automaticamente)
for dir in k8s/*/; do
  name=$(basename "$dir")
  echo "   Aplicando $name..."
  kubectl apply -R -f "$dir" 2>/dev/null || true
done

# cert-manager (sempre via Helm, repo atual)
helm repo add jetstack https://charts.jetstack.io 2>/dev/null
helm repo update
helm upgrade --install cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace --set installCRDs=true --wait --timeout=5m

# ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml 2>/dev/null || true
kubectl apply -f bootstrap/argocd-app.yaml 2>/dev/null || true

# Monitoring
helm upgrade --install prometheus prometheus-community/prometheus --namespace monitoring --create-namespace --wait --timeout=5m 2>/dev/null || true
helm upgrade --install grafana grafana/grafana --namespace monitoring --create-namespace --wait --timeout=5m 2>/dev/null || true

echo "[5/5] Finalizando..."
nohup kubectl port-forward --address 0.0.0.0 svc/nginx-service -n default 8083:80 > /tmp/fwd.log 2>&1 &

echo ""
echo "============================================="
echo " SETUP DIN?MICO COMPLETO!"
echo " Portfolio: http://$(hostname -I | cut -d' ' -f1):8083/"
echo " Watchdog:  $(systemctl is-active wsl-watchdog.timer)"
echo "============================================="
echo ">> Conforme o projeto crescer, adicione pastas em k8s/"
echo ">> que o bootstrap as aplicar? automaticamente. <<"
echo "============================================="
