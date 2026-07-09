#!/bin/bash
echo "=== Checking existing proxy setups ==="
echo -n "localhost:80 -> "
curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 http://localhost:80/ 2>&1
echo ""
echo -n "localhost:443 -> "
curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 https://localhost/ 2>&1
echo ""
echo -n "localhost:8082 -> "
curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 http://localhost:8082/ 2>&1
echo ""
echo "=== Current socat ==="
sudo systemctl status socat-8083.service 2>&1 | head -10
echo ""
echo "=== Docker bridge ==="
ip addr show docker0 2>&1 | head -5
echo ""
echo "=== Checking kind container IP ==="
docker inspect lab-sre-denoso-control-plane -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' 2>&1
echo ""
echo "=== Checking if we can access kind container via docker0 ==="
KIND_IP=$(docker inspect lab-sre-denoso-control-plane -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' 2>&1)
echo "Kind IP: $KIND_IP"
curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 http://$KIND_IP:31701/ 2>&1
echo ""
echo "=== Test access via cluster IP ==="
kubectl get svc nginx-service -n default 2>&1
echo "=== Test via port-forward ==="
