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
  <a href="https://argo-cd.readthedocs.io/">
    <img src="https://img.shields.io/badge/GitOps-ArgoCD-orange" alt="ArgoCD">
  </a>
  <a href="https://kyverno.io/">
    <img src="https://img.shields.io/badge/Policy-Kyverno-9cf" alt="Kyverno">
  </a>
</p>

<p align="center">
  <a href="#visao-geral">Visao Geral</a> &middot;
  <a href="#arquitetura">Arquitetura</a> &middot;
  <a href="#comecando">Comecando</a> &middot;
  <a href="#componentes">Componentes</a> &middot;
  <a href="#seguranca">Seguranca</a> &middot;
  <a href="#operacao">Operacao</a> &middot;
  <a href="#autor">Autor</a>
</p>

---


## Arquitetura — 100% WSL Native

> **Este projeto roda INTEIRAMENTE dentro do WSL2 (Ubuntu).**
> **Nenhum software Windows e necessario alem do proprio WSL.**

```
Windows 10/11                      WSL2 (Ubuntu)
┌──────────────────────┐          ┌──────────────────────────────────┐
│  Browser             │          │  Docker Engine (nativo)          │
│  (Chrome)            │ Cloudflare│    └─ Kind Cluster K8s           │
│  ─→ site ←───────────┼──tunnel──┼──→  ├─ nginx (portfolio)        │
│                      │          │     ├─ PostgreSQL                │
│  ┌──────────────────┐│          │     ├─ Grafana + Prometheus     │
│  │ RSO (Agente IA)  ││          │     └─ Watchdog (auto-heal)      │
│  │ WSL Bridge Client││ TCP 5555 │                                   │
│  │ wsl_agent.ps1 ───┼──────────┼──→ wsl_bridge_server.py (Python) │
│  └──────────────────┘│          │     └─ Executa comandos kubectl  │
│                      │          │                                   │
│  WSL (opcional)      │          │                                   │
│  ubuntu.exe ─────────┼──────────→                                   │
└──────────────────────┘          └──────────────────────────────────┘
```

### Pre-requisitos (Windows)
- **WSL 2** com Ubuntu (`wsl --install -d Ubuntu`)
- **Nada mais.** Docker, Kind, kubectl e todo o resto sao instalados AUTOMATICAMENTE pelo bootstrap dentro do WSL.

### O que NAO e necessario
- ❌ Docker Desktop (o Docker Engine roda NATIVO no WSL)
- ❌ Nenhum software adicional no Windows
- ❌ Nenhuma configuracao manual de rede ou firewall

### Bootstrap completo (3 minutos)
```bash
# 1. Clone dentro do WSL
wsl -d Ubuntu
git clone https://github.com/denoso1993/k8s-portfolio-iac.git ~/k8s-portfolio-iac

# 2. Execute o bootstrap (instala TUDO automaticamente)
cd ~/k8s-portfolio-iac
bash wsl/scripts/bootstrap-wsl.sh

# 3. Acesse
https://denisdeoliveira.com.br/
```

### WSL Bridge — Agente de Gerenciamento (Opcional)

> **Repositorio privado:** [WSL-Opencode-Bridge](https://github.com/denoso1993/WSL-Opencode-Bridge)
> Acesso restrito ao proprietario do projeto.

O **WSL-Opencode-Bridge** e uma ponte de comunicacao entre o Windows e o WSL que permite ao **RSO** (Root Swarm Orchestrator — o agente de IA que gerencia este cluster) executar comandos diretamente no WSL sem necessidade de abrir um terminal manualmente.

```
Windows (PowerShell)              WSL (Python server)
┌─────────────────────┐          ┌──────────────────────┐
│ wsl_agent.ps1 ──────┼─TCP 5555─→ wsl_bridge_server.py │
│ -Cmd "kubectl..."   │          │ → executa comando     │
│ -Status             │          │ → retorna resultado   │
│ -Start / -Stop      │          │                       │
└─────────────────────┘          └──────────────────────┘
```

**Funcionalidades:**
- Executar comandos `kubectl`, `kind`, `docker` sem abrir o WSL
- Diagnostico remoto de problemas no cluster
- Integracao com o watchdog para auto-recovery
- Gerenciamento de port-forwards

**Como ativar (se desejar usar o RSO):**
```powershell
# No Windows (PowerShell):
C:\wsl_bridge\wsl_agent.ps1 -Start        # Inicia o servidor no WSL
C:\wsl_bridge\wsl_agent.ps1 -Cmd "kubectl get pods -A"  # Executa comandos
C:\wsl_bridge\wsl_agent.ps1 -Status       # Verifica se esta online
```

**Nota:** O bridge e opcional para o funcionamento do cluster. O cluster roda 100% autonomamente no WSL com ou sem ele. O bridge e utilizado apenas pelo RSO para facilitar o gerenciamento remoto durante sessoes de diagnostico e manutencao.



## Visao Geral

Este repositorio define a infraestrutura como codigo de um cluster Kubernetes rodando localmente com Kind. O projeto foi construido para demonstrar tecnicas de Site Reliability Engineering na pratica: GitOps, observabilidade, hardening de seguranca, politicas como codigo e gerenciamento de recursos.

O cluster executa um **site pessoal de portfolio no estilo Windows 95** (nginx) e um banco PostgreSQL, ambos gerenciados pelo ArgoCD com sincronizacao automatica a partir deste repositorio. Toda a configuracao e declarativa e versionada.

O portfolio possui layout **Windows 95 classico** no desktop + **versao mobile dedicada** (CSS proprio, janelas centralizadas, sem wallpaper), com tema visual Windows 95, terminal interativo com dados reais do kubectl via API proxy, e dashboard Grafana embutido com metricas ao vivo do cluster.

---

## Arquitetura

O ambiente consiste em um cluster Kind de no unico rodando Kubernetes 1.27.3 sobre WSL2 (Ubuntu). A estrutura de diretorios reflete a separacao por responsabilidade:

```
wsl/cluster/
  infrastructure/      metrics-server, ingress-controller, cert-manager
  monitoring/          regras de alerta do Prometheus
  security/            NetworkPolicies, quotas, PSS
  services/            aplicacoes (portfolio + postgres)
  platform/            politicas Kyverno
bootstrap/             manifesto do ArgoCD Application
scripts/               scripts de bootstrap e verificacao
archive/               relatorios historicos e Terraform legado
kind-config.yaml       definicao do cluster Kind
```

### Especificacoes do Cluster

| Item | Valor |
|------|-------|
| Kubernetes | 1.27.3 |
| No | 1 (control-plane) |
| Capacidade | Compartilhado com WSL2 host (4GB RAM alocada ao WSL2 (notebook 8GB total)) |
| Container runtime | containerd 1.7.1 |
| Rede | Kind default (CNI: kindnet) |
| Ambiente | WSL2 (Ubuntu 26.04) + Docker Engine (nativo WSL) |

---

## Componentes

### Mobile (porta 5599)

O cluster possui um deployment separado para mobile (mobile-server) com CSS otimizado:

- **Seletores de alta especificidade** (div.w, div#x, div.di) para sobrescrever CSS desktop sem conflito
- **Janelas centralizadas** ocupando 96vw de largura por calc(100dvh - 96px) de altura
- **Icones no topo** em linha horizontal, centralizados
- **Wallpaper removido** no mobile, apenas fundo verde agua (#008080)
- **Service:** porta 5599 exterma → 8080 pod interno
- **Cloudflare tunnel** configurado para o subdominio mobile


| Componente | Finalidade |
|------------|------------|
| **Kind** | Cluster Kubernetes local para desenvolvimento |
| **nginx** | Servidor web do portifolio (imagem nginxinc/nginx-unprivileged, sem root) |
| **PostgreSQL 15** | Banco relacional com StatefulSet e volume persistente |
| **ArgoCD** | Sincronizacao GitOps entre este repositorio e o cluster |
| **cert-manager** | Gerenciamento do ciclo de vida de certificados TLS |
| **Kyverno** | Motor de politicas como codigo (Policy-as-Code) |
| **Prometheus / Grafana** | Coleta de metricas e visualizacao |
| **metrics-server** | Metricas de recursos para HPA |

---

## Comecando

### Pre-requisitos

- WSL2 com Ubuntu 20.04 ou superior
- Docker Engine nativo no WSL2 (sem Docker Desktop)
- Kind (Kubernetes in Docker)
- kubectl
- Helm 3+

### Criando o cluster

O bootstrap completo do ambiente pode ser feito com os comandos abaixo. O tempo estimado e de aproximadamente 5 minutos dependendo da conexao com a internet.

```bash
git clone https://github.com/denoso1993/k8s-portfolio-iac.git
cd k8s-portfolio-iac

kind create cluster --name lab-sre-denoso --config kind-config.yaml

kubectl apply -f wsl/cluster/infrastructure/
kubectl apply -f wsl/cluster/security/
kubectl apply -f wsl/cluster/services/portfolio/
kubectl apply -f wsl/cluster/services/postgres/

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm install prometheus prometheus-community/prometheus --namespace monitoring --create-namespace
helm install grafana grafana/grafana --namespace monitoring
helm install loki-stack grafana/loki-stack --namespace monitoring

kubectl create ns argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.12.3/manifests/install.yaml
kubectl apply -f bootstrap/argocd-app.yaml
```

### Acessando os servicos

| Servico | Acesso Interno | Acesso Externo |
|---------|----------------|-----------------|
| Portfolio | ClusterIP:80 | kubectl port-forward svc/nginx-service 8083:80 |
| Grafana | monitoring:80 | kubectl port-forward svc/grafana -n monitoring 3000:80 |
| Prometheus | monitoring:9090 | kubectl port-forward svc/prometheus-server -n monitoring 9090:9090 |
| ArgoCD | argocd:443 | kubectl port-forward svc/argocd-server -n argocd 8080:443 |
| Mobile (DEV) | 5599 (host) / 8080 (pod) | kubectl port-forward svc/mobile-server-service 5599:8080 |

> Credenciais padrao do Grafana: admin / admin. A senha do ArgoCD e obtida via `kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d`

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
