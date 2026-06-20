# Architecture Plan: Reconhecimento Completo do Ambiente

> **Data:** 2026-06-20
> **Arquiteto:** Architect A (DeepSeek V4 Flash)
> **Status:** Pronto para dispatch
> **Versão:** 2.0 (corrigida — agentes corretos, 4 waves, integridade do repositório)
> **Contexto:** Força-tarefa de reconhecimento — mapear 100% do ambiente do usuário (denoso1993) antes de qualquer intervenção.

---

## ⚠️ Correções Cruciais vs Plano Anterior

| Erro no plano v1 | Correção v2 |
|---|---|
| `explorer` executando comandos shell (schtasks, netsh, docker) | `executor-light` executa comandos shell; `explorer` só lê arquivos |
| Wave 3 era "Coleta Cluster K8s" | Wave 3 é "Validação de Rede" (conforme solicitado) |
| Wave 4 era "Validação End-to-End" | Wave 4 é "Integridade do Repositório" (conforme solicitado) |
| Cluster K8s misturado com validação de rede | Cluster K8s coleta movida para Wave 2 (via bridge) |
| 56 tarefas, superestimado | ~40 tarefas, priorizadas, tempo realista |

---

## 1. Escopo (File-Level)

| Arquivo | Finalidade |
|---------|-----------|
| `docs/ARCHITECTURE.md` | Plano de reconhecimento (este documento) |
| `docs/RECON-REPORT-WAVE1.md` | Output consolidado da Wave 1 |
| `docs/RECON-REPORT-WAVE2.md` | Output consolidado da Wave 2 |
| `docs/RECON-REPORT-WAVE3.md` | Output consolidado da Wave 3 |
| `docs/RECON-REPORT-WAVE4.md` | Output consolidado da Wave 4 |
| `docs/RECON-SUMMARY.md` | Sumário executivo final |

---

## 2. Fluxo de Dados

