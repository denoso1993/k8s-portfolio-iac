# Troubleshooting Guide

## Site off (502) / localhost:8083 off (000)

1. Verificar Docker: `docker info`
2. Verificar cluster: `kind get clusters`
3. Verificar pods: `kubectl get pods -A`
4. Verificar socat: `systemctl status socat-8083.service`
5. Verificar tunnel: `systemctl status cloudflared-tunnel.service`

Se tudo acima estiver OK mas site off, rodar recovery:
```bash
sudo /usr/local/bin/recover-kind.sh
```

## Grafana "No Data"

1. Verificar kube-state-metrics: `kubectl get pods -n monitoring -l app.kubernetes.io/name=kube-state-metrics`
2. Se CrashLoopBackOff, recriar:
```bash
kubectl delete deployment prometheus-kube-state-metrics -n monitoring
kubectl apply -f ~/k8s-portfolio-iac/wsl/cluster/monitoring/prometheus-manifests.yaml
```
3. Verificar Prometheus targets: `kubectl exec -n monitoring -c prometheus-server <pod> -- wget -q -O- http://localhost:9090/api/v1/targets`

## Container Kind com exit 128

Causa: Docker `docker.io` (Ubuntu) em vez de `docker-ce` oficial.
Verificar: `docker version | head -3` — deve mostrar "Server Version: 29.x.x"
Corrigir:
```bash
apt-get remove -y docker.io containerd runc
bash ~/k8s-portfolio-iac/wsl/scripts/bootstrap-wsl.sh
```

## /k8s/ API retorna 504

Verificar NetworkPolicies: `kubectl get networkpolicies -n default`
Se `allow-kubectl-proxy` não existir, aplicar:
```bash
kubectl apply -f ~/k8s-portfolio-iac/wsl/cluster/security/network-policies/
```

## Grafana não acessível na porta 3000

Verificar socat: `systemctl status socat-3000.service`
Verificar NodePort: `kubectl get svc grafana -n monitoring`
Atualizar socat com NodePort correto:
```bash
NP=$(kubectl get svc grafana -n monitoring -o jsonpath='{.spec.ports[0].nodePort}')
IP=$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' lab-sre-denoso-control-plane)
sed -i "s/TCP:[0-9.]*:[0-9]*/TCP:$IP:$NP/" /etc/systemd/system/socat-3000.service
systemctl daemon-reload && systemctl restart socat-3000.service
```
