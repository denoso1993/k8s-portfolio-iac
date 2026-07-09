#!/bin/bash
LOG=/var/log/portfolio-full-recovery.log
K8S_BASE=/home/administrator/k8s-portfolio-iac/k8s
CLUSTER=lab-sre-denoso
WSL_IP=$(hostname -I | awk "{print \$1}")
log() { echo "[$(date "+%H:%M:%S")] $*" >> $LOG; }
log "=== RECOVERY START ==="
echo "$WSL_IP" > /tmp/wsl-ip.txt
if ! kind get clusters 2>/dev/null | grep -q $CLUSTER; then
  log "Creating Kind cluster..."
  kind create cluster --name $CLUSTER --config $K8S_BASE/../scripts/bootstrap/kind-config.yaml
  sleep 30
fi
kubectl wait --for=condition=Ready nodes --all --timeout=180s
for dir in infrastructure security security/network-policies services/postgres services/portfolio; do
  d="$K8S_BASE/$dir"; [ -d "$d" ] && kubectl apply -R -f "$d" 2>/dev/null && log "OK: $dir" || log "WARN: $dir"
done
for label in "app=nginx" "app=dev-server" "app=mobile-server" "app=postgres"; do
  kubectl wait --for=condition=Ready pod -l $label -n default --timeout=120s 2>/dev/null || true
done
bash /home/administrator/k8s-portfolio-iac/scripts/install-monitoring.sh 2>/dev/null
for p in 8083:svc/nginx-service:80:default 3000:svc/grafana:80:monitoring 5500:svc/dev-server-service:5500:default 5599:svc/mobile-server-service:5599:default; do
  port=$(echo $p | cut -d: -f1)
  svc=$(echo $p | cut -d: -f2)
  target=$(echo $p | cut -d: -f3)
  ns=$(echo $p | cut -d: -f4)
  nohup kubectl port-forward --address 0.0.0.0 $svc -n $ns $port:$target > /tmp/pf-$port.log 2>&1 &
done
kubectl proxy --port=8002 --accept-hosts='localhost|127.0.0.1' --address='127.0.0.1' > /tmp/proxy-8002.log 2>&1 &
log "=== RECOVERY COMPLETE ==="