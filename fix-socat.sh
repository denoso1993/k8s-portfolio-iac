#!/bin/bash
IP=172.18.0.2
sudo tee /etc/systemd/system/socat-8083.service > /dev/null << EOF
[Unit]
Description=Socat forward 8083 -> nginx NodePort 31701
After=docker.service network-online.target
[Service]
Type=exec
ExecStart=/usr/bin/socat TCP-LISTEN:8083,fork,reuseaddr TCP:$IP:31701
Restart=always
RestartSec=3
User=root
[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload && sudo systemctl restart socat-8083.service
echo "DONE"
