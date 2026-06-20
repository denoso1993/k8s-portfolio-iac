# Diretório k8s/ — REDIRECIONADO

Este diretório foi **substituído** por `wsl/cluster/`.

**Fonte única da verdade:** `wsl/cluster/`

Todos os manifests agora estão em `wsl/cluster/`:
- `wsl/cluster/services/` — Deployments, Services, ConfigMaps
- `wsl/cluster/monitoring/` — Grafana, Prometheus
- `wsl/cluster/infrastructure/` — ingress-nginx, metrics-server
- `wsl/cluster/security/` — NetworkPolicies, quotas
- `wsl/cluster/platform/` — Kyverno policies

**Motivo:** Eliminar duplicação de manifests entre `k8s/` e `wsl/cluster/`.
