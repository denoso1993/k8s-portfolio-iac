#!/bin/bash
set -e

echo "=== PASSO 1: Docker + Cluster ==="
systemctl start docker.service 2>&1
kind delete cluster --name lab-sre-denoso 2>/dev/null
rm -rf /sys/fs/cgroup/docker 2>/dev/null
cd /home/administrator/k8s-portfolio-iac && bash wsl/scripts/ensure-cluster.sh 2>&1 | tail -5

echo "=== PASSO 2: Nginx ==="
sleep 30
docker pull nginxinc/nginx-unprivileged:1.25-alpine 2>/dev/null | tail -1
kind load docker-image nginxinc/nginx-unprivileged:1.25-alpine --name lab-sre-denoso 2>/dev/null
kubectl create cm nginx-html-config -n default --from-file=index.html=/home/administrator/k8s-portfolio-iac/wsl/cluster/services/portfolio/html/prod-index.html 2>/dev/null
kubectl delete pod -n default -l app=nginx --force --grace-period=0 2>/dev/null
sleep 25
IP=$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' lab-sre-denoso-control-plane)
nohup socat TCP-LISTEN:8083,fork,reuseaddr TCP:$IP:31701 &>/dev/null &
sleep 3
echo "8083: $(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 5 http://localhost:8083/ 2>&1)"

echo "=== PASSO 3: Cloudflared ==="
pkill -f cloudflared 2>/dev/null
nohup cloudflared tunnel --config /home/administrator/.cloudflared/config.yml run &>/dev/null &
sleep 15
echo "SITE: $(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 15 https://denisdeoliveira.com.br/ 2>&1)"

echo "=== PASSO 4: Grafana ==="
kubectl apply -f /home/administrator/k8s-portfolio-iac/wsl/cluster/monitoring/ 2>/dev/null
kubectl patch svc grafana -n monitoring -p '{"spec":{"type":"NodePort"}}' 2>/dev/null
kubectl create cm grafana -n monitoring --from-literal=grafana.ini="[server]\nroot_url = https://denisdeoliveira.com.br/grafana/\nserve_from_sub_path = true\n[auth.anonymous]\nenabled = true\norg_role = Viewer\n[security]\nallow_embedding = true" 2>/dev/null
kubectl delete pod -n monitoring -l app.kubernetes.io/name=grafana --force --grace-period=0 2>/dev/null
sleep 25
NP=$(kubectl get svc grafana -n monitoring -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null)
pkill -f 'socat.*3000' 2>/dev/null
nohup socat TCP-LISTEN:3000,fork,reuseaddr TCP:$IP:$NP &>/dev/null &
sleep 5
echo "3000: $(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 5 http://localhost:3000/ 2>&1)"
echo "GRAFANA: $(curl -s -o /dev/null -w '%{http_code}' -H 'Host: grafana.denisdeoliveira.com.br' --connect-timeout 5 http://localhost:3000/ 2>&1)"

echo "=== PASSO 5: Verificação Final ==="
echo "SITE: $(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 15 https://denisdeoliveira.com.br/ 2>&1)"
echo "8083: $(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 5 http://localhost:8083/ 2>&1)"
echo "GRAFANA: $(curl -s -o /dev/null -w '%{http_code}' -H 'Host: grafana.denisdeoliveira.com.br' --connect-timeout 5 http://localhost:3000/ 2>&1)"
echo "=== RECUPERAÇÃO CONCLUÍDA ==="
