# Arquitetura do Portfolio

## Fluxo de Trafego

```
Navegador → HTTPS → Cloudflare Tunnel → localhost:8083 → nginx pod :8080
                                                           ├── / → index.html (portfolio Win95)
                                                           ├── /k8s/ → dev-server-service:8001 → K8s API
                                                           └── /grafana/ → grafana.monitoring:80 → Dashboard
```

## Componentes

| Componente | Funcao | Porta | Ambiente |
|-----------|--------|-------|----------|
| nginx | Servidor web (Win95 theme) | 8083 (host) / 8080 (pod) | PROD |
| mobile-server | Servidor DEV (espelhado do PROD) | 5599 (host) / 8080 (pod) | DEV |
| kubectl proxy | Proxy para K8s API (pods/nodes) | 8001 | API |
| Grafana | Dashboard de metricas | 3000 (localhost) | GRAFANA |
| Prometheus | Coleta de metricas | interna | MONITORING |
| PostgreSQL | Banco de dados | interna | DADOS |
| ArgoCD | GitOps | 8080 (port-forward) | GITOPS |
| Cloudflare Tunnel | Exposicao HTTPS publica | 443/80 | REDE |

## Ambientes

| Ambiente | Porta | URL | Pod |
|----------|-------|-----|-----|
| 🟢 PROD | 8083 | http://localhost:8083 | nginx |
| 🟡 DEV | 5599 | http://localhost:5599 | mobile-server (espelhado) |
| 📊 GRAFANA | 3000 | http://localhost:3000 | grafana |
| 🔄 ARGOCD | 8080 | port-forward | argocd-server |

## Startup Chain

A inicializacao do cluster apos reboot e totalmente automatizada.
Consulte [STARTUP-CHAIN.md](STARTUP-CHAIN.md) para detalhes.

## Tecnologias

- Kubernetes 1.27.3 (Kind)
- Docker Desktop + WSL2 (Ubuntu)
- nginx (portfolio, mobile)
- ArgoCD (GitOps)
- Prometheus + Grafana + Loki (observabilidade)
- PostgreSQL 15 (banco de dados)
- Cloudflare Tunnel (exposicao publica)
- Kyverno (policy-as-code)

## Port-Forwards Gerenciados

Gerenciados pelo `portfolio-daemon.sh` (watchdog a cada 15s):
- 8083 → nginx-service:80 (PROD)
- 5599 → mobile-server-service:5599 (DEV)
- 3000 → grafana:80 (GRAFANA - restrito a localhost)
- 8001 → kubectl proxy (API)
