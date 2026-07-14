#!/bin/bash
IP=$(docker inspect lab-sre-denoso-control-plane 2>/dev/null | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d[0]['NetworkSettings']['Networks']['kind']['IPAddress'])
" 2>/dev/null)
echo "Control Plane IP: $IP"

echo "--- Testing nodeport 31701 ---"
sleep 15
HTTP_CODE=$(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 10 http://$IP:31701/ 2>&1)
echo "31701: $HTTP_CODE"

echo "--- Setting up socat forwarding ---"
nohup socat TCP-LISTEN:8083,fork,reuseaddr TCP:$IP:31701 &>/dev/null &
echo "Socat PID: $!"
sleep 3

echo "--- Testing localhost:8083 ---"
HTTP_CODE2=$(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 10 http://localhost:8083/ 2>&1)
echo "8083: $HTTP_CODE2"

echo "--- Testing site ---"
HTTP_CODE3=$(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 15 https://denisdeoliveira.com.br/ 2>&1)
echo "SITE: $HTTP_CODE3"
