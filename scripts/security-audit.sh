#!/bin/bash
# security-audit.sh - Auditoria de segurança do cluster
# Uso: bash security-audit.sh [--verbose]

VERBOSE=${1:+true}
ISSUES=0

echo "===== AUDITORIA DE SEGURANCA ====="
echo "Data: $(date)"
echo ""

# 1. Verificar pods rodando como root
echo "[CHECK] Pods rodando como root..."
ROOT_PODS=$(kubectl get pods -A -o jsonpath='{range .items[*]}{.metadata.namespace}{" "}{.metadata.name}{" "}{.spec.containers[*].securityContext.runAsNonRoot}{"\n"}{end}' 2>/dev/null | grep -v "true" | grep -v "^\s*$")
if [ -n "$ROOT_PODS" ]; then
    echo "  WARNING: Pods sem runAsNonRoot:"
    echo "$ROOT_PODS" | while read ns pod val; do echo "    $ns/$pod"; done
    ISSUES=$((ISSUES+1))
else
    echo "  OK - Todos os pods tem runAsNonRoot configurado"
fi

# 2. Verificar secrets expostos
echo ""
echo "[CHECK] Secrets sem criptografia..."
for ns in $(kubectl get ns -o name | cut -d/ -f2); do
    for secret in $(kubectl get secrets -n $ns -o name 2>/dev/null | cut -d/ -f2); do
        TYPE=$(kubectl get secret -n $ns $secret -o jsonpath='{.type}' 2>/dev/null)
        if [ "$TYPE" = "Opaque" ]; then
            DATA=$(kubectl get secret -n $ns $secret -o jsonpath='{.data}' 2>/dev/null | wc -c)
            if [ "$DATA" -gt 100 ]; then
                [ "$VERBOSE" = true ] && echo "  $ns/$secret ($DATA bytes)"
            fi
        fi
    done
done
echo "  Info: Secrets Opaque listados (use --verbose para detalhes)"

# 3. Verificar NetworkPolicies
echo ""
echo "[CHECK] Namespaces sem NetworkPolicy..."
for ns in $(kubectl get ns -o name | cut -d/ -f2); do
    NP_COUNT=$(kubectl get networkpolicies -n $ns --no-headers 2>/dev/null | wc -l)
    if [ "$NP_COUNT" -eq 0 ]; then
        echo "  WARNING: $ns sem NetworkPolicy"
        ISSUES=$((ISSUES+1))
    fi
done

# 4. Verificar port-forwards expostos
echo ""
echo "[CHECK] Port-forwards em 0.0.0.0 (expostos na rede)..."
PF_EXPOSTOS=$(ps aux | grep "kubectl port-forward.*0.0.0.0" | grep -v grep)
if [ -n "$PF_EXPOSTOS" ]; then
    echo "  Port-forwards expostos:"
    echo "$PF_EXPOSTOS" | while read line; do
        PORT=$(echo "$line" | grep -oP "\d+:\d+" | head -1)
        echo "    $PORT"
    done
fi

# 5. Verificar RBAC excessivo
echo ""
echo "[CHECK] ClusterRoles com permissoes amplas..."
kubectl get clusterroles -o json 2>/dev/null | python3 -c "
import sys, json
d = json.load(sys.stdin)
for item in d.get('items', []):
    name = item.get('metadata', {}).get('name', '')
    rules = item.get('rules', [])
    for rule in rules:
        if '*' in rule.get('resources', []) and '*' in rule.get('verbs', []):
            print(f'  WARNING: ClusterRole \"{name}\" tem permissoes totais')
            break
" 2>/dev/null

echo ""
echo "===== AUDITORIA COMPLETA ====="
echo "Issues encontrados: $ISSUES"
