#!/bin/bash
KIND_IP="172.18.0.2"
echo "=== Fixing socat to point to kind container IP: $KIND_IP ==="

sudo tee /etc/systemd/system/socat-8083.service > /dev/null << EOF
[Unit]
Description=Socat forward 8083 -> nginx NodePort 31701 (via kind $KIND_IP)
After=network-online.target
[Service]
Type=exec
ExecStart=/usr/bin/socat TCP-LISTEN:8083,fork,reuseaddr TCP:$KIND_IP:31701
Restart=always
RestartSec=3
User=root
[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload && sudo systemctl restart socat-8083.service
sleep 3
echo -n "8083: "
curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 http://localhost:8083/ 2>&1
echo ""
