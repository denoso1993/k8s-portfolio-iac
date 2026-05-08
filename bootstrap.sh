#!/bin/bash
set -e

kind delete cluster --name lab-sre-denoso || true

kind create cluster --name lab-sre-denoso --config kind-config.yaml

terraform init

terraform apply -auto-approve

echo "======================================================="
echo "[SRE-LAB] Infraestrutura provisionada com sucesso."
echo "- Grafana:   http://localhost:3000  (admin / admin)"
echo "- Portfólio: http://localhost:8081"
echo "======================================================="
