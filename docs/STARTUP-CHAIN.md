# Startup Chain — Cadeia de Inicializacao

## Visão Geral
Sequencia automatica que garante que o cluster e servicos subam apos reboot.

## Fluxo Completo

```
Windows Boot
  └── Login (interativo ou automatico)
       └── Scheduled Tasks (ONLOGON)
            ├── Portfolio-Cluster-Start (30s delay)
            │    ├── Aguarda Docker Desktop (ate 2min)
            │    ├── Inicia WSL (se necessario)
            │    ├── ensure-cluster.sh (cria/verifica Kind cluster)
            │    │    ├── kind create cluster (se necessario)
            │    │    ├── kubectl apply -f k8s/infrastructure/
            │    │    ├── kubectl apply -f k8s/security/
            │    │    ├── kubectl apply -f k8s/services/
            │    │    ├── kubectl apply -f k8s/platform/
            │    │    ├── kubectl apply -f k8s/monitoring/
            │    │    └── python3 import-grafana-dashboard.sh
            │    └── portfolio-daemon.sh (port-forwards)
            │         ├── kubectl port-forward nginx:8083
            │         ├── kubectl port-forward grafana:3000
            │         ├── kubectl port-forward dev-server:5500
            │         ├── kubectl port-forward mobile:5599
            │         └── watchog (verifica a cada 15s)
            ├── Portfolio-Netsh-Proxy (1min delay)
            │    └── netsh-recreate.ps1 (recria regras portproxy)
            └── Portfolio-HealthCheck (2min delay, repete 5/5min)
                 ├── Verifica HTTP 200 em localhost:8083
                 ├── Verifica HTTP 200 em localhost:3000/api/health
                 ├── Verifica WSL vivo
                 └── Aciona recovery se necessario
```

## Scripts Envolvidos

| Script | Localizacao | Funcao |
|--------|-------------|--------|
| `start-cluster.ps1` | bootstrap/ | Inicia Docker → WSL → Kind → Daemon |
| `netsh-recreate.ps1` | bootstrap/ | Detecta IP do WSL e recria netsh |
| `healthcheck.ps1` | bootstrap/ | Monitora saude a cada 5min |
| `install-tasks.ps1` | bootstrap/ | Instala Scheduled Tasks (executar como Admin) |
| `ensure-cluster.sh` | scripts/ | Garante cluster com todos os recursos |
| `portfolio-daemon.sh` | scripts/ | Daemon com watchdog de port-forwards |
| `import-grafana-dashboard.sh` | scripts/ | Importa dashboard Cluster SRE |

## Port-Forwards Gerenciados

| Porta | Servico | Pod | Ambiente |
|-------|---------|-----|----------|
| 8083 | nginx-service:80 | nginx | PROD |
| 5599 | mobile-server-service:5599 | mobile-server | DEV |
| 3000 | grafana:80 | grafana | GRAFANA (127.0.0.1) |

## Recuperacao

Se a startup chain falhar em algum ponto:
1. Verificar Docker Desktop esta rodando
2. Executar manualmente: `bash scripts/ensure-cluster.sh`
3. Verificar port-forwards: `bash scripts/portfolio-daemon.sh`
4. Se persistir, rebootar e tentar novamente
