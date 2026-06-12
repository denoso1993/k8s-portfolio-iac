#!/bin/bash
# ensure-cluster.sh - Garante que o cluster está rodando com todos os recursos
set -e

CLUSTER="lab-sre-denoso"
REPO_DIR="$HOME/k8s-portfolio-iac"
K8S_BASE="$REPO_DIR/k8s"

# Verificar se o cluster existe
if ! kind get clusters 2>/dev/null | grep -q "$CLUSTER"; then
    echo "[CREATE] Criando cluster Kind..."
    kind create cluster --name "$CLUSTER" --config "$REPO_DIR/kind-config.yaml"
    echo "[CREATE] Aguardando API..."; sleep 15
else
    echo "[CHECK] Cluster $CLUSTER existe"
fi

# Aplicar recursos em ordem
echo "[APPLY] Infrastructure..."
kubectl apply -f $K8S_BASE/infrastructure/

echo "[APPLY] Security (network policies, quotas, limits)..."
kubectl apply -f $K8S_BASE/security/
kubectl apply -f $K8S_BASE/security/network-policies/

echo "[APPLY] Services..."
kubectl apply -f $K8S_BASE/services/portfolio/
kubectl apply -f $K8S_BASE/services/postgres/

echo "[APPLY] Platform (Kyverno)..."
kubectl apply -f $K8S_BASE/platform/

echo "[CHECK] Aguardando pods..."
kubectl wait --for=condition=ready pod -l app=nginx -n default --timeout=60s 2>/dev/null || true

echo "[INSTALL] Monitoring stack if needed..."
if ! kubectl get ns monitoring >/dev/null 2>&1; then
    echo "Instalando Prometheus + Grafana..."
    kubectl create ns monitoring --dry-run=client -o yaml | kubectl apply -f -
    kubectl apply -f $K8S_BASE/monitoring/prometheus-manifests.yaml
    kubectl apply -f $K8S_BASE/monitoring/grafana-manifests.yaml
    kubectl apply -f $K8S_BASE/monitoring/loki-manifests.yaml 2>/dev/null || true
    echo "Aguardando monitoring..."
    sleep 20
fi

echo "[ADD] Grafana dashboard..."
python3 /tmp/grafana-fix.py 2>/dev/null || python3 -c "
import json, urllib.request, base64
with open('$K8S_BASE/monitoring/cluster-sre-dashboard.json') as f:
    dash = json.load(f)
dash['schemaVersion'] = 39
for p in dash.get('panels', []):
    for t in p.get('targets', []):
        t['datasource'] = {'type': 'prometheus', 'uid': 'PBFA97CFB590B2093'}
req = urllib.request.Request('http://localhost:3000/api/dashboards/db',
    data=json.dumps({'dashboard': dash, 'overwrite': True}).encode(),
    headers={'Content-Type': 'application/json', 'Authorization': 'Basic ' + base64.b64encode(b'admin:admin').decode()})
print('Dashboard:', json.loads(urllib.request.urlopen(req).read()).get('status'))
" 2>/dev/null || echo "Grafana dashboard import skipped (Grafana may not be ready)"

echo "[DONE] Cluster pronto!"
kubectl get pods -A 2>/dev/null | awk '{print $1, $2, $3}'