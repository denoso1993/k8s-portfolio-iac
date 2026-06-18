#!/bin/bash
set -e
echo "=== Instalando socat ==="
apt-get update -qq && apt-get install -y -qq socat
echo "=== Desabilitando PFs antigos ==="
for svc in pf-watchdog pf-nginx pf-dev-server pf-mobile pf-mobile-dev pf-grafana grafana-pf k8s-pf k8s-startup; do
    systemctl stop ${svc}.service 2>/dev/null || true
    systemctl disable ${svc}.service 2>/dev/null || true
done
pkill -f "kubectl.*port-forward" 2>/dev/null || true
sleep 2
echo "=== Criando socat forwarders ==="
FORWARDERS=("8083:172.18.0.2:31701" "5500:172.18.0.2:32286" "5599:172.18.0.2:31807" "5598:172.18.0.2:31804" "3000:172.18.0.2:32039")
for fwd in "${FORWARDERS[@]}"; do
    IFS=":" read -r src dst_ip dst_port <<< "$fwd"
    name="socat-${src}"
    cat > /etc/systemd/system/${name}.service << SRVEOF
[Unit]
Description=${name} -> ${dst_ip}:${dst_port}
After=network-online.target
[Service]
Type=exec
ExecStart=/usr/bin/socat TCP-LISTEN:${src},fork,reuseaddr TCP:${dst_ip}:${dst_port}
Restart=always
RestartSec=3
User=administrator
[Install]
WantedBy=multi-user.target
SRVEOF
    systemctl enable ${name}.service
    systemctl restart ${name}.service
    echo "  ${name}: ${src} -> ${dst_ip}:${dst_port} OK"
done
echo ""
systemctl list-units --type=service --all | grep socat-
echo "? bootstrap-wsl.sh COMPLETO"
echo "=== Instalando auto-recovery systemd ==="
cp /home/administrator/k8s-portfolio-iac/wsl/services/cluster.target /etc/systemd/system/
cp /home/administrator/k8s-portfolio-iac/wsl/services/ensure-cluster.service /etc/systemd/system/
cp /home/administrator/k8s-portfolio-iac/wsl/services/cluster-ready.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable cluster.target ensure-cluster.service cluster-ready.service
echo "  Auto-recovery services installed"
echo "Para iniciar manualmente: systemctl start cluster.target"
