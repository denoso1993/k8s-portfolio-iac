#!/bin/bash
set -e

echo "========================================"
echo "[SRE-LAB] Starting cluster recreation..."
echo "========================================"

# Delete existing cluster
kind delete cluster --name lab-sre-denoso || true

# Create new cluster with proper config
echo "[1/4] Creating Kind cluster..."
kind create cluster --name lab-sre-denoso --config kind-config.yaml

# Initialize Terraform
echo "[2/4] Initializing Terraform..."
terraform init

# Apply infrastructure
echo "[3/4] Applying Terraform infrastructure..."
terraform apply -auto-approve

# Wait for metrics-server to be ready
echo "[4/4] Waiting for metrics-server to be ready..."
sleep 30

# Verify metrics
echo "========================================"
echo "[SRE-LAB] Verifying metrics..."
kubectl top nodes || echo "Note: Metrics may take 1-2 minutes to be available"

echo "========================================"
echo "[SRE-LAB] Infraestrutura provisionada com sucesso."
echo ""
echo "Endpoints:"
echo "  - Portfólio: http://localhost:8081"
echo "  - Grafana:   http://localhost:3000 (admin/admin)"
echo "  - Prometheus: http://localhost:3000/#/status?g0.prometheus=Prometheus"
echo ""
echo "HPA Status:"
kubectl get hpa nginx-hpa || echo "HPA not yet available"
echo "========================================"
