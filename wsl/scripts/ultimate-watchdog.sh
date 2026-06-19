#!/bin/bash
# Ultimate watchdog - keeps cloudflared, cluster, and socats alive
# Runs as a simple background process, no systemd dependency

CLUSTER_NAME="lab-sre-denoso"
TOKEN="eyJhIjoiN2ZjMzE1OTJkMTFmZjMwYzQ4OTA2MzdjNGQyNjFmZjciLCJ0IjoiNGY1YzBiNmMtZGFmYi00NTBlLTk0ZGQtNWIwZjk4ZTM0NTY0IiwicyI6IlltUTRPR001TmprdE5XRXhOeTAwWVRNeUxUZ3dORGd0WkRZelpqSmlZVEJsT0RsayJ9"

while true; do
    # 1. Check cluster - recreate if missing
    if ! kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
        echo "[$(date)] Cluster down. Recreating..."
        cd /home/administrator/k8s-portfolio-iac
        kind create cluster --name "${CLUSTER_NAME}" --config kind-config.yaml
        kubectl wait --for=condition=Ready nodes --all --timeout=120s
        kubectl apply -f wsl/cluster/services/portfolio/ 2>/dev/null || true
        kubectl apply -f wsl/cluster/infrastructure/ingress-controller.yaml 2>/dev/null || true
        docker update --restart=always "${CLUSTER_NAME}-control-plane" 2>/dev/null || true
        echo "[$(date)] Cluster recreated!"
    fi
    
    # 2. Check cloudflared - restart if dead
    if ! pgrep -f "cloudflared tunnel" > /dev/null 2>&1; then
        echo "[$(date)] Cloudflared down. Restarting..."
        nohup cloudflared tunnel run --token "${TOKEN}" > /tmp/cloudflared.log 2>&1 &
        echo "[$(date)] Cloudflared restarted!"
    fi
    
    # 3. Check socat-8084 - restart if dead
    if ! ss -tlnp | grep -q ":8084 "; then
        echo "[$(date)] Socat-8084 down. Restarting..."
        sudo systemctl restart socat-8084.service 2>/dev/null || \
        nohup socat TCP-LISTEN:8084,fork,reuseaddr TCP:172.18.0.2:31701 > /tmp/socat-8084.log 2>&1 &
        echo "[$(date)] Socat restarted!"
    fi
    
    sleep 15
done
