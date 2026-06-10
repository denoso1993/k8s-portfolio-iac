#!/bin/bash
# generate-postgres-secret.sh - Gera senha aleatoria para o PostgreSQL
# Executar no bootstrap do cluster
# A senha fica no Windows Credential Manager e no arquivo local (fora do git)

if kubectl get secret postgres-secret -n default >/dev/null 2>&1; then
    echo "Secret already exists"
    exit 0
fi

# Generate random password
PASS=$(openssl rand -base64 16 | tr -d "=+/" | head -c 16)

# Create secret
kubectl create secret generic postgres-secret -n default \
    --from-literal=POSTGRES_USER=postgres \
    --from-literal=POSTGRES_PASSWORD=$PASS \
    --from-literal=POSTGRES_DB=portfolio

echo "PostgreSQL secret created with random password"
echo "Password saved to /home/administrator/.pg-password"
echo "$PASS" > /home/administrator/.pg-password
chmod 600 /home/administrator/.pg-password
