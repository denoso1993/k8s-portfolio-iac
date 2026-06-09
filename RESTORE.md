# Restore Portfolio

## Restauracao completa do portfolio

### Aplicar nginx + HTML
kubectl apply -f k8s/services/portfolio/
kubectl rollout restart deployment nginx-deployment -n default

### Restaurar dashboard Grafana
curl -X POST -u admin:admin http://localhost:3000/api/dashboards/db -H "Content-Type: application/json" -d @k8s/monitoring/cluster-sre-dashboard.json

### Arquivos principais
- configmap-nginx.yaml: HTML do portfolio
- configmap-nginx-full.yaml: Config nginx com proxy /k8s/
- cluster-sre-dashboard.json: Dashboard Grafana
