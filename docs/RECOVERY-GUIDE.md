# Guia de Recuperação — Todos os Cenários

## 📌 Cenários de Queda e Recuperação

| # | Cenário | Sintoma | Causa | Recuperação |
|---|---------|---------|-------|-------------|
| 1 | 502 constante (loop) | Site cai e volta a cada ~30s | autoheal.sh destrutivo | Parar autoheal (seção 1) |
| 2 | Container Kind exit 128 | Container morre, site 502 | Bug cgroup v2 WSL2 | Limpar cgroups + recriar (seção 2) |
| 3 | nginx CrashLoopBackOff | Pods nginx 0/1 | ConfigMap vazio ou imagem ausente | Criar CM + carregar imagem (seção 3) |
| 4 | kubeconfig zerado | kubectl connection refused | kind get kubeconfig falhou | Regenerar kubeconfig (seção 4) |
| 5 | recover-kind 203/EXEC | Boot recovery não roda | CRLF no shebang | dos2unix (seção 5) |
| 6 | Grafana 502/000 | Grafana inacessível porta 3000 | Pod não existe ou socat errado | Subir Grafana (seção 6) |
| 7 | DNS quebrado | ImagePullBackOff | 8.8.8.8 inalcançável | DNS fixo 10.255.255.254 (seção 7) |
| 8 | Socat IP errado | Site 502 mas container running | IP do Kind mudou | Atualizar IP socat (seção 8) |

---

## 1. 502 CONSTANTE (LOOP) — CRÍTICO
```bash
systemctl stop autoheal.service
systemctl disable autoheal.service
pkill -f autoheal.sh
```
**NUNCA religar autoheal com kind delete cluster.**

## 2. CONTAINER KIND EXIT 128
```bash
systemctl start docker.service
kind delete cluster --name lab-sre-denoso
rm -rf /sys/fs/cgroup/docke
cd ~/k8s-portfolio-iac && bash wsl/scripts/ensure-cluster.sh
```

## 3. NGINX CRASHLOOPBACKOFF
```bash
docker pull nginxinc/nginx-unprivileged:1.25-alpine
kind load docker-image nginxinc/nginx-unprivileged:1.25-alpine --name lab-sre-denoso
kubectl create cm nginx-html-config -n default --from-file=index.html=~/k8s-portfolio-iac/wsl/cluster/services/portfolio/html/prod-index.html
kubectl delete pod -n default -l app=nginx --force --grace-period=0
```

## 4. KUBECONFIG ZERADO
```bash
kind get kubeconfig --name lab-sre-denoso > /root/.kube/config
chmod 600 /root/.kube/config
```

## 5. RECOVER-KIND 203/EXEC (CRLF)
```bash
dos2unix /usr/local/bin/recover-kind.sh
systemctl daemon-reload
```

## 6. GRAFANA OFF
```bash
kubectl apply -f ~/k8s-portfolio-iac/wsl/cluster/monitoring/
kubectl patch svc grafana -n monitoring -p '{"spec":{"type":"NodePort"}}'
kubectl create cm grafana -n monitoring --from-file=grafana.ini=~/k8s-portfolio-iac/config/grafana.ini
kubectl delete pod -n monitoring -l app.kubernetes.io/name=grafana --force --grace-period=0
sleep 30
NP=$(kubectl get svc grafana -n monitoring -o jsonpath='{.spec.ports[0].nodePort}')
IP=$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' lab-sre-denoso-control-plane)
pkill -f 'socat.*3000'
nohup socat TCP-LISTEN:3000,fork,reuseaddr TCP:$IP:$NP &>/dev/null &
```

## 7. DNS QUEBRADO
```bash
chattr -i /etc/resolv.conf 2>/dev/null
echo "nameserver 10.255.255.254" > /etc/resolv.conf
chattr +i /etc/resolv.conf
cat > /etc/docker/daemon.json << 'EOF'
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "cgroup-parent": "/docker.slice",
  "dns": ["10.255.255.254", "8.8.8.8"]
}
EOF
systemctl restart docker.service
```

## 8. SOCAT IP ERRADO
```bash
IP=$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' lab-sre-denoso-control-plane)
NP=$(kubectl get svc nginx-service -n default -o jsonpath='{.spec.ports[0].nodePort}')
pkill -f 'socat.*8083'
nohup socat TCP-LISTEN:8083,fork,reuseaddr TCP:$IP:$NP &>/dev/null &
```

## ✅ VERIFICAÇÃO COMPLETA
```bash
curl http://localhost:8083/                     # nginx → 200
curl https://denisdeoliveira.com.br/            # site → 200
curl -H 'Host: grafana.denisdeoliveira.com.br' http://localhost:3000/  # grafana → 301
```

## ⚠️ REGRA DE OURO
- NUNCA usar autoheal que apaga cluster em loop
- SEMPRE versionar scripts de recuperação no git
- SEMPRE documentar novos cenários neste guia
