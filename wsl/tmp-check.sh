#!/bin/bash
echo "=== Test port 30081 (mapped) ==="
curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 http://localhost:30081/ 2>&1
echo ""
echo "=== Check nginx html content via pod ==="
POD=$(kubectl get pods -n default -l app=nginx -o jsonpath="{.items[0].metadata.name}" 2>&1)
kubectl exec -n default $POD -- cat /usr/share/nginx/html/index.html 2>&1 | head -5
echo ""
echo "=== Check nginx config inside pod ==="
kubectl exec -n default $POD -- cat /etc/nginx/nginx.conf 2>&1 | head -20
echo ""
echo "=== Check NodePort via docker IP ==="
docker inspect lab-sre-denoso-control-plane -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' 2>&1
echo ""
curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 http://172.17.0.2:31701/ 2>&1
echo ""
echo "=== Check via kind internal ==="
NODE_IP=$(kubectl get nodes -o jsonpath="{.items[0].status.addresses[0].address}" 2>&1)
echo "Node IP: $NODE_IP"
curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 http://$NODE_IP:31701/ 2>&1
echo ""
