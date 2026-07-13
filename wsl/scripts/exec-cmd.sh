#!/bin/bash
set -e

echo "=== 2: Docker DNS + restart ==="
cat > /etc/docker/daemon.json << 'EOF'
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "dns": ["8.8.8.8", "1.1.1.1"]
}
EOF

systemctl restart docker.service 2>&1
sleep 5
systemctl is-active docker.service 2>&1
docker info > /dev/null 2>&1 && echo 'DOCKER_OK' || echo 'DOCKER_FALHOU'

echo ""
echo "=== 3: Recriar cluster ==="
kind delete cluster --name lab-sre-denoso 2>/dev/null
cd /home/administrator/k8s-portfolio-iac && bash wsl/scripts/ensure-cluster.sh 2>&1 | tail -10

echo ""
echo "=== 4: Subir nginx ==="
sleep 30
kind load docker-image nginxinc/nginx-unprivileged:1.25-alpine --name lab-sre-denoso 2>&1

echo "Criando configmap..."
kubectl create cm nginx-html-config -n default \
  --from-file=index.html=/home/administrator/k8s-portfolio-iac/wsl/cluster/services/portfolio/html/prod-index.html 2>/dev/null

echo "Deletando pods velhos..."
kubectl delete pod -n default -l app=nginx --force --grace-period=0 2>/dev/null

echo "Aguardando 25s..."
sleep 25
echo "--- pods ---"
kubectl get pods -n default -l app=nginx 2>&1

IP=$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' lab-sre-denoso-control-plane)
echo "31701: $(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 5 http://$IP:31701/ 2>&1)"

echo ""
echo "=== 5: Subir socat + cloudflared + site ==="
systemctl restart socat-8083.service 2>&1 || echo "socat service not found"
systemctl restart cloudflared-tunnel.service 2>&1 || echo "cloudflared service not found"
sleep 15
echo "8083: $(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 5 http://localhost:8083/ 2>&1)"
echo "SITE: $(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 15 https://denisdeoliveira.com.br/ 2>&1)"
