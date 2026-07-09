#!/bin/bash
# import-grafana-dashboard.sh - Importa o dashboard Cluster SRE no Grafana
set -e

DASHBOARD_FILE="$HOME/k8s-portfolio-iac/wsl/cluster/monitoring/cluster-sre-dashboard.json"
GRAFANA_URL="${GRAFANA_URL:-http://localhost:3000}"
GRAFANA_USER="${GRAFANA_USER:-admin}"
GRAFANA_PASS="${GRAFANA_PASS:-admin}"

if [ ! -f "$DASHBOARD_FILE" ]; then
    echo "ERRO: Dashboard JSON nao encontrado em $DASHBOARD_FILE"
    exit 1
fi

echo "[IMPORT] Importando dashboard Cluster SRE..."

python3 -c "
import json, urllib.request, base64

with open('$DASHBOARD_FILE') as f:
    dash = json.load(f)

# Garantir datasource UID correto
for p in dash.get('panels', []):
    for t in p.get('targets', []):
        t.setdefault('datasource', {})
        t['datasource']['type'] = 'prometheus'
        t['datasource']['uid'] = 'PBFA97CFB590B2093'

auth = base64.b64encode(b'${GRAFANA_USER}:${GRAFANA_PASS}').decode()
payload = json.dumps({'dashboard': dash, 'overwrite': True}).encode()
req = urllib.request.Request('${GRAFANA_URL}/api/dashboards/db',
    data=payload,
    headers={'Content-Type': 'application/json', 'Authorization': f'Basic {auth}'})
resp = json.loads(urllib.request.urlopen(req).read())
print(f'Status: {resp.get(\"status\")}, Version: {resp.get(\"version\")}')
"

echo "[IMPORT] Dashboard importado com sucesso!"
