#!/bin/bash
set -e

echo "[$(date)] === Starting Portfolio Cluster ==="

# 1. Check if kind cluster exists
if ! kind get clusters 2>/dev/null | grep -q lab-sre-denoso; then
    echo "[$(date)] Creating Kind cluster..."
    kind create cluster --name lab-sre-denoso --config /home/administrator/k8s-portfolio-iac/kind-config.yaml
    echo "[$(date)] Waiting for cluster readiness..."
    sleep 30
    kubectl apply -f /home/administrator/k8s-portfolio-iac/k8s/services/portfolio/
    kubectl apply -f /home/administrator/k8s-portfolio-iac/k8s/infrastructure/
else
    echo "[$(date)] Cluster already exists"
fi

# 2. Kubectl proxy
if ! pgrep -f "kubectl proxy.*8001" > /dev/null 2>&1; then
    echo "[$(date)] Starting kubectl proxy..."
    nohup kubectl proxy --address=0.0.0.0 --port=8001 --accept-hosts=.* > /tmp/kubectl-proxy.log 2>&1 &
fi

# 3. Port-forward nginx
if ! pgrep -f "kubectl port-forward.*nginx.*8083" > /dev/null 2>&1; then
    echo "[$(date)] Starting port-forward nginx:8083..."
    nohup kubectl port-forward --address 0.0.0.0 svc/nginx-service -n default 8083:80 > /tmp/port-forward-nginx.log 2>&1 &
fi

# 4. Port-forward grafana
if ! pgrep -f "kubectl port-forward.*grafana.*3000" > /dev/null 2>&1; then
    echo "[$(date)] Starting port-forward grafana:3000..."
    nohup kubectl port-forward --address 0.0.0.0 svc/grafana -n monitoring 3000:80 > /tmp/port-forward-grafana.log 2>&1 &
fi

echo "[$(date)] === Ready ==="
echo "Portfolio: http://localhost:8083"
echo "Grafana:   http://localhost:3000"
