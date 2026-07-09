#!/bin/bash
echo "=== Final verification ==="
echo -n "31701 (NodePort via kind IP): "
curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 http://172.18.0.2:31701/ 2>&1
echo ""
echo -n "8083 (socat localhost): "
curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 http://localhost:8083/ 2>&1
echo ""
echo -n "EXTERNO (denisdeoliveira.com.br): "
curl -s -o /dev/null -w "%{http_code}" --connect-timeout 15 https://denisdeoliveira.com.br/ 2>&1
echo ""
echo ""
echo "=== Checking nginx content via 8083 ==="
curl -s http://localhost:8083/ 2>&1 | head -10
echo ""
echo "=== Pods ==="
kubectl get pods -n default -l app=nginx 2>&1
echo ""
echo "=== Services ==="
kubectl get svc nginx-service -n default 2>&1
echo ""
echo "=== ConfigMaps ==="
kubectl get cm -n default -l 2>&1 | grep nginx
echo ""
