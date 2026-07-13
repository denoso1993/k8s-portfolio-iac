# Setup do Zero — k8s-portfolio-iac

## Pré-requisitos
- Windows 10/11 com WSL2
- Git

## Passo a passo

### 1. Instalar WSL2
```powershell
wsl --install -d Ubuntu
```

### 2. Clonar o repositório
```powershell
git clone https://github.com/denoso1993/k8s-portfolio-iac.git
cd k8s-portfolio-iac
```

### 3. Executar bootstrap (instala Docker OFICIAL + Kind + kubectl + cloudflared)
```bash
# Dentro do WSL
bash wsl/scripts/bootstrap-wsl.sh
```

### 4. Criar cluster
```bash
cd ~/k8s-portfolio-iac
bash wsl/scripts/ensure-cluster.sh
```

### 5. Verificar
```bash
kubectl get pods -A
curl http://localhost:8083/
```

## Troubleshooting

### Container Kind morre com exit 128 (cgroup)
Causa: Docker `docker.io` (Ubuntu) foi instalado em vez do `docker-ce` oficial.
Solução: Remover docker.io e instalar docker-ce manualmente:
```bash
apt-get remove -y docker.io containerd runc
bash wsl/scripts/bootstrap-wsl.sh  # instala docker-ce oficial
```

### nginx CrashLoopBackOff
Causa: ConfigMap `nginx-html-config` vazio (só metadata, sem HTML).
Solução:
```bash
kubectl create cm nginx-html-config -n default \
  --from-file=index.html=~/k8s-portfolio-iac/wsl/cluster/services/portfolio/html/prod-index.html
kubectl delete pod -n default -l app=nginx --force --grace-period=0
```

### /k8s/ API retorna 504
Causa: NetworkPolicy `default-deny-ingress` bloqueia nginx → kubectl-proxy.
Solução: Aplicar `allow-kubectl-proxy.yaml`:
```bash
kubectl apply -f ~/k8s-portfolio-iac/wsl/cluster/security/network-policies/
```

### Grafana "No Data"
Causa: kube-state-metrics em CrashLoopBackOff ou Prometheus sem acesso ao API Server.
Solução: Verificar network policies e recriar kube-state-metrics:
```bash
kubectl delete deployment prometheus-kube-state-metrics -n monitoring
kubectl apply -f ~/k8s-portfolio-iac/wsl/cluster/monitoring/prometheus-manifests.yaml
```
