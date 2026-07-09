#!/bin/bash
# healthcheck-site.sh - Verifica site a cada 5 min, recupera se cair
LOG=/var/log/healthcheck-site.log
echo "[$(date)] Verificando site..." >> $LOG

# Testar site externo
curl -s -o /dev/null -w '%{http_code}' --connect-timeout 15 https://denisdeoliveira.com.br/ 2>/dev/null | grep -q 200
if [ $? -ne 0 ]; then
    echo "[$(date)] SITE FORA! Recuperando..." >> $LOG
    kind get kubeconfig --name lab-sre-denoso > ~/.kube/config 2>/dev/null
    chmod 600 ~/.kube/config 2>/dev/null
    cd /home/administrator/k8s-portfolio-iac && bash wsl/scripts/ensure-everything.sh >> $LOG 2>&1
    sleep 30
    IP=$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' lab-sre-denoso-control-plane 2>/dev/null)
    sed -i "s/TCP:[0-9.]*:31701/TCP:$IP:31701/" /etc/systemd/system/socat-8083.service 2>/dev/null
    systemctl daemon-reload 2>/dev/null && systemctl restart socat-8083.service 2>/dev/null
    echo "[$(date)] Recovery concluido" >> $LOG
else
    echo "[$(date)] Site OK" >> $LOG
fi
