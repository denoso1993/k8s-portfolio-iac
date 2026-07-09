#!/bin/bash
set -e

echo "=== BLOCO 1: Verificar deployment.yaml ==="
echo "--- Checking deployment.yaml for nginx-config/subPath ---"
grep -A5 'nginx-config\|subPath' /home/administrator/k8s-portfolio-iac/wsl/cluster/services/portfolio/deployment.yaml 2>&1 || echo "NO_MATCH"

echo ""
echo "=== BLOCO 2: Corrigir ensure-everything.sh ==="
echo "--- Current ensure-everything.sh content around apply ---"
grep -n 'kubectl apply\|ConfigMap\|nginx-full-config' /home/administrator/k8s-portfolio-iac/wsl/scripts/ensure-everything.sh 2>&1 || echo "NOT_FOUND"

echo ""
echo "--- Applying sed fix ---"
sudo sed -i 's|kubectl apply -f .*wsl/cluster/services/portfolio/|kubectl delete cm nginx-full-config -n default --ignore-not-found 2>/dev/null\nkubectl create cm nginx-full-config -n default --from-file=nginx.conf=/home/administrator/k8s-portfolio-iac/wsl/cluster/services/portfolio/nginx-secure.conf 2>/dev/null\nkubectl apply -f /home/administrator/k8s-portfolio-iac/wsl/cluster/services/portfolio/deployment.yaml 2>/dev/null\nkubectl apply -f /home/administrator/k8s-portfolio-iac/wsl/cluster/services/portfolio/service-nginx.yaml 2>/dev/null|' /home/administrator/k8s-portfolio-iac/wsl/scripts/ensure-everything.sh 2>&1 && echo 'ENSURE_EVERYTHING_CORRIGIDO'

echo ""
echo "--- Post-fix ensure-everything.sh ---"
grep -n 'kubectl apply\|ConfigMap\|nginx-full-config' /home/administrator/k8s-portfolio-iac/wsl/scripts/ensure-everything.sh 2>&1 || echo "NOT_FOUND"

echo ""
echo "=== BLOCO 3: Atualizar ultimate-watchdog para K3s ==="
sudo sed -i 's|kind get clusters|systemctl is-active k3s.service|g' /home/administrator/k8s-portfolio-iac/wsl/scripts/ultimate-watchdog.sh 2>&1 || true
sudo sed -i 's|CLUSTER_NAME="lab-sre-denoso"|CLUSTER_NAME="k3s"|g' /home/administrator/k8s-portfolio-iac/wsl/scripts/ultimate-watchdog.sh 2>&1 || true
echo 'WATCHDOG_ATUALIZADO'

echo ""
echo "--- Verifying watchdog changes ---"
grep -n 'systemctl\|CLUSTER_NAME' /home/administrator/k8s-portfolio-iac/wsl/scripts/ultimate-watchdog.sh 2>&1 || echo "NOT_FOUND"

echo ""
echo "=== BLOCO 4: Git commit ==="
cd /home/administrator/k8s-portfolio-iac
git add -A
echo "--- Git Status ---"
git status
echo "--- Committing ---"
git commit -m "fix: ConfigMap nginx com chave nginx.conf + watchdog K3s"
echo "--- Pushing ---"
git push origin main 2>&1 || echo "PUSH_FAILED"

echo ""
echo "=== BLOCO 5: Teste final ==="
echo "--- Waiting 10s ---"
sleep 10
echo "31701: $(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 5 http://localhost:31701/ 2>&1)"
echo "8083: $(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 5 http://localhost:8083/ 2>&1)"
echo "SITE: $(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 10 https://denisdeoliveira.com.br/ 2>&1)"
kubectl get nodes 2>&1 | head -2

echo ""
echo "=== ALL BLOCKS COMPLETE ==="
