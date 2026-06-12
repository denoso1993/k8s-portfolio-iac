#!/bin/bash
# backup-postgres.sh - Backup do banco PostgreSQL
set -e

BACKUP_DIR="${1:-$HOME/backups/postgres}"
mkdir -p "$BACKUP_DIR"
RETENTION_DAYS=7
PG_USER="postgres"
PG_DB="portfolio"
NAMESPACE="default"
POD="postgres-sts-0"

# Obter senha
PG_PASS=$(kubectl get secret postgres-secret -n $NAMESPACE -o jsonpath="{.data.POSTGRES_PASSWORD}" 2>/dev/null | base64 -d)
if [ -z "$PG_PASS" ]; then
    PG_PASS=$(cat ~/.pg-password 2>/dev/null)
fi

if [ -z "$PG_PASS" ]; then
    echo "ERRO: Senha PostgreSQL nao encontrada" >&2
    exit 1
fi

BACKUP_FILE="$BACKUP_DIR/portfolio-$(date +%F_%H%M%S).sql.gz"

echo "[BACKUP] Iniciando backup PostgreSQL..."
kubectl exec -n $NAMESPACE $POD -- sh -c "PGPASSWORD='$PG_PASS' pg_dump -U $PG_USER $PG_DB" 2>/dev/null | gzip > "$BACKUP_FILE"

if [ -f "$BACKUP_FILE" ] && [ -s "$BACKUP_FILE" ]; then
    echo "[BACKUP] OK: $(ls -lh "$BACKUP_FILE" | awk '{print $5}')"
    
    # Limpar backups antigos
    find "$BACKUP_DIR" -name "portfolio-*.sql.gz" -mtime +$RETENTION_DAYS -delete
    echo "[BACKUP] Limpeza: backups mais velhos que $RETENTION_DAYS dias removidos"
else
    echo "[BACKUP] ERRO: Falha ao criar backup" >&2
    exit 1
fi
