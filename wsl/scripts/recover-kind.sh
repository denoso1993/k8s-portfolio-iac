#!/bin/bash
# recover-kind.sh v2 - Recovery com validacao completa
LOG=/var/log/recover-kind.log
exec 2>>$LOG
echo "[$(date)] === RECOVER ===" >> $LOG

# 1. Docker
for i in $(seq 1 30); do docker info &>/dev/null && break; sleep 2; done

# 2. Kind
if ! kind get clusters 2>/dev/null | grep -q lab-sre; then
  echo "[$(date)] Criando cluster..." >> $LOG
  cd /home/administrator/k8s-portfolio-iac
  kind create cluster --name lab-sre-denoso --config kind-config.yaml >> $LOG 2>&1
  sleep 20
fi

# 3. Kubeconfig + manifests
kind get kubeconfig --name lab-sre-denoso > /root/.kube/config 2>/dev/null
kubectl apply -f /home/administrator/k8s-portfolio-iac/wsl/cluster/services/portfolio/ >> $LOG 2>&1
kubectl expose deployment nginx-deployment -n default --port=80 --target-port=8080 --name=nginx-service --type=NodePort 2>/dev/null
kubectl patch svc nginx-service -n default -p '{"spec":{"ports":[{"port":80,"targetPort":8080,"nodePort":31701}]}}' 2>/dev/null
kubectl create cm nginx-html-config -n default --from-file=index.html=/home/administrator/k8s-portfolio-iac/wsl/cluster/services/portfolio/html/prod-index.html 2>/dev/null
kubectl delete pod -n default -l app=nginx --force --grace-period=0 >> $LOG 2>&1
sleep 30

# 4. Restart socats (com IP dinamico via socat-forward.sh)
for s in socat-8083 socat-8084 socat-5500 socat-5599 socat-5598 socat-3000 cloudflared-tunnel; do
  systemctl restart $s.service 2>/dev/null || true
done
sleep 15

# 5. Validacao
echo "[$(date)] === VALIDACAO ===" >> $LOG
sleep 15
curl -s -o /dev/null -w '%{http_code}' --connect-timeout 10 https://denisdeoliveira.com.br/ >> $LOG 2>&1
echo " [SITE]" >> $LOG
kubectl get pods -n default -l app=nginx --no-headers 2>&1 | head -2 >> $LOG
echo "[$(date)] === RECOVER CONCLUIDO ===" >> $LOG
