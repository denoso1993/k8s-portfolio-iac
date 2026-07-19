# Guia de Recuperação Pós-Reinício

## Comando Único (PowerShell)
Abra o PowerShell como administrador e execute:
```powershell
wsl -d Ubuntu -u root -- bash -c "
systemctl start docker.service;
kind delete cluster --name lab-sre-denoso;
rm -rf /sys/fs/cgroup/docker;
cd /home/administrator/k8s-portfolio-iac && bash wsl/scripts/ensure-cluster.sh;
sleep 30;
docker pull nginxinc/nginx-unprivileged:1.25-alpine;
kind load docker-image nginxinc/nginx-unprivileged:1.25-alpine --name lab-sre-denoso;
kubectl create cm nginx-html-config -n default --from-file=index.html=wsl/cluster/services/portfolio/html/prod-index.html;
kubectl delete pod -n default -l app=nginx --force --grace-period=0;
sleep 25;
IP=\$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' lab-sre-denoso-control-plane);
nohup socat TCP-LISTEN:8083,fork,reuseaddr TCP:\$IP:31701 &>/dev/null &;
echo '8083 OK: \$(curl -s -o /dev/null -w \"%{http_code}\" http://localhost:8083/)';
echo 'SITE OK: \$(curl -s -o /dev/null -w \"%{http_code}\" https://denisdeoliveira.com.br/)'
"
```

## Verificação Pós-Recovery
```bash
curl http://localhost:8083/                     # Deve retornar 200
curl https://denisdeoliveira.com.br/            # Deve retornar 200
curl http://localhost:3000/                     # Deve retornar 301 (Grafana)
```

## Problemas Conhecidos

### Container Kind morre com exit 128
**Causa:** Bug de cgroup v2 no kernel WSL2.  
**Solução:** 
```bash
rm -rf /sys/fs/cgroup/docker
systemctl restart docker
kind delete cluster --name lab-sre-denoso
bash ~/k8s-portfolio-iac/wsl/scripts/ensure-cluster.sh
```

### nginx CrashLoopBackOff
**Causa:** ConfigMap de HTML não foi criado ou imagem não carregada.  
**Solução:**
```bash
kubectl create cm nginx-html-config -n default \
  --from-file=index.html=~/k8s-portfolio-iac/wsl/cluster/services/portfolio/html/prod-index.html
kubectl delete pod -n default -l app=nginx --force --grace-period=0
```

### Grafana não acessível
**Causa:** socat-3000 não está rodando ou NodePoint mudou.  
**Solução:**
```bash
NP=$(kubectl get svc grafana -n monitoring -o jsonpath='{.spec.ports[0].nodePort}')
IP=$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' lab-sre-denoso-control-plane)
pkill -f 'socat.*3000'; nohup socat TCP-LISTEN:3000,fork,reuseaddr TCP:$IP:$NP &>/dev/null &
```