```
┌─────────────────────────────────────────────────────────────────────────┐
│  WAVE 1 — RECONHECIMENTO WINDOWS (sem bridge)                          │
│  executor-light  (PowerShell direto no Windows)                         │
│  explorer        (leitura de arquivos .ps1, .json, .md, .gitignore)     │
│                                                                          │
│  Coleta: scheduled tasks, netsh, processos, docker, git, portas         │
│  Saída → docs/RECON-REPORT-WAVE1.md                                     │
└───────────────────────┬─────────────────────────────────────────────────┘
                        │  (paralelo, sem dependências)
                        ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  WAVE 2 — BRIDGE SETUP + WSL + CLUSTER K8s                              │
│  executor         (PowerShell: bridge client → WSL)                      │
│                                                                          │
│  2a. Bridge: start server, testar ping/pong                             │
│  2b. WSL: distro, systemd, docker, recursos, cloudflared               │
│  2c. K8s Cluster: nodes, pods, svc, deploy, helm, events               │
│  Saída → docs/RECON-REPORT-WAVE2.md                                     │
└───────────────────────┬─────────────────────────────────────────────────┘
                        │  (depende da bridge ativa)
                        ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  WAVE 3 — VALIDAÇÃO DE REDE                                              │
│  executor-light   (curl/Invoke-WebRequest no Windows)                    │
│  executor         (curl via bridge para endpoints no WSL)               │
│  redteam          (validação cruzada da cadeia Cloudflare)              │
│                                                                          │
│  Testar: localhost:8083, :5500, :5599, :3000, :8001                    │
│  Verificar: cloudflared, netsh chain, denisdeoliveira.com.br            │
│  Saída → docs/RECON-REPORT-WAVE3.md                                     │
└───────────────────────┬─────────────────────────────────────────────────┘
                        │  (paralelo com Wave 2, mas prefere bridge ativa)
                        ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  WAVE 4 — INTEGRIDADE DO REPOSITÓRIO                                     │
│  explorer         (grep de merge conflicts, YAMLs, duplicatas)           │
│  executor-light   (git status, kubectl --dry-run)                        │
│  redteam          (validação final cruzada)                              │
│                                                                          │
│  Verificar: merge conflicts, YAML válidos, git status, duplicatas       │
│  Bootstrap: dry-run dos scripts de startup                              │
│  Saída → docs/RECON-REPORT-WAVE4.md + docs/RECON-SUMMARY.md             │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Mapa de Agentes × Capacidades

| Agente | Shell (PS/bash) | File Read | Web Fetch | Globbing | Serviço RSO |
|--------|:-:|:-:|:-:|:-:|:-:|
| `explorer` | ❌ | ✅ | ❌ | ✅ | ❌ |
| `explorer-deep` | ❌ | ✅ | ✅ | ✅ | ❌ |
| `executor` | ✅ | ✅ | ❌ | ✅ | ❌ |
| `executor-light` | ✅ | ✅ | ❌ | ✅ | ❌ |
| `redteam` | ❌ (QA gate) | ✅ | ❌ | ❌ | ❌ |
| `executor-heavy` | ✅ | ✅ | ✅ | ✅ | ❌ |

**Regra:** Se precisa rodar `schtasks`, `netsh`, `docker`, `git`, `curl` → **executor(-light)**.  
Se precisa só ler arquivos, procurar padrões → **explorer**.

---

## 4. Decomposição de Tarefas

### Wave 1 — Reconhecimento Windows (sem bridge)

**Agente primário:** executor-light (shell) + explorer (leitura)  
**Tempo estimado:** 5-8 min  
**Paralelização:** Tasks 1.1-1.7 rodam em paralelo; 1.8-1.9 em série.

| # | Tarefa | Agente | Prioridade | Depende | Comando Exato |
|---|--------|--------|-----------|---------|---------------|
| 1.1 | Scheduled Tasks | executor-light | P0 | — | `Get-ScheduledTask \| Where-Object {$\_.TaskPath -match 'portfolio\|k8s\|bridge\|wsl'} \| Format-Table TaskName,State,TaskPath -AutoSize` |
| 1.2 | Netsh Portproxy | executor-light | P0 | — | `netsh interface portproxy show all` |
| 1.3 | Processos-chave | executor-light | P0 | — | `Get-Process \| Where-Object { $\_.ProcessName -match 'cloudflared\|python\|wsl\|node\|docker\|kind\|kubectl' } \| Format-Table Id, ProcessName, CPU, @{N='StartTime';E={$\_.StartTime.ToString('HH:mm:ss')}} -AutoSize` |
| 1.4 | Docker Status | executor-light | P0 | — | `docker info 2>&1 \| Select-Object -First 20` e `docker ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'` |
| 1.5 | Git Status (k8s-portfolio-iac) | executor-light | P1 | — | `cd C:\Users\Administrator\Documents\Projects\k8s-portfolio-iac; git status --short; git branch; git log --oneline -5; git remote -v` |
| 1.6 | Git Status (WSL-Opencode-Bridge) | executor-light | P1 | — | `cd C:\Users\Administrator\Documents\Projects\WSL-Opencode-Bridge; git status --short; git branch; git log --oneline -5; git remote -v` |
| 1.7 | Portas Escutando | executor-light | P0 | — | `netstat -ano -p TCP \| findstr LISTENING \| findstr ":8083\|:5500\|:5599\|:5598\|:3000\|:8001\|:5555\|:80\|:443"` |
| 1.8 | Bridge Server Status | executor-light | P0 | — | `Test-NetConnection -ComputerName 127.0.0.1 -Port 5555 -WarningAction SilentlyContinue \| Select-Object TcpTestSucceeded` |
| 1.9 | Bridge Server Start (se necessário) | executor-light | P0 | 1.8 (se DOWN) | Se 1.8 falhar: `wsl -d Ubuntu -e python3 /mnt/c/wsl_bridge/wsl_bridge_server.py &` em background |
| 1.10 | Bridge Test Ping | executor-light | P0 | 1.9 | Usar script wsl_agent ou raw TCP: enviar `{"command":"ping"}` e verificar resposta `pong` |
| 1.11 | Ler CONTEXT.json | explorer | P1 | — | `C:\WSLBRIDGE\CONTEXT.json` (conteúdo completo) |
| 1.12 | Logs Recentes (netsh, startup) | explorer | P2 | — | `C:\wsl_bridge\logs\*` (últimas 30 linhas de cada) |
| 1.13 | Verificar arquivos sensíveis | explorer | P0 | — | Procurar por padrões: `GITAUTS.txt`, `auth.json`, `tokens`, `*.pg-password`, `ghp_` em arquivos .md, .txt, .json, .ps1, .sh |

**CA-W1:** Relatório com 13/13 tarefas. Scheduled Tasks identificadas. Netsh rules documentadas. Bridge server UP ou DOWN registrado.

---

### Wave 2 — Bridge Setup + WSL + Cluster K8s

**Agente primário:** executor (via bridge client PowerShell)  
**Tempo estimado:** 12-18 min  
**Paralelização:** Tasks 2.2-2.6 rodam em paralelo; 2.7-2.19 dependem de 2.1 (bridge ativa).

| # | Tarefa | Agente | Prioridade | Depende | Comando Exato (via bridge) |
|---|--------|--------|-----------|---------|---------------------------|
| 2.1 | Verificar Bridge Ativa | executor | P0 | 1.10 | Usar `C:\Users\Administrator\Documents\Projects\WSL-Opencode-Bridge\wsl-bridge\components\wsl_agent (1).ps1 -Cmd "ping"` OU TCP raw `{"command":"ping"}` |
| 2.2 | WSL Distro & OS | executor | P0 | 2.1 | `-Cmd "cat /etc/os-release"` |
| 2.3 | Systemd Services | executor | P0 | 2.1 | `-Cmd "systemctl list-units --type=service --state=running --no-pager"` |
| 2.4 | Systemd: Críticos | executor | P0 | 2.1 | `-Cmd "for s in docker ultimate-watchdog cloudflared-tunnel ensure-cluster cluster-ready; do echo \$s: \$(systemctl is-active \$s.service 2>/dev/null || echo 'not-found'); done"` |
| 2.5 | Docker Status (WSL) | executor | P0 | 2.1 | `-Cmd "docker info --format '{{.ServerVersion}} {{.Containers}} containers'"` e `-Cmd "docker ps -a --format 'table {{.Names}}\t{{.Status}}'"` |
| 2.6 | Recursos WSL | executor | P1 | 2.1 | `-Cmd "echo RAM: \$(free -h \| grep Mem); echo DISK: \$(df -h / \| tail -1); echo CPU: \$(nproc) cores; echo UPTIME: \$(uptime -p)"` |
| 2.7 | Kind Cluster | executor | P0 | 2.1 | `-Cmd "kind get clusters"` e `-Cmd "kubectl cluster-info --kubeconfig /etc/kubernetes/admin.conf 2>/dev/null \|\| kind get kubeconfig --name lab-sre-denoso \| kubectl cluster-info"` |
| 2.8 | Port-Forwards Ativos | executor | P0 | 2.1 | `-Cmd "ss -tlnp \| grep -E '8083\|5500\|5599\|5598\|3000\|8001'"` |
| 2.9 | Cloudflared | executor | P1 | 2.1 | `-Cmd "test -f /etc/cloudflared-token && echo 'TOKEN_EXISTS' \|\| echo 'NO_TOKEN'; cloudflared tunnel list 2>/dev/null"` |
| 2.10 | Socat Forwarders | executor | P2 | 2.1 | `-Cmd "ps aux \| grep socat \| grep -v grep"` e `-Cmd "systemctl list-units --type=service 'socat-*' --no-pager 2>/dev/null"` |
| 2.11 | Watchdog/Daemon | executor | P1 | 2.1 | `-Cmd "ps aux \| grep -E 'ultimate-watchdog\|portfolio-daemon\|ensure-everything' \| grep -v grep"` |
| 2.12 | Kubeconfig | executor | P2 | 2.7 | `-Cmd "kubectl config view --minify --kubeconfig /etc/kubernetes/admin.conf 2>/dev/null \|\| kubectl config view --minify 2>/dev/null"` |
| 2.13 | Nodes K8s | executor | P0 | 2.7 | `-Cmd "kubectl get nodes -o wide"` |
| 2.14 | Pods K8s (todos) | executor | P0 | 2.7 | `-Cmd "kubectl get pods -A -o wide"` |
| 2.15 | Services K8s | executor | P0 | 2.7 | `-Cmd "kubectl get svc -A"` |
| 2.16 | Deployments K8s | executor | P1 | 2.7 | `-Cmd "kubectl get deploy -A -o wide"` |
| 2.17 | Ingress + Namespaces | executor | P1 | 2.7 | `-Cmd "kubectl get ingress -A"` e `-Cmd "kubectl get ns --show-labels"` |
| 2.18 | Events Recentes | executor | P2 | 2.7 | `-Cmd "kubectl get events -A --sort-by=.lastTimestamp \| tail -30"` |
| 2.19 | Helm Releases | executor | P1 | 2.7 | `-Cmd "helm list -A 2>/dev/null \|\| echo 'helm not found'"` |
| 2.20 | Postgres + Grafana + Prometheus | executor | P1 | 2.14 | `-Cmd "kubectl get pods -n default -l app=postgres; kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana; kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus"` |
| 2.21 | Resource Usage | executor | P2 | 2.7 | `-Cmd "kubectl top nodes 2>/dev/null; kubectl top pods -A 2>/dev/null \|\| echo 'metrics-server not available'"` |

**CA-W2:** Bridge ativa. WSL distro/versão documentados. Systemd services listados. Cluster Kind confirmado. Pods, services, deployments de todos os namespaces coletados. Postgres/Grafana/Prometheus status confirmados.

---

### Wave 3 — Validação de Rede

**Agentes:** executor-light (Windows HTTP) + executor (WSL HTTP via bridge) + redteam (validação)  
**Tempo estimado:** 8-12 min  
**Paralelização:** Tasks 3.1-3.5 rodam em paralelo no Windows; 3.6-3.8 via bridge; 3.9-3.10 validação cruzada.

| # | Tarefa | Agente | Prioridade | Depende | Comando Exato |
|---|--------|--------|-----------|---------|---------------|
| 3.1 | HTTP: nginx PROD (localhost:8083) | executor-light | P0 | — | `curl -s -o \$null -w "%{http_code}" http://localhost:8083/` (esperado: 200) |
| 3.2 | HTTP: dev-server (localhost:5500) | executor-light | P0 | — | `curl -s -o \$null -w "%{http_code}" http://localhost:5500/` (esperado: 200/302) |
| 3.3 | HTTP: mobile (localhost:5599) | executor-light | P0 | — | `curl -s -o \$null -w "%{http_code}" http://localhost:5599/` (esperado: 200) |
| 3.4 | HTTP: Grafana (localhost:3000) | executor-light | P0 | — | `curl -s -o \$null -w "%{http_code}" http://localhost:3000/` (esperado: 200/302/401) |
| 3.5 | HTTP: K8s API (localhost:8001) | executor-light | P1 | — | `curl -s -o \$null -w "%{http_code}" http://localhost:8001/api/v1/nodes` (esperado: 200) |
| 3.6 | HTTP: via WSL (curl dentro do WSL) | executor | P1 | 2.1 | `-Cmd "curl -s -o /dev/null -w '%{http_code}' http://172.18.0.2:31701/"` — testar NodePort direto |
| 3.7 | Cloudflare Tunnel | executor | P0 | 2.1 | `-Cmd "cloudflared tunnel list 2>/dev/null \|\| echo 'cloudflared not found'"` |
| 3.8 | Netsh Chain Test | executor-light | P1 | — | `curl -s -o \$null -w "%{http_code}" http://localhost:8083/` (redundante com 3.1, mas confirmar) |
| 3.9 | denisdeoliveira.com.br | executor-light | P0 | 3.1 | `curl -s -o \$null -w "%{http_code}" -L https://denisdeoliveira.com.br/` (esperado: 200 via Cloudflare) |
| 3.10 | Prometheus Targets | executor | P1 | 2.1 | `-Cmd "kubectl port-forward svc/prometheus-server -n monitoring 9090:80 &>/dev/null & sleep 2; curl -s http://localhost:9090/api/v1/targets 2>/dev/null \| python3 -c \"import sys,json; d=json.load(sys.stdin); [print(t['labels']['job'], ':', t['health']) for t in d['data']['activeTargets']]\""` |
| 3.11 | Grafana Dashboards | executor | P2 | 2.1 | `-Cmd "kubectl port-forward svc/grafana -n monitoring 3001:80 &>/dev/null & sleep 2; curl -s http://admin:admin@localhost:3001/api/search 2>/dev/null \| python3 -c \"import sys,json; [print(d['title'], d['type']) for d in json.load(sys.stdin)]\" \|\| echo 'grafana port-forward failed'"` |
| 3.12 | **REDTEAM:** Validação Cruzada | redteam | P0 | 3.1-3.11 | Analisar outputs, verificar: toda porta NodePort tem socat/netsh correspondente? Cadeia Cloudflare→netsh→WSL→socat→Kind→Pod está funcional? |

**CA-W3:** 5/5 endpoints HTTP respondem com código < 500. denisdeoliveira.com.br responde 200/3xx. Cloudflare tunnel list mostra status ativo. Prometheus targets ≥ 50% UP. RedTeam valida cadeia completa.

---

### Wave 4 — Integridade do Repositório

**Agentes:** explorer (grep de padrões) + executor-light (git + kubectl) + redteam (validação)  
**Tempo estimado:** 8-12 min  
**Paralelização:** Tasks 4.1-4.3 rodam em paralelo; 4.4-4.6 em série; 4.7-4.8 validação.

| # | Tarefa | Agente | Prioridade | Depende | Comando Exato |
|---|--------|--------|-----------|---------|---------------|
| 4.1 | Merge Conflicts | explorer | P0 | — | Grep recursivo por `<<<<<<< HEAD` e `=======` e `>>>>>>>` em `C:\Users\Administrator\Documents\Projects\k8s-portfolio-iac\` (excluindo .git) |
| 4.2 | YAMLs Válidos (sintaxe) | executor-light | P0 | — | `Get-ChildItem -Path "C:\Users\Administrator\Documents\Projects\k8s-portfolio-iac\wsl\cluster" -Recurse -Filter *.yaml \| ForEach-Object { $name = $_.FullName; $content = Get-Content $_ -Raw; try { [System.Management.Automation.Language.Parser]::ParseInput($content, [ref]$null, [ref]$null) \| Out-Null; Write-Host "OK: $name" } catch { Write-Host "INVALID: $name - $_" } }` |
| 4.3 | YAMLs Válidos (kubectl dry-run) | executor | P1 | 2.7 | `-Cmd "for f in ~/k8s-portfolio-iac/wsl/cluster/services/portfolio/*.yaml; do echo \$f; kubectl apply --dry-run=client -f \$f 2>&1 \| head -2; done"` |
| 4.4 | Duplicatas: k8s/ vs wsl/cluster/ | explorer | P0 | — | Comparar estruturas: glob em `k8s/**/*.yaml` vs `wsl/cluster/**/*.yaml`. Identificar arquivos que existem em ambos com mesmo nome. |
| 4.5 | Git Status Completo | executor-light | P1 | — | `cd C:\Users\Administrator\Documents\Projects\k8s-portfolio-iac; git status; git log --oneline -10; git stash list` |
| 4.6 | Scripts Bootstrap — Dry Run | explorer | P1 | — | Ler e validar sintaxe dos scripts em `bootstrap/` e `scripts/`: verificar caminhos, hardcoded IPs, referências a arquivos que existem |
| 4.7 | Hardcoded IPs | explorer | P1 | — | Grep por padrões de IP `172\.\d+\.\d+\.\d+` e `192\.168\.\d+\.\d+` em todos os arquivos .sh, .ps1, .yaml, .conf (para detectar IPs hardcoded que quebram em restart) |
| 4.8 | **REDTEAM:** Validação Final | redteam | P0 | 4.1-4.7 | Consolidar: há merge conflicts? YAMLs quebrados? Duplicatas? IPs hardcoded? Recomendações de limpeza. |
| 4.9 | Gerar RECON-SUMMARY.md | executor-light | P0 | 4.8 | Escrever sumário executivo final consolidando todas as 4 waves |

**CA-W4:** 0 merge conflicts. YAMLs válidos (sintaxe + dry-run). Duplicatas documentadas. Hardcoded IPs identificados. Sumário executivo gerado.

---

## 5. Matriz de Dependências

```
Tempo ────────────────────────────────────────────────────────────────►
                                                                       
WAVE 1 ─┬─ 1.1 Scheduled Tasks ─┐                                     
         ├─ 1.2 Netsh ──────────┤                                     
         ├─ 1.3 Processos ──────┤  (paralelo, sem dependências)        
         ├─ 1.4 Docker ────────┤                                      
         ├─ 1.5 Git k8s ──────┤                                       
         ├─ 1.6 Git bridge ───┤                                       
         ├─ 1.7 Portas ───────┤                                       
         ├─ 1.8 Bridge Status ─┤──── 1.9 Bridge Start ── 1.10 Ping    
         ├─ 1.11 CONTEXT.json ─┤                                       
         ├─ 1.12 Logs ────────┤                                       
         └─ 1.13 Sensíveis ───┘                                       
                                    │                                  
WAVE 2 ────────────────────────── 2.1 Bridge Check ─┐                 
         ├─ 2.2 WSL OS ─────────┤                   │                 
         ├─ 2.3 Systemd ───────┤                    │                 
         ├─ 2.4 Systemd Crit ──┤                    │  (paralelo       
         ├─ 2.5 Docker ────────┤                     │  após 2.1)     
         ├─ 2.6 Recursos ─────┤                    │                 
         ├─ 2.7 Kind Cluster ──┤                    │                 
         ├─ 2.8 PFs Ativos ───┤                    │                 
         ├─ 2.9 Cloudflared ──┤                    │                 
         ├─ 2.10 Socat ───────┤                    │                 
         ├─ 2.11 Watchdog ────┤                    │                 
         ├─ 2.12 Kubeconfig ──┤                    │                 
         └─ 2.13-2.21 K8s ───┘                    │                 
                                                    │                  
WAVE 3 ─────────────────────────────────────────────┤  (paralelo       
         ├─ 3.1-3.5 HTTP Windows ───┐               │  com Wave 2)   
         ├─ 3.6-3.11 HTTP WSL ─────┤               │                 
         └─ 3.12 RedTeam ───────────┘               │                 
                                                    │                  
WAVE 4 ─────────────────────────────────────────────┤  (paralelo       
         ├─ 4.1 Merge Conflicts ─┐                  │  com Wave 2/3) 
         ├─ 4.2 YAML Sintaxe ────┤                  │                 
         ├─ 4.3 YAML Dry-run ────┤                  │                 
         ├─ 4.4 Duplicatas ──────┤                  │                 
         ├─ 4.5 Git Status ─────┤                  │                 
         ├─ 4.6 Scripts ────────┤                  │                 
         ├─ 4.7 Hardcoded IPs ──┤                  │                 
         ├─ 4.8 RedTeam ────────┤                  │                 
         └─ 4.9 Summary ────────┘                  │                 
                                                    │                  
                                                    ▼                  
                                         RECON-SUMMARY.md              
                                         (consolidação final)          
```

**Regras de paralelização:**
- Waves 1, 2 (após bridge check), 3, 4 podem rodar **simultaneamente** após 1.10 confirmar bridge ativa
- Se bridge falhar: Wave 2 continua limitada (sem WSL/K8s), Wave 3 continua (só testes Windows HTTP), Wave 4 continua normalmente
- Wave 4 não depende de bridge — roda 100% no Windows + explorer

---

## 6. Estratégia de Bridge

```
CASO A: Bridge já ativa (porta 5555 respondendo)
  ├── Pular tasks 1.9 (start)
  ├── Ir direto para 2.1 (uso)
  └── Todas as waves rodam em paralelo

CASO B: Bridge inativa, Python3 no WSL disponível
  ├── Executar 1.9: start bridge
  ├── Aguardar 3s, testar 1.10
  ├── Se OK: igual Caso A
  └── Se falhar: tentar 2x com --force

CASO C: Bridge inativa, WSL/Python3 indisponível
  ├── Wave 2 limitada (sem WSL/K8s)
  ├── Wave 3 limitada (só testes Windows HTTP)
  ├── Wave 1 e 4 completas
  └── Reportar: "BRIDGE UNAVAILABLE — WSL não acessível deste agente"
```

---

## 7. Critérios de Aceitação Globais

### CA-G1: Todas as 4 Waves Completas
- [ ] `docs/RECON-REPORT-WAVE1.md` — 13/13 tasks executadas
- [ ] `docs/RECON-REPORT-WAVE2.md` — 21/21 tasks executadas (ou com bridge unavailable reportado)
- [ ] `docs/RECON-REPORT-WAVE3.md` — 12/12 tasks executadas
- [ ] `docs/RECON-REPORT-WAVE4.md` — 9/9 tasks executadas
- [ ] `docs/RECON-SUMMARY.md` — consolidado final gerado

### CA-G2: Qualidade
- [ ] Nenhum erro fatal aborta wave — erros são registrados e continuam
- [ ] Cada wave reporta: tasks OK / total, issues encontradas, status
- [ ] Bridge server: status documentado (UP/DOWN/LIMITED)
- [ ] Cluster K8s: pods running/total, services, nodes documentados
- [ ] Endpoints HTTP: cada um com status code documentado
- [ ] Repositório: merge conflicts 0, YAMLs válidos, duplicatas identificadas

### CA-G3: Segurança
- [ ] Nenhum conteúdo de secret é exibido nos relatórios
- [ ] Apenas nomes de secrets (não valores) são listados
- [ ] Se GITAUTS.txt, auth.json ou tokens forem encontrados, reportar como CRITICAL sem exibir conteúdo

---

## 8. Plano de Contingência

| Problema | Ação | Responsável |
|----------|------|-------------|
| Bridge não sobe | Tentar 2x. Se falhar, reportar e continuar Waves 1+4 | executor |
| Bridge cai durante Wave 2 | Retry 1x. Se cair de novo, reportar dados parciais e continuar | executor |
| Kind cluster não existe | Reportar "cluster inexistente", pular tasks K8s | executor |
| Docker Desktop não responde | Reportar status, continuar (não é blocker) | executor-light |
| curl/HTTP falha em todos endpoints | Reportar como ISSUE GRAVE, verificar firewall/socat | executor-light |
| Merge conflict encontrado | Reportar como CRITICAL, listar arquivos conflitados | explorer |
| Proxy/GitHub rate limit | Aguardar 60s e retry 1x | executor-light |

---

## 9. Timeline e Recursos

| Wave | Agente Principal | Tasks | Estimativa | Custo ($) |
|------|-----------------|-------|-----------|-----------|
| Wave 1 | executor-light + explorer | 13 | 5-8 min | ~$0.02 |
| Wave 2 | executor | 21 | 12-18 min | ~$0.03 |
| Wave 3 | executor-light + executor + redteam | 12 | 8-12 min | ~$0.03 |
| Wave 4 | explorer + executor-light + redteam | 9 | 8-12 min | ~$0.02 |
| **Total** | 4 agentes | **55** | **~35-50 min** | **~$0.10** |

**Modelos usados:**
- executor / executor-light → DeepSeek V4 Flash (Tier 1, NVIDIA free)
- explorer → NVIDIA Qwen 397B (Tier 2)
- redteam → Qwen 3.5 397B (Tier 3)

---

## 10. Verificação Pós-Execução

Após todas as waves completarem:

```powershell
# Verificar arquivos de output
@(
    "docs/RECON-REPORT-WAVE1.md",
    "docs/RECON-REPORT-WAVE2.md",
    "docs/RECON-REPORT-WAVE3.md",
    "docs/RECON-REPORT-WAVE4.md",
    "docs/RECON-SUMMARY.md"
) | ForEach-Object {
    $path = "C:\Users\Administrator\Documents\Projects\k8s-portfolio-iac\$_"
    if (Test-Path $path) {
        Write-Host "OK: $path" -ForegroundColor Green
    } else {
        Write-Warning "MISSING: $path"
    }
}
```

### Verificação de Critérios
1. Re-ler cada RECON-REPORT e verificar se tasks foram preenchidas
2. Validar que erros foram registrados (não ignorados)
3. Se CA-G1 a CA-G3 estão satisfeitos → missão completa
4. Se houver discrepância → reportar ao RSO: "Plan deviation: [task]"
