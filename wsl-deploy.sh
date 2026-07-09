#!/bin/bash
echo "=== BLOCO A ==="
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config 2>&1
sudo chown administrator:administrator ~/.kube/config 2>&1
chmod 600 ~/.kube/config 2>&1
sed -i "s/127.0.0.1/localhost/" ~/.kube/config
kubectl get nodes 2>&1 && echo "KUBECONFIG_OK" || echo "KUBECONFIG_FALHOU"
echo "=== BLOCO B ==="
kubectl get svc nginx-service -n default -o jsonpath="nginx NodePort: {.spec.ports[0].nodePort}{\"\n\"}" 2>&1
echo "---"
kubectl get pods -n default -l app=nginx 2>&1
echo "=== BLOCO C ==="
curl -s -o /dev/null -w "NODEPORT_31701: %{http_code}\n" --connect-timeout 5 http://localhost:31701/ 2>&1
echo "=== BLOCO D ==="
sudo systemctl restart socat-8083.service 2>&1
sleep 3
curl -s -o /dev/null -w "LOCAL_8083: %{http_code}\n" --connect-timeout 5 http://localhost:8083/ 2>&1
echo "=== BLOCO E ==="
curl -s -o /dev/null -w "EXTERNO: %{http_code}\n" --connect-timeout 10 https://denisdeoliveira.com.br/ 2>&1
echo "=== BLOCO F ==="
kind delete cluster --name lab-sre-denoso 2>&1 && echo "KIND_DELETADO"
echo "=== FIM ==="
