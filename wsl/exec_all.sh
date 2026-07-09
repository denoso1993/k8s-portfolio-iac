#!/bin/bash
set -e

echo "=============================================="
echo "1. LOG DO POD"
echo "=============================================="
POD=$(kubectl get pods -n default -l app=nginx -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$POD" ]; then
  kubectl logs -n default "$POD" --tail=10 2>&1
else
  echo "No pod found"
fi

echo ""
echo "=============================================="
echo "2. EXEC DENTRO DO POD - curl test"
echo "=============================================="
POD=$(kubectl get pods -n default -l app=nginx -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$POD" ]; then
  kubectl exec -n default "$POD" -- curl -s -o /dev/null -w '%{http_code}\n' --connect-timeout 3 http://localhost:8080/ 2>&1
else
  echo "No pod found"
fi

echo ""
echo "=============================================="
echo "3. VERIFICAR NGINX DENTRO DO POD"
echo "=============================================="
POD=$(kubectl get pods -n default -l app=nginx -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$POD" ]; then
  kubectl exec -n default "$POD" -- ps aux 2>&1 | grep nginx
else
  echo "No pod found"
fi

echo ""
echo "=============================================="
echo "4. RECRIAR TUDO DO ZERO"
echo "=============================================="
kubectl delete deployment nginx-deployment -n default --ignore-not-found 2>&1
kubectl delete cm nginx-html-config -n default --ignore-not-found 2>&1
kubectl delete cm nginx-full-config -n default --ignore-not-found 2>&1
kubectl delete svc nginx-service -n default --ignore-not-found 2>&1
sleep 5

echo ""
echo "--- Creating ConfigMaps ---"
kubectl create cm nginx-full-config -n default --from-file=nginx.conf=/home/administrator/k8s-portfolio-iac/wsl/cluster/services/portfolio/nginx-secure.conf 2>&1
kubectl create cm nginx-html-config -n default --from-file=index.html=/home/administrator/k8s-portfolio-iac/wsl/cluster/services/portfolio/html/prod-index.html 2>&1

echo ""
echo "--- Applying Deployment ---"
kubectl apply -f /home/administrator/k8s-portfolio-iac/wsl/cluster/services/portfolio/deployment.yaml 2>&1
sleep 20

echo ""
echo "--- Exposing Service ---"
kubectl expose deployment nginx-deployment -n default --port=80 --target-port=8080 --name=nginx-service --type=NodePort 2>&1
kubectl patch svc nginx-service -n default -p '{"spec":{"ports":[{"port":80,"targetPort":8080,"nodePort":31701}]}}' 2>&1
sleep 15

echo ""
echo "--- Checking Pods and Endpoints ---"
kubectl get pods -n default -l app=nginx 2>&1
kubectl get endpoints nginx-service -n default 2>&1

echo ""
echo "--- Testing Local Ports ---"
echo "31701: $(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 10 http://localhost:31701/ 2>&1)"
echo "8083: $(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 10 http://localhost:8083/ 2>&1)"
sleep 15

echo ""
echo "--- Testing External ---"
echo "EXTERNO: $(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 15 https://denisdeoliveira.com.br/ 2>&1)"

echo ""
echo "=============================================="
echo "COMPLETO"
echo "=============================================="
