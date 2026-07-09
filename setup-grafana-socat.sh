#!/bin/bash
NP=$(kubectl get svc grafana -n monitoring -o jsonpath={.spec.ports[0].nodePort} 2>/dev/null)
echo "GRAFANA_PORT: $NP"
curl -s -o /dev/null -w "GRAFANA: %{http_code}\n" --connect-timeout 5 "http://localhost:$NP/"

cat > /etc/systemd/system/socat-3000.service << EOF
[Unit]
Description=Socat forward 3000 -> Grafana NodePort ${NP}
After=network-online.target
[Service]
Type=exec
ExecStart=/usr/bin/socat TCP-LISTEN:3000,fork,reuseaddr TCP:127.0.0.1:${NP}
Restart=always
RestartSec=3
User=root
[Install]
WantedBy=cluster.target
EOF

systemctl daemon-reload
systemctl restart socat-3000.service
sleep 3
echo "3000: $(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 5 http://localhost:3000/ 2>&1)"
