#!/bin/bash
# auto-recover.sh v3 - Verifica site, local E grafana. Recupera após 2 falhas.
LOG=/var/log/auto-recover.log
FAILS=0

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> $LOG; }

recover_full() {
    kubectl create namespace monitoring 2>/dev/null
    kubectl create namespace loki 2>/dev/null
    kubectl create namespace argocd 2>/dev/null
    kubectl create namespace cert-manager 2>/dev/null
    kubectl create namespace ingress-nginx 2>/dev/null
    log "=== RECOVERY INICIADO ==="
    systemctl start docker.service 2>/dev/null
    kind delete cluster --name lab-sre-denoso >> $LOG 2>&1
    rm -rf /sys/fs/cgroup/docker 2>/dev/null
    cd /home/administrator/k8s-portfolio-iac && bash wsl/scripts/ensure-cluster.sh >> $LOG 2>&1
    sleep 30
    kind get kubeconfig --name lab-sre-denoso > /root/.kube/config 2>/dev/null
    docker pull nginxinc/nginx-unprivileged:1.25-alpine >> $LOG 2>&1
    kind load docker-image nginxinc/nginx-unprivileged:1.25-alpine --name lab-sre-denoso >> $LOG 2>&1
    kubectl create cm nginx-html-config -n default --from-file=index.html=/home/administrator/k8s-portfolio-iac/wsl/cluster/services/portfolio/html/prod-index.html 2>/dev/null
    kubectl delete pod -n default -l app=nginx --force --grace-period=0 >> $LOG 2>&1
    sleep 20
    IP=$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' lab-sre-denoso-control-plane 2>/dev/null)
    pkill -f 'socat.*8083' 2>/dev/null
    nohup socat TCP-LISTEN:8083,fork,reuseaddr TCP:$IP:31701 &>/dev/null &
    pkill -f cloudflared 2>/dev/null
    nohup cloudflared tunnel --config /home/administrator/.cloudflared/config.yml run &>/dev/null &
    # GRAFANA
    kubectl apply -f /home/administrator/k8s-portfolio-iac/wsl/cluster/monitoring/ >> $LOG 2>&1
    kubectl patch svc grafana -n monitoring -p '{"spec":{"type":"NodePort"}}' 2>/dev/null
    kubectl create cm grafana -n monitoring --from-file=grafana.ini=/home/administrator/k8s-portfolio-iac/config/grafana.ini 2>/dev/null
    kubectl delete pod -n monitoring -l app.kubernetes.io/name=grafana --force --grace-period=0 >> $LOG 2>&1
    sleep 30
    NP=$(kubectl get svc grafana -n monitoring -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null)
    pkill -f 'socat.*3000' 2>/dev/null
    nohup socat TCP-LISTEN:3000,fork,reuseaddr TCP:$IP:$NP &>/dev/null &
    sleep 15
    log "=== RECOVERY CONCLUIDO ==="
    log "SITE: $(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 10 https://denisdeoliveira.com.br/ 2>/dev/null)"
    log "GRAFANA: $(curl -s -o /dev/null -w '%{http_code}' -H 'Host: grafana.denisdeoliveira.com.br' --connect-timeout 5 http://localhost:3000/ 2>/dev/null)"
}

while true; do
    site=$(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 10 https://denisdeoliveira.com.br/ 2>/dev/null)
    local=$(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 5 http://localhost:8083/ 2>/dev/null)
    grafana=$(curl -s -o /dev/null -w '%{http_code}' -H 'Host: grafana.denisdeoliveira.com.br' --connect-timeout 5 http://localhost:3000/ 2>/dev/null)
    if [ "$site" = "200" ] && [ "$local" = "200" ] && { [ "$grafana" = "200" ] || [ "$grafana" = "301" ]; }; then
        FAILS=0
    else
        FAILS=$((FAILS + 1))
        log "OFF(site=$site local=$local grafana=$grafana) falha $FAILS/2"
        if [ $FAILS -ge 2 ]; then
            log "2 falhas. Recuperando..."
            recover_full
            FAILS=0
        fi
    fi
    sleep 60
done
