#!/bin/bash
# backup-manifests.sh - Backup de todos os recursos do Kubernetes
# Uso: bash backup-manifests.sh [diretorio_destino]

BACKUP_DIR="${1:-$HOME/backups/manifests/$(date +%F_%H%M%S)}"
mkdir -p "$BACKUP_DIR"

echo "[BACKUP] Exportando todos os recursos do cluster..."
echo "Destino: $BACKUP_DIR"

RESOURCES=(
    "pods" "services" "deployments" "statefulsets" "daemonsets"
    "configmaps" "secrets" "persistentvolumeclaims" "persistentvolumes"
    "networkpolicies" "limitranges" "resourcequotas"
    "serviceaccounts" "roles" "rolebindings" "clusterroles" "clusterrolebindings"
    "ingresses" "horizontalpodautoscalers"
)

for resource in "${RESOURCES[@]}"; do
    echo "  Exportando $resource..."
    kubectl get "$resource" -A -o yaml > "$BACKUP_DIR/$resource.yaml" 2>/dev/null
done

# Exportar Custom Resources (Prometheus, Grafana, ArgoCD)
for crd in $(kubectl get crd -o name 2>/dev/null | cut -d/ -f2); do
    echo "  Exportando CRD: $crd..."
    kubectl get "$crd" -A -o yaml > "$BACKUP_DIR/crd-$crd.yaml" 2>/dev/null
done

# Salvar lista de pods com detalhes
kubectl get pods -A -o wide > "$BACKUP_DIR/pods-list.txt" 2>/dev/null

echo "[BACKUP] Compactando..."
cd "$(dirname "$BACKUP_DIR")"
tar -czf "manifests-$(date +%F_%H%M%S).tar.gz" "$(basename "$BACKUP_DIR")" 2>/dev/null
rm -rf "$BACKUP_DIR"
echo "[BACKUP] Completo: $(ls -lh *.tar.gz | tail -1)"
