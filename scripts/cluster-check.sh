#!/bin/bash
# Cluster Health Check - K8s Portfolio IAC
# Run this at the start of each session

set -e

echo "=== K8s Portfolio IAC - Health Check ==="
echo "Date: $(date)"
echo ""

# Check Docker
echo "1. Docker Status"
docker ps -a --filter "name=lab-sre" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""

# Check cluster
echo "2. Cluster Status"
kubectl get nodes
echo ""

# Check pods
echo "3. Pods Status"
TOTAL=$(kubectl get pods --all-namespaces | grep -v NAME | wc -l)
RUNNING=$(kubectl get pods --all-namespaces | grep Running | wc -l)
echo "Total: $TOTAL | Running: $RUNNING | Health: $(( RUNNING * 100 / TOTAL ))%"
echo ""

# Check ArgoCD
echo "4. ArgoCD Status"
kubectl get application -n argocd 2>/dev/null || echo "ArgoCD not installed"
echo ""

# Check Git
echo "5. Git Status"
cd /home/denoso/k8s-portfolio-iac
git log --oneline -3
git status --short
echo ""

# Check pending work
echo "6. Pending Work"
echo "- Check ROADMAP-2026.md for current tasks"
echo "- Verify README.md reflects cluster state"
echo "- Review MEMORY-WINDOWS.md for context"
echo ""

echo "=== Health Check Complete ==="
