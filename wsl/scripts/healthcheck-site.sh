#!/bin/bash
LOG=/var/log/healthcheck-site.log
echo "[$(date)] Verificando site..." >> $LOG

# Testar LOCAL (8083) — não externo (Cloudflare cache)
curl -s -o /dev/null -w '%{http_code}' --connect-timeout 5 http://localhost:8083/ 2>/dev/null | grep -q 200
if [ $? -ne 0 ]; then
    echo "[$(date)] SITE FORA (8083)! Recuperando..." >> $LOG
    cd /home/administrator/k8s-portfolio-iac && bash wsl/scripts/ensure-everything.sh >> $LOG 2>&1
    sleep 30
    IP=$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' lab-sre-denoso-control-plane 2>/dev/null)
    if [ -n "$IP" ]; then
        sed -i "s/TCP:[0-9.]*:31701/TCP:$IP:31701/" /etc/systemd/system/socat-8083.service 2>/dev/null
        systemctl daemon-reload 2>/dev/null && systemctl restart socat-8083.service 2>/dev/null
    fi
    echo "[$(date)] Recovery concluido" >> $LOG
else
    echo "[$(date)] Site OK (8083 respondeu 200)" >> $LOG
fi
