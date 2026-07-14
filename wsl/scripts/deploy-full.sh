#!/bin/bash
set -e
kind delete cluster --name lab-sre-denoso 2>/dev/null
cd /home/administrator/k8s-portfolio-iac && bash wsl/scripts/ensure-cluster.sh 2>&1 | tail -3
sleep 30
docker pull nginxinc/nginx-unprivileged:1.25-alpine 2>/dev/null | tail -1
kind load docker-image nginxinc/nginx-unprivileged:1.25-alpine --name lab-sre-denoso 2>/dev/null
kubectl create cm nginx-html-config -n default --from-file=index.html=/home/administrator/k8s-portfolio-iac/wsl/cluster/services/portfolio/html/prod-index.html 2>/dev/null
kubectl delete pod -n default -l app=nginx --force --grace-period=0 2>/dev/null
sleep 25
IP=$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' lab-sre-denoso-control-plane)
echo "31701: $(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 5 http://$IP:31701/ 2>&1)"
nohup socat TCP-LISTEN:8083,fork,reuseaddr TCP:$IP:31701 &>/dev/null &
systemctl restart cloudflared-tunnel.service 2>/dev/null || nohup cloudflared tunnel --config /home/administrator/.cloudflared/config.yml run &>/dev/null &
sleep 15
echo "8083: $(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 5 http://localhost:8083/ 2>&1)"
echo "SITE: $(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 15 https://denisdeoliveira.com.br/ 2>&1)"
