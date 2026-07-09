# Guia de Recuperacao do Portfolio

## Apos um REBOOT do Windows:

### Recuperacao AUTOMATICA (recomendado)
O sistema possui 4 camadas de auto-recovery:

1. **Windows Scheduled Tasks** - Disparam no boot/logon:
   - Portfolio-Boot - Inicia WSL + Daemon v5 no boot (como SYSTEM)
   - Portfolio-Daemon - Fallback no logon do usuario
   - Portfolio-CloudflareTunnel - Tunnel Cloudflare
   - Portfolio-NetshPorts - Portproxy do Windows

2. **Daemon v5** (scripts/portfolio-daemon.sh) - Monitoramento a cada 15s:
   - Recria cluster Kind se perdido
   - Aplica todos os manifests K8s
   - Instala monitoring (Prometheus + Grafana) via Helm
   - Sobe proxies (8001, 8002) e port-forwards (8083, 3000, 5500, 5599)

3. **Watchdog** (scripts/daemon-watchdog.sh) - Monitoramento secundario

4. **Windows Script** (ootstrap/auto-recovery.ps1) - Orchestrador manual

### Recuperacao MANUAL (se o auto-recovery falhar)


### Recuperacao COMPLETA (formatou o PC)



## Arquitetura de Recuperacao



## Servicos e Portas

| Servico | Porta | Acesso |
|---------|-------|--------|
| Site (PROD) | 8083 | http://localhost:8083 |
| Site (DEV) | 5500 | http://localhost:5500 |
| Mobile | 5599 | http://localhost:5599 |
| Grafana | 3000 | http://localhost:3000 (admin/admin) |
| API K8s | 8002 | http://localhost:8002/api/v1/... |
| PostgreSQL | 5432 | Interno ao cluster |

## Arquivos de Recovery

| Arquivo | Funcao |
|---------|--------|
| scripts/restore-all.sh | Script mestre de recovery (WSL) |
| scripts/portfolio-daemon.sh | Daemon de monitoramento v5 |
| scripts/daemon-watchdog.sh | Watchdog secundario |
| scripts/install-monitoring.sh | Instala Prometheus + Grafana via Helm |
| scripts/bootstrap/kind-config.yaml | Configuracao do cluster Kind |
| ootstrap/auto-recovery.ps1 | Orchestrador Windows |
| wsl/cluster/monitoring/prometheus-manifests.yaml | Manifests do Prometheus |
| wsl/cluster/monitoring/grafana-manifests.yaml | Manifests do Grafana |
| wsl/cluster/monitoring/cluster-sre-dashboard.json | Dashboard do cluster |
