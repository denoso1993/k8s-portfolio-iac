# Cadeia de Inicializacao (Startup Chain v2)

## Visao Geral

O cluster `lab-sre-denoso` possui uma cadeia de auto-start em **tres camadas sobrepostas** que garantem recuperacao automatica apos reboot do Windows, queda de energia, ou qualquer falha.

## Diagrama Atualizado

```
[Windows Boot]
    |
    |-- Scheduled Task: Portfolio-Boot (SYSTEM)
    |   `-- Inicia WSL + systemd
    |
    |-- Scheduled Task: Portfolio-NetshPorts (Logon)
    |   `-- netsh interface portproxy (3 regras: 80, 443, 8083)
    |
    |-- Scheduled Task: Portfolio-Daemon (Logon, 1min delay)
    |   `-- bootstrap/start-cluster.ps1
    |       |-- Aguarda Docker Engine (120s timeout)
    |       |-- Aguarda WSL responder
    |       `-- Chama: systemctl start cluster.target (VIA WSL)
    |
    v
[WSL2 (Ubuntu) - Systemd]
    |
    |-- docker.service (enabled)
    |
    |-- cluster.target (enabled - WantedBy=multi-user.target)
    |   |-- ensure-cluster.service (oneshot)
    |   |   |-- Cria cluster Kind se nao existir
    |   |   |-- Aplica manifests (wsl/cluster/)
    |   |   |-- Cria secrets (postgres, metrics-server)
    |   |   |-- Cria ConfigMaps (HTML, dashboards)
    |   |   `-- Seta restart=always no container Kind
    |   |
    |   |-- cluster-ready.service (oneshot - health check)
    |   |
    |   |-- socat-8084.service (nginx: NodePort 31701)
    |   |-- socat-5500.service (dev-server: NodePort 32286)
    |   |-- socat-5599.service (mobile: NodePort 31807)
    |   |-- socat-5598.service (mobile-dev: NodePort 31804)
    |   `-- cloudflared-tunnel.service (WSL nativo)
    |
    |-- ultimate-watchdog.service (enabled)
    |   |-- Monitora cluster a cada 30s
    |   |-- Recria port-forwards do kubectl:
    |   |   |-- 8083 -> nginx-service:80 (0.0.0.0) <- cloudflared
    |   |   |-- 3000 -> grafana:80 (0.0.0.0)
    |   |   |-- 5500 -> dev-server-service:5500 (0.0.0.0)
    |   |   |-- 5599 -> mobile-server-service:5599 (0.0.0.0)
    |   |   `-- 8001 -> kubectl proxy (127.0.0.1, restrito)
    |   |-- Healthcheck HTTP dos endpoints
    |   `-- Recovery completo se cluster cair
    |
    `-- wsl-bridge.service (enabled - porta 5555)
        `-- Comunicacao RSO (agente IA) <-> WSL
```

## Camadas de Auto-Recovery

| Camada | Componente | O que faz | Tempo de recuperacao |
|--------|-----------|-----------|---------------------|
| 1 | **Windows Scheduled Tasks** | Inicia WSL + cluster.target no boot do Windows | ~30s apos login |
| 2 | **Systemd cluster.target** | Orquestra Docker -> Kind -> socats -> tunnel | ~2min apos WSL init |
| 3 | **ultimate-watchdog.service** | Monitor + recovery continuo (loop 30s) | 30-45s |
| 4 | **Docker restart=always** | Container Kind reinicia automaticamente | 5-10s |

## Componentes Detalhados

### 1. cluster.target (Systemd)
- **Localizacao:** `/etc/systemd/system/cluster.target`
- **Status:** `enabled` (WantedBy=multi-user.target)
- **Dependencias:** docker.service, network-online.target
- **Servicos gerenciados:**
  - ensure-cluster.service (cria cluster + aplica manifests)
  - cluster-ready.service (health check pos-criacao)
  - socat-8084, socat-5500, socat-5599, socat-5598 (forward NodePorts)
  - cloudflared-tunnel.service (tunnel Cloudflare)

### 2. start-cluster.ps1 (Windows)
- **Localizacao:** `bootstrap/start-cluster.ps1`
- **Finalidade:** Script de inicializacao chamado pela Scheduled Task
- **Fluxo:** Docker OK? -> WSL OK? -> `systemctl start cluster.target` -> Verifica site:8083 e grafana:3000

### 3. ultimate-watchdog.sh (WSL)
- **Localizacao:** `wsl/scripts/ultimate-watchdog.sh`
- **Finalidade:** Watchdog unico de monitoramento e auto-recovery
- **Frequencia:** Loop a cada 30s (gerenciado pelo systemd com Restart=always)
- **Acoes:**
  - Verifica se cluster Kind existe (recria se perdido)
  - Verifica pods essenciais (reapply manifests se ausentes)
  - Garante port-forwards do kubectl (recria se cairem)
  - Healthcheck HTTP dos endpoints (nginx, dev, mobile, grafana, api)
  - Detecta e mata proxies kubectl inseguros

### 4. ensure-everything.sh (WSL)
- **Localizacao:** `wsl/scripts/ensure-everything.sh`
- **Finalidade:** Script mestre de bootstrap e recovery
- **Chamado por:** ensure-cluster.service, ultimate-watchdog.service
- **Acoes:**
  - Cria cluster Kind se ausente
  - Aplica manifests K8s (wsl/cluster/) - idempotente
  - Cria secrets (postgres, metrics-server) se ausentes
  - Cria ConfigMaps de HTML (dry-run+apply - zero downtime)
  - Garante socat services rodando
  - Inicia cloudflared tunnel se token existir

## Recuperacao Automatica por Cenario

| Cenario | Acao | Responsavel | Tempo |
|---------|------|-------------|-------|
| Reboot do Windows | Scheduled Task -> cluster.target -> watchdog | 3 camadas | ~3min |
| Docker Engine crash | systemd restart docker -> container Kind volta | systemd | 30s |
| Container Kind perdido | ensure-everything.sh recria cluster | watchdog | 3min |
| Port-forward caiu | Watchdog detecta e recria em 30s | watchdog | 30s |
| Cloudflare tunnel cai | systemd restart em 5s | systemd | 5-15s |
| Pod nginx morre | Kubernetes Deployment controller recria | K8s | 5s |
| WSL reinicia | systemd reinicia todos os servicos | systemd + tasks | 2min |

## Scripts Relacionados

| Script | Localizacao | Descricao |
|--------|------------|-----------|
| ensure-everything.sh | `wsl/scripts/ensure-everything.sh` | Bootstrap + recovery mestre |
| ultimate-watchdog.sh | `wsl/scripts/ultimate-watchdog.sh` | Watchdog de monitoramento |
| ensure-cluster.sh | `wsl/scripts/ensure-cluster.sh` | Criacao do cluster Kind |
| start-cluster.ps1 | `bootstrap/start-cluster.ps1` | Bootstrap Windows |
| netsh-recreate.ps1 | `bootstrap/netsh-recreate.ps1` | Recria regras portproxy |
| auto-recovery.ps1 | `bootstrap/auto-recovery.ps1` | Script de recuperacao manual |
| socat-forward.sh | `wsl/scripts/socat-forward.sh` | Wrapper de forward com deteccao de IP |
