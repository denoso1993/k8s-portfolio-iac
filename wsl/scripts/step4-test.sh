#!/bin/bash
IP=$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' lab-sre-denoso-control-plane)
echo "IP: $IP"
echo "31701: $(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 5 http://$IP:31701/ 2>&1)"
