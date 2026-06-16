# Sala de Planejamento - Reestruturacao k8s-portfolio-iac

Data: 16/06/2026

---

## 1. RAIOS-X DO PROJETO

### 1.1 Topologia atual

WINDOWS - netsh -> WSL - socat -> Kind -> NodePort -> Pod

- Windows: cloudflared tunnel, netsh portproxy, scheduled tasks
- WSL: socat forwarders (systemd), kubectl proxy, Kind cluster
- Kind: 5 servicos NodePort (nginx, dev, mobile-p, mobile-d, grafana)

### 1.2 Matriz de responsabilidades

| Componente         | Hoje     | Ideal    |
|------------------|---------|---------|
| Kind cluster       | WSL      | WSL      |
| socat forwarders   | WSL sysd | WSL sysd |
| kubectl proxy      | WSL      | WSL      |
| cloudflared tunnel | Windows  | WSL ?    |
| netsh portproxy    | Windows  | WSL ?    |
| Scheduled tasks    | Windows  | systemd  |
| Scripts .sh        | WSL      | WSL      |
| Scripts .ps1       | Windows  | eliminar |
| Git/IaC            | WSL      | WSL      |

### 1.3 O que pode mudar
\n*----------------------------------------------------------------
**Cloudflared no WSL:**
 - Elimina netsh loopback + dependencia Windows
 - Troubleshooting mais facil (tudo no mesmo logar)
 - Cloudflared tem binary Linux, funciona

**netsh pode sumir?**
 - Se cloudflared for pro WSL, netsh loopback morre naturalmente
 - netsh 0.0.0.0:PORT -> NodePort mantido para acesso externo direto
 - Ou substituir por iptables no WSL
**Scheduled tasks podem virar systemd:**
 - Portfolio-Boot, Portfolio-Daemon, Portfolio-CloudflareTunnel
 - Tudo num target systemd so: cluster.target
 - Windows: 1 unica task chamando wsl systemctl start cluster.target

---

## 2. ARQUITETURA ALVO

WINDOWS (1%)                      WSL (99%)
------------------------         ------------------------
1 Scheduled Task:                cloudflared tunnel (systemd)
  wsl -d Ubuntu -- sh -c          socat forwarders (systemd)
    "systemctl start cluster"     kubectl proxy (systemd)
                                  Kind Cluster
                                  bootstrap scripts (.sh)
                                  Git / IaC
                                  Makefile

### 2.1 WSL assume tudo
- Cluster K8s
- Forwarders (socat)
- K8s API proxy
- Cloudflared tunnel (se aprovado)
- Todos os scripts
- Systemd para services

### 2.2 Windows so o essencial
- 1 scheduled task trigger
- netsh portproxy (se mantido, 2 regras)

---

## 3. DECISOES

### D1: Cloudflared no WSL?
( ) Sim - tunnel no WSL, elimina Windows dependency
( ) Nao - mantem no Windows (status quo)

### D2: Estrutura de diretorios?
Proposta:
k8s-portfolio-iac/
|-- wsl/cluster/       # Kind config + manifests|-- wsl/services/      # systemd units
|-- wsl/scripts/      # bootstrap, deploy
|-- wsl/monitoring/    # Prometheus, Grafana, Loki
|-- windows/           ## netsh + task (minimo)
|-- docs/              ## documentacao
|-- audit/             ## relatorios
|-- Makefile

### D3: Helm dumps?
( ) Manter (pragmatico)
( ) Substituir por values + template (profissional)

### D4: CI/CD?
( ) Nao, ArgoCD resolve
( ) Makefile basico (cluster, deploy, clean, test)
( ) GitHub Actions completo

---

## 4. FORCA-TAREFA

### Fase 1 - Seguranca
[ ] Remover credenciais vazadas dos docs
[ ] Corrigir IP hardcoded nginx-secure.conf
[ ] Corrigir path cluster-check.sh
 ] Substituir proxies inseguros (5 scripts)

### Fase 2 - Limpeza
[ ] Migrar cloudflared para WSL (se aprovado)
[ ] Deletar pf-J.service legados
[ ] Deletar terraform/ + archive/
[ ] Deletar arquivos orfaos
[ ] Consolidar scripts duplicados

### Fase 3 - Automacao
[ ] Nova estrutura de diretorios
[ ] Makefile basico
[ ] Systemd cluster.target
[ ] bootstrap.sh unificado

### Fase 4 - CI/CD
[ ] GitHub Actions
[ ] Security scan (gitleaks)

---

## 5. PENDENCIAS

1. Cloudflared no WSL: sim ou nao?
2. Estrutura de diretorios: aprovada?
3. Prioridade das fases?