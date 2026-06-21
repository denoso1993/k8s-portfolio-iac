# Cadeia de Inicializacao (Startup Chain)

## Visao Geral

O cluster `lab-sre-denoso` possui uma cadeia de auto-start que garante que todos os servicos subam automaticamente apos reboot do Windows ou queda do WSL.

```
Windows Login
    |
    v
[Scheduled Task: Portfolio-Daemon]
(Inicia automaticamente no login do usuario)
    |
    v
[bootstrap/start-cluster.ps1]
(PowerShell script no Windows)
    |-- Aguarda Docker Engine (ate 120s)
    |-- Verifica se WSL esta respondendo
    |-- Verifica se cluster Kind existe
    |-- Chama ensure-cluster.sh dentro do WSL
    |-- Inicia portfolio-daemon.sh em background
    |-- Testa http://localhost:8083/
    |
    v
[bootstrap/netsh-recreate.ps1]
(Executado manualmente apos reboot se IP do WSL mudar)
    |-- Detecta IP atual do WSL
    |-- Recria regras netsh portproxy
    |-- Portas: 80, 443, 5501, 5599
    |
    v
[WSL: scripts/portfolio-daemon.sh]
(Daemon principal, roda dentro do WSL)
    |
    ├── [RECOVERY] Verifica cluster Kind
    |   ├── Se cluster existe -> OK
    |   └── Se cluster nao existe -> kind create cluster
    |
    ├── [RECOVERY] Aplica manifests K8s
    |   ├── wsl/cluster/infrastructure/
    |   ├── wsl/cluster/security/
    |   ├── wsl/cluster/security/network-policies/
    |   ├── wsl/cluster/services/postgres/
    |   └── wsl/cluster/services/portfolio/
    |
    ├── [INFRA] Inicia servicos
    |   ├── port-forward nginx:8083 (0.0.0.0)
    |   ├── port-forward grafana:3000 (127.0.0.1)
    |   ├── port-forward dev-server:5500 (0.0.0.0)
    |   ├── port-forward mobile:5599 (0.0.0.0)
    |   └── kubectl proxy :8001 (0.0.0.0)
    |
    └── [MONITOR] Loop de verificacao (15s)
        ├── Cluster existe?
        ├── Port-forwards ativos?
        ├── Pods essenciais rodando?
        └── Site responde HTTP 200?
```

## Componentes

### 1. Scheduled Task (Windows)
- **Nome:** `Portfolio-Daemon`
- **Trigger:** Ao fazer login (com 1 minuto de atraso aleatorio)
- **Acao:** Executa `wsl -d Ubuntu` chamando `scripts/portfolio-daemon.sh`
- **Criada por:** `bootstrap/install-tasks.ps1`

### 2. start-cluster.ps1 (Windows)
- **Finalidade:** Script de inicializacao manual (executado tambem pela task)
- **Localizacao:** `bootstrap/start-cluster.ps1`
- **Dependencias:** Docker Engine, WSL (Ubuntu)

### 3. portfolio-daemon.sh (WSL/Linux)
- **Finalidade:** Daemon principal de manutencao do cluster
- **Localizacao:** `scripts/portfolio-daemon.sh`
- **Comportamento:**
  - Recovery completo se cluster cair
  - Monitoramento de port-forwards (recria se cair)
  - Health check do site a cada 15s
  - Auto-recuperacao de pods essenciais

### 4. ensure-cluster.sh (WSL/Linux)
- **Finalidade:** Garantir cluster com todos os recursos
- **Localizacao:** `scripts/ensure-cluster.sh`
- **Chamado por:** start-cluster.ps1, portfolio-daemon.sh
- **Acoes:**
  - Cria cluster Kind se nao existir
  - Aplica todos os manifests em ordem
  - Instala monitoring stack se necessario
  - Importa dashboard Grafana

## Recuperacao Automatica

O daemon implementa auto-recuperacao para os seguintes cenarios:

| Cenario | Acao |
|---------|------|
| Cluster Kind perdido | `kind create cluster` + re-aplica tudo |
| Port-forward caiu | Recria o port-forward especifico |
| Pod nginx nao esta Running | Re-aplica `wsl/cluster/services/portfolio/` |
| Site nao responde HTTP 200 | Log de alerta (sem acao automatica) |
| WSL reiniciou | Daemon detecta e faz recovery completo |

## Scripts Relacionados

| Script | Localizacao | Descricao |
|--------|------------|-----------|
| ensure-cluster.sh | `scripts/ensure-cluster.sh` | Cria cluster + aplica recursos |
| portfolio-daemon.sh | `scripts/portfolio-daemon.sh` | Daemon de manutencao continua |
| start-cluster.ps1 | `bootstrap/start-cluster.ps1` | Bootstrap Windows |
| netsh-recreate.ps1 | `bootstrap/netsh-recreate.ps1` | Recria regras portproxy |
| install-tasks.ps1 | `bootstrap/install-tasks.ps1` | Instala Scheduled Tasks |
| auto-recovery.ps1 | `bootstrap/auto-recovery.ps1` | Script de recuperacao manual |
