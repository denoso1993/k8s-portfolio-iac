#!/bin/bash
echo "=== STEP 6: Testar ==="
echo "31701: $(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 5 http://localhost:31701/ 2>&1)"

echo ""
echo "=== STEP 7: socat-8083 ==="
sudo tee /etc/systemd/system/socat-8083.service > /dev/null << 'EOF'
[Unit]
Description=Socat forward 8083 -> nginx NodePort 31701
After=network-online.target
[Service]
Type=exec
ExecStart=/usr/bin/socat TCP-LISTEN:8083,fork,reuseaddr TCP:127.0.0.1:31701
Restart=always
RestartSec=3
User=root
[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload && sudo systemctl enable socat-8083.service && sudo systemctl restart socat-8083.service
sleep 3
echo "8083: $(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 5 http://localhost:8083/ 2>&1)"
sleep 10
echo "EXTERNO: $(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 15 https://denisdeoliveira.com.br/ 2>&1)"
