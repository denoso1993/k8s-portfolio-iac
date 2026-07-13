#!/bin/bash
# recover-kind.sh v3 - Recovery completo com validacao
LOG=/var/log/recover-kind.log
exec 2>>$LOG
echo "[$(date)] === RECOVER v3 ===" >> $LOG

# 1. Fix DNS (necessario para puxar imagens)
echo "nameserver 8.8.8.8" > /etc/resolv.conf 2>/dev/null || true

# 2. Docker
for i in $(seq 1 30); do docker info &>/dev/null && break; sleep 2; done
echo "[$(date)] Docker OK" >> $LOG

# 3. Kind
if ! kind get clusters 2>/dev/null | grep -q lab-sre; then
  echo "[$(date)] Criando cluster..." >> $LOG
  cd /home/administrator/k8s-portfolio-iac
  kind create cluster --name lab-sre-denoso --config kind-config.yaml >> $LOG 2>&1
  sleep 20
fi

# 4. Kubeconfig
kind get kubeconfig --name lab-sre-denoso > /root/.kube/config 2>/dev/null
echo "[$(date)] Kubeconfig OK" >> $LOG

# 5. Manifests
kubectl apply -f /home/administrator/k8s-portfolio-iac/wsl/cluster/services/portfolio/ >> $LOG 2>&1
kubectl expose deployment nginx-deployment -n default --port=80 --target-port=8080 --name=nginx-service --type=NodePort 2>/dev/null
kubectl patch svc nginx-service -n default -p '{"spec":{"ports":[{"port":80,"targetPort":8080,"nodePort":31701}]}}' 2>/dev/null

# 6. ConfigMap de HTML
kubectl create cm nginx-html-config -n default --from-file=index.html=/home/administrator/k8s-portfolio-iac/wsl/cluster/services/portfolio/html/prod-index.html 2>/dev/null

# 7. Carregar imagem no Kind (essencial!)
kind load docker-image nginxinc/nginx-unprivileged:1.25-alpine --name lab-sre-denoso >> $LOG 2>&1
echo "[$(date)] Imagem carregada" >> $LOG

# 8. Recriar pods
kubectl delete pod -n default -l app=nginx --force --grace-period=0 >> $LOG 2>&1
sleep 20

# 9. Aguardar pods ficarem Ready
kubectl wait --for=condition=Ready pods -l app=nginx -n default --timeout=60s >> $LOG 2>&1 || true
echo "[$(date)] Pods OK" >> $LOG

# 10. Restart socats + cloudflared
for s in socat-8083 socat-3000 cloudflared-tunnel; do
  systemctl restart $s.service 2>/dev/null || true
done
sleep 15

# 11. Validacao
echo "[$(date)] === VALIDACAO ===" >> $LOG
for url in "http://localhost:8083/" "https://denisdeoliveira.com.br/"; do
  code=$(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 10 "$url" 2>/dev/null)
  echo "[$(date)] $url -> $code" >> $LOG
done
kubectl get pods -A --no-headers 2>/dev/null | head -10 >> $LOG
echo "[$(date)] === RECOVER CONCLUIDO ===" >> $LOG