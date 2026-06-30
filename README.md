<p align="center">
  <h1 align="center">Kubernetes SRE Lab</h1>
  <p align="center">
    <em>Infraestrutura como Codigo com Kubernetes, GitOps e boas praticas de SRE</em>
  </p>
</p>

<p align="center">
  <a href="https://github.com/denoso1993/k8s-portfolio-iac/blob/main/LICENSE">
    <img src="https://img.shields.io/badge/licenca-MIT-blue.svg" alt="Licenca MIT">
  </a>
  <a href="https://kubernetes.io/">
    <img src="https://img.shields.io/badge/Kubernetes-1.27.3-326CE5?logo=kubernetes" alt="K8s 1.27.3">
  </a>
  <a href="https://kind.sigs.k8s.io/">
    <img src="https://img.shields.io/badge/Kind-cluster-green" alt="Kind">
  </a>
  <a href="https://prometheus.io/">
    <img src="https://img.shields.io/badge/Monitoring-Prometheus-e6522c" alt="Prometheus">
  </a>
  <a href="https://grafana.com/">
    <img src="https://img.shields.io/badge/Dashboard-Grafana-orange" alt="Grafana">
  </a>
</p>

<p align="center">
  <a href="#visao-geral">Visao Geral</a> &middot;
  <a href="#arquitetura">Arquitetura</a> &middot;
  <a href="#ambientes">Ambientes</a> &middot;
  <a href="#zero-downtime">Zero-Downtime</a> &middot;
  <a href="#fluxo-de-trafico">Fluxo de Trafego</a> &middot;
  <a href="#componentes">Componentes</a> &middot;
  <a href="#comecando">Comecando</a> &middot;
  <a href="#autor">Autor</a>
</p>

---

## Visao Geral

Este repositorio define a infraestrutura como codigo de um cluster Kubernetes rodando localmente com Kind no WSL2. O projeto demonstra tecnicas de Site Reliability Engineering na pratica: observabilidade, resiliencia, implantacao zero-downtime e gerenciamento declarativo de infraestrutura.

O cluster executa um **site pessoal de portfolio no estilo Windows 95** em 4 ambientes (Desktop PROD/DEV, Mobile PROD/DEV), com PostgreSQL, dashboard Grafana com metricas reais do cluster e terminal interativo com dados da API do Kubernetes.

Tudo roda em **WSL2 (Ubuntu)**, com Cloudflare Tunnel gerenciado pelo systemd. O Windows fica responsavel apenas por uma scheduled task que dispara a recuperacao no boot.

---

## Arquitetura

### Especificacoes do Cluster

| Item | Valor |
|------|-------|
| Kubernetes | 1.27.3 |
| Nos | 1 (control-plane) |
| Container runtime | containerd 1.7.1 |
| Rede | Kind default (CNI: kindnet) |
| Ambiente | WSL2 (Ubuntu) + Docker |
| Memoria WSL | 8GB RAM + 4GB swap |
| Cgroup driver | cgroupfs |

### Estrutura do Repositorio

```
wsl/
  cluster/             Manifests Kubernetes (services, monitoring, infra)
  scripts/             Scripts de bootstrap e auto-recuperacao
  services/            Systemd units (socat, watchdog, cloudflared)
windows/               Scripts minimos para Windows (netsh, task)
docs/                  Documentacao e guias
audit/                 Relatorios de auditoria
```

---

## Ambientes

O cluster possui **4 ambientes** servindo variacoes do mesmo portfolio, cada um com sua propria rota de acesso:

```
+-----------------------------------------------------------+
|                   AMBIENTES DO CLUSTER                     |
+----------+----------+------------+---------------+---------+
| Ambiente | Tipo     | Porta Local| NodePort K8s  | Endpoint|
+----------+----------+------------+---------------+---------+
| PROD     | Desktop  | 8083/8084  | 31701         | externo |
| DEV      | Desktop  | 5500       | 32286         | interno |
| MOB-PROD | Mobile   | 5599       | 31807         | interno |
| MOB-DEV  | Mobile   | 5598       | 31804         | interno |
+----------+----------+------------+---------------+---------+
```

- **PROD:** Acessivel via `https://denisdeoliveira.com.br/` (Cloudflare Tunnel)
- **DEV:** Acessivel via `http://localhost:5500/` (desenvolvimento)
- **Mobile PROD:** Versao mobile do portfolio
- **Mobile DEV:** Versao mobile em desenvolvimento

---

## Zero-Downtime

Todas as implantacoes sao configuradas para **zero-downtime** durante atualizacoes:

```yaml
replicas: 2
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxUnavailable: 0    # Nunca derruba todos os pods
    maxSurge: 1          # Sobe 1 novo antes de matar 1 velho
```

### Como funciona:

```
Antes do deploy:   [Pod A] [Pod B]  <- 2 replicas servindo
Durante o deploy:  [Pod A] [Pod C]  <- Novo pod C sobe, A ainda serve
                   [Pod C] [Pod B]  <- A morre, B ainda serve
                   [Pod C] [Pod D]  <- D sobe, C serve
Apos o deploy:     [Pod C] [Pod D]  <- 2 novas replicas servindo
```

Cada pod possui **readiness probe** que so libera trafego quando o pod esta pronto. As sondas verificam se o nginx responde na porta 8080 antes de incluir o pod no service.

---

## Fluxo de Trafego

### Acesso Externo (Cloudflare)

```
Internet --> Cloudflare Edge
                |
            [TLS/QUIC]
                |
                v
        cloudflared tunnel (WSL systemd)
                |
            localhost:8083
                |
                v
        Docker proxy --> container:30080
                |
                v
        ingress-nginx (NodePort 30080)
                |
            [Ingress Rule]
                |
                v
        nginx-service:80 (ClusterIP)
                |
                v
        nginx-deployment (2 pods)
                |
                v
        Portfolio HTML (Windows 95 Theme)
```

### Acesso Local (WSL)

```
localhost:8084 --> socat --> NodePort 31701 --> nginx
localhost:5500 --> socat --> NodePort 32286 --> dev-server
localhost:5599 --> socat --> NodePort 31807 --> mobile-server
localhost:5598 --> socat --> NodePort 31804 --> mobile-dev-server
localhost:3000 --> socat --> NodePort 32039 --> grafana
```

### APIs Internas

```
/k8s/   --> nginx --> kubectl-proxy:8001 --> Kubernetes API
/grafana/ --> nginx --> grafana:80 --> Prometheus datasource
```

---

## Componentes

| Componente | Funcao | Status |
|-----------|--------|--------|
| **nginx** | Servidor web do portfolio (2 pods) | OK |
| **ingress-nginx** | Roteamento HTTP para o dominio | OK |
| **kubectl-proxy** | Proxy para API do Kubernetes (/k8s/) | OK |
| **PostgreSQL** | Banco de dados do portfolio | OK |
| **Prometheus** | Coleta de metricas do cluster | OK |
| **kube-state-metrics** | Metricas de objetos K8s | OK |
| **Grafana** | Dashboard com metricas ao vivo | OK (anonimo + embed) |
| **cert-manager** | Certificados TLS | parcial |
| **Loki** | Agregacao de logs | configurado |
| **socat** | Forwarder de portas (NodePort) | OK (4 instancias) |
| **cloudflared** | Tunnel Cloudflare no WSL | OK (systemd) |
| **watchdog** | Auto-recuperacao a cada 30s | OK (systemd) |

---

## Comecando

### Pre-requisitos

- Windows 10/11 com WSL2
- Docker Desktop
- Git

### Instalacao rapida

```bash
# 1. Clone o repositorio
git clone https://github.com/denoso1993/k8s-portfolio-iac
cd k8s-portfolio-iac

# 2. Execute o bootstrap (tudo automatico)
bash wsl/scripts/bootstrap-wsl.sh

# 3. Acesse
#    https://denisdeoliveira.com.br/  (se configurado Cloudflare)
#    http://localhost:8083/            (local via ingress)
```

O bootstrap executa 8 etapas:
1. Instala dependencias (socat, curl, jq)
2. Configura systemd services (watchdog, tunnel)
3. Aplica configuracao Docker (cgroupfs)
4. Cria o cluster Kind
5. Aplica todos os manifests K8s
6. Cria ConfigMaps com HTML
7. Inicia watchdog de auto-recuperacao
8. Verifica endpoints

### Apos a instalacao

Tudo roda automaticamente. O watchdog verifica o cluster a cada 30s e recupera qualquer falha. Em caso de reboot do Windows, uma scheduled task reinicia o WSL e o watchdog automaticamente.

---

## Seguranca

O cluster segue boas praticas de seguranca em multicamadas:

### Pod Security Standards

Cada namespace aplica o nivel de Pod Security Standard mais adequado a sua carga de trabalho:

| Nivel | Namespaces |
|-------|------------|
| restricted | default, argocd, cert-manager, monitoring, ingress-nginx |
| baseline | kube-public, kube-node-lease, local-path-storage |
| privileged | kube-system |

### Controle de Recursos

O namespace default possui as seguintes limitacoes:

- Maximo de 20 pods
- Limite de requisicao de CPU: 4 cores (8 de burst)
- Limite de requisicao de memoria: 4 GB (8 GB de burst)
- Container padrao: 100m CPU / 128 MB de requisicao

### Politicas de Rede

- Bloqueio total de ingress por padrao (default-deny)
- Regras explicitas de liberacao para nginx (porta 8080) e PostgreSQL (porta 5432)
- Acesso ao DNS permitido apenas para o kube-system

### Policy as Code

O Kyverno aplica duas politicas em modo de auditoria:

- Proibicao de containers privilegiados
- Exigencia de recursos minimos (requests e limits)

---

## Operacao

### Comandos uteis

```bash
kubectl get pods -A
kubectl get application -n argocd -o wide
kubectl top nodes
kubectl top pods -A
kubectl describe application -n argocd k8s-portfolio-iac
kubectl logs -n ingress-nginx deploy/ingress-nginx-controller
```

### Limitacoes conhecidas

- **Terraform (deprecado):** O registry.terraform.io nao e acessivel deste ambiente WSL. O Terraform foi removido do bootstrap e substituido por kubectl + Helm. Os manifests em `terraform/` e `archive/terraform/` sao mantidos apenas como referencia historica.
- **Porta 8081:** Esta porta esta ocupada por outro processo no host. O portfolio e servido na porta 8083, com redirecionamento a partir da porta 8082 via netsh do Windows.
- **Rede WSL2:** O WSL2 utiliza um adaptador de rede virtualizado. Servicos sao expostos via kubectl port-forward com --address 0.0.0.0 e proxies de porta do Windows (netsh).

---

## Auto-Recovery — 3 Camadas Sobrepostas

O cluster possui **tres camadas independentes** de auto-recovery que garantem funcionamento ininterrupto mesmo apos reboot, queda de energia, ou falha de componentes:

### 1. Systemd (WSL)
- **cluster.target** (enabled) — orquestra inicializacao no boot do WSL
- **ensure-cluster.service** — cria cluster Kind se ausente
- **ultimate-watchdog.service** — monitor + recovery a cada 30s
- **cloudflared-tunnel.service** — tunnel Cloudflare com restart=5s

### 2. Windows Scheduled Tasks
- **Portfolio-Boot** — inicia WSL + systemd no boot do Windows
- **Portfolio-Daemon** — chama start-cluster.ps1 no logon
- **Portfolio-NetshPorts** — recria netsh portproxy no logon

### 3. Docker
- Container Kind com **restart=always** — volta automaticamente apos restart do Docker

### Fluxo Completo Apos Reboot:
```
Boot → Scheduled Tasks → WSL init → systemctl start cluster.target →
  ensure-cluster → socat forwarders → cloudflared tunnel → 
  ultimate-watchdog → port-forwards kubectl → Site online!
```

Para detalhes completos, consulte docs/STARTUP-CHAIN.md.

---

## Autor

**Denis Oliveira Ramos**
Analista Cloud Senior | SRE & Infraestrutura
Barueri, SP - Brasil

[LinkedIn](https://linkedin.com/in/denis93) | denoso1993@gmail.com

---

<p align="center">
  <em>Projeto de portifolio pessoal em Infraestrutura como Codigo</em><br>
  Denis Oliveira Ramos
</p>
