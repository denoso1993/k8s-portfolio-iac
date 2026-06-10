#!/bin/bash
# backup-postgres.sh - Backup do PostgreSQL
# Salva em /home/administrator/k8s-portfolio-iac/backups/

BACKUP_DIR=/home/administrator/k8s-portfolio-iac/backups
mkdir -p $BACKUP_DIR

DATE=$(date "+%Y-%m-%d_%H-%M")
FILE=$BACKUP_DIR/portfolio-$DATE.sql

echo "[$(date)] Backing up PostgreSQL..."
kubectl exec -n default postgres-sts-0 -- pg_dump -U postgres portfolio > $FILE 2>/dev/null || kubectl exec -n default postgres-sts-0 -- pg_dumpall -U postgres > $FILE 2>/dev/null

SIZE=$(wc -c < $FILE)
echo "[$(date)] Backup saved: $FILE ($SIZE bytes)"

# Keep only last 7 backups
ls -t $BACKUP_DIR/portfolio-*.sql 2>/dev/null | tail -n +8 | xargs -r rm
echo "[$(date)] Cleaned old backups"
