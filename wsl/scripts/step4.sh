#!/bin/bash
IP=$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' lab-sre-denoso-control-plane)
echo "IP: $IP"
sudo sed -i "s/TCP:[0-9.]*:[0-9]*/TCP:$IP:31701/" /etc/systemd/system/socat-8083.service 2>/dev/null
sudo systemctl daemon-reload && sudo systemctl restart socat-8083.service
sleep 3
echo "8083: $(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 5 http://localhost:8083/ 2>&1)"
