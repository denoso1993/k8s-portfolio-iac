# 🚀 Setup Rápido - Dashboards Grafana

## Opção 1: PowerShell (Recomendado)

```powershell
# Windows PowerShell
C:\wsl_bridge\setup-grafana-dashboards.ps1
```

## Opção 2: Manual via UI

1. **Acesse Grafana**: http://localhost:30001
2. **Login**: admin / admin
3. **Dashboards** → **Import**
4. **Import via grafana.com**:
   - ID: `6417` → Kubernetes Cluster
   - ID: `13332` → Kubernetes Monitoring
5. **Select datasource**: Prometheus
6. **Import**

## Opção 3: Via kubectl (Automático)

```bash
# WSL
kubectl port-forward svc/grafana -n monitoring 30001:80 &
sleep 2

# Import dashboard 6417
curl -sL https://grafana.com/api/dashboards/6417/revisions/latest/download | \
  python3 -c "
import sys, json
d = json.load(sys.stdin)
print(json.dumps({'dashboard': d, 'overwrite': True, 'inputs': [{'name': 'DS_PROMETHEUS', 'type': 'datasource', 'pluginId': 'prometheus', 'value': 'prometheus'}]}))
" | curl -X POST http://localhost:30001/api/dashboards/db \
  -H "Content-Type: application/json" \
  -u admin:admin \
  -d @-
```

## Dashboards Incluídos

| ID | Nome | Descrição |
|----|------|---------|
| 6417 | Kubernetes Cluster | Visão geral do cluster |
| 13332 | Kubernetes Monitoring | Métricas detalhadas de pods/nodes |

## Após Setup

- **Home do Grafana** agora mostra os dashboards importados
- **Auto-refresh**: 10s (configurável)
- **Alertas**: Configure em Alerting → Contact Points
