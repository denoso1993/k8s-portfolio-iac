#!/bin/bash
LOG=/var/log/portfolio-watchdog.log
K8S_BASE=/home/administrator/k8s-portfolio-iac/k8s
log() { echo "[$(date "+%Y-%m-%d %H:%M:%S")] $*" >> $LOG; }
sleep 30
while true; do
  for entry in "8083:svc/nginx-service:80:default:Site" "3000:svc/grafana:80:monitoring:Grafana" "5500:svc/dev-server-service:5500:default:Dev" "5599:svc/mobile-server-service:5599:default:Mobile"; do
    port=$(echo $entry | cut -d: -f1)
    svc=$(echo $entry | cut -d: -f2)
    target=$(echo $entry | cut -d: -f3)
    ns=$(echo $entry | cut -d: -f4)
    name=$(echo $entry | cut -d: -f5)
    pgrep -f "port-forward.*:$port" >/dev/null 2>&1 || {
      log "RESTART: $name"
      nohup kubectl port-forward --address 0.0.0.0 $svc -n $ns $port:$target > /tmp/pf-$port.log 2>&1 &
    }
  done
  pgrep -f "kubectl proxy.*8002" >/dev/null 2>&1 || kubectl proxy --port=8002 --accept-hosts='localhost|127.0.0.1' --address="0.0.0.0" > /tmp/proxy-8002.log 2>&1 &
  kubectl get pod -l app=nginx -n default --no-headers 2>/dev/null | grep -q Running || kubectl apply -R -f $K8S_BASE/services/portfolio/ 2>/dev/null
  sleep 15
done