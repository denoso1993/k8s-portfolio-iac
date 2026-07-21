# Guia de Recuperação Pós-Reinício

## Script Único (PowerShell)
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
echo '8083: \$(curl -s -o /dev/null -w \"%{http_code}\" http://localhost:8083/)';
echo 'SITE: \$(curl -s -o /dev/null -w \"%{http_code}\" https://denisdeoliveira.com.br/)'
"
```

## Grafana
Após o recovery principal, executar:
```powershell
wsl -d Ubuntu -u root -- bash -c "
kubectl apply -f /home/administrator/k8s-portfolio-iac/wsl/cluster/monitoring/;
kubectl patch svc grafana -n monitoring -p '{\"spec\":{\"type\":\"NodePort\"}}';
kubectl create cm grafana -n monitoring --from-literal=grafana.ini='[server]\nroot_url = https://denisdeoliveira.com.br/grafana/\nserve_from_sub_path = true\n[auth.anonymous]\nenabled = true\norg_role = Viewer\n[security]\nallow_embedding = true';
kubectl delete pod -n monitoring -l app.kubernetes.io/name=grafana --force --grace-period=0;
sleep 25;
NP=\$(kubectl get svc grafana -n monitoring -o jsonpath='{.spec.ports[0].nodePort}');
IP=\$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' lab-sre-denoso-control-plane);
pkill -f 'socat.*3000' 2>/dev/null;
nohup socat TCP-LISTEN:3000,fork,reuseaddr TCP:\$IP:\$NP &>/dev/null &;
sleep 3;
echo 'GRAFANA: \$(curl -s -o /dev/null -w \"%{http_code}\" -H \"Host: grafana.denisdeoliveira.com.br\" http://localhost:3000/)'
"
```

## Verificação Completa
```bash
curl http://localhost:8083/                     # nginx → 200
curl https://denisdeoliveira.com.br/            # site → 200
curl -H 'Host: grafana.denisdeoliveira.com.br' http://localhost:3000/  # grafana → 301
```

## Problemas Conhecidos

### Container Kind exit 128
```bash
rm -rf /sys/fs/cgroup/docker
systemctl restart docker
kind delete cluster --name lab-sre-denoso
bash ~/k8s-portfolio-iac/wsl/scripts/ensure-cluster.sh
```

### nginx CrashLoopBackOff
```bash
kubectl create cm nginx-html-config -n default --from-file=index.html=~/k8s-portfolio-iac/wsl/cluster/services/portfolio/html/prod-index.html
kubectl delete pod -n default -l app=nginx --force --grace-period=0
```

### Grafana off
```bash
NP=$(kubectl get svc grafana -n monitoring -o jsonpath='{.spec.ports[0].nodePort}')
IP=$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' lab-sre-denoso-control-plane)
pkill -f 'socat.*3000'; nohup socat TCP-LISTEN:3000,fork,reuseaddr TCP:$IP:$NP &>/dev/null &
```
