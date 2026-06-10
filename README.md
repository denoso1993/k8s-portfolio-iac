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

## Visao Geral

Este repositorio define a infraestrutura como codigo de um cluster Kubernetes rodando localmente com Kind. O projeto foi construido para demonstrar tecnicas de Site Reliability Engineering na pratica: GitOps, observabilidade, hardening de seguranca, politicas como codigo e gerenciamento de recursos.

O cluster executa um **site pessoal de portfolio no estilo Windows 95** (nginx) e um banco PostgreSQL, ambos gerenciados pelo ArgoCD com sincronizacao automatica a partir deste repositorio. Toda a configuracao e declarativa e versionada.

O portfolio possui layout **Windows 95 classico** no desktop + **versao mobile dedicada** (CSS proprio, janelas centralizadas, sem wallpaper), com tema visual Windows 95, terminal interativo com dados reais do kubectl via API proxy, e dashboard Grafana embutido com metricas ao vivo do cluster.

---

## Arquitetura

O ambiente consiste em um cluster Kind de no unico rodando Kubernetes 1.27.3 sobre WSL2 (Ubuntu). A estrutura de diretorios reflete a separacao por responsabilidade:

```
k8s/
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
| Ambiente | WSL2 (Ubuntu 26.04) + Docker Desktop (29.5.3) |

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
- Docker Desktop com integracao WSL2
- Kind (Kubernetes in Docker)
- kubectl
- Helm 3+

### Criando o cluster

O bootstrap completo do ambiente pode ser feito com os comandos abaixo. O tempo estimado e de aproximadamente 5 minutos dependendo da conexao com a internet.

```bash
git clone https://github.com/denoso1993/k8s-portfolio-iac.git
cd k8s-portfolio-iac

kind create cluster --name lab-sre-denoso --config kind-config.yaml

kubectl apply -f k8s/infrastructure/
kubectl apply -f k8s/security/
kubectl apply -f k8s/services/portfolio/
kubectl apply -f k8s/services/postgres/

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
| Grafana | monitoring:80 | kubectl port-forward svc/grafana -n monitoring 3090:80 |
| Prometheus | monitoring:9090 | kubectl port-forward svc/prometheus-server -n monitoring 9090:9090 |
| ArgoCD | argocd:443 | kubectl port-forward svc/argocd-server -n argocd 8080:443 |

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

- **Terraform:** O registry do provider Terraform (registry.terraform.io) nao e acessivel deste ambiente WSL devido a restricoes de resolucao de DNS. Toda a infraestrutura e provisionada via kubectl e Helm.
- **Porta 8081:** Esta porta esta ocupada por outro processo no host. O portfolio e servido na porta 8083, com redirecionamento a partir da porta 8082 via netsh do Windows.
- **Rede WSL2:** O WSL2 utiliza um adaptador de rede virtualizado. Servicos sao expostos via kubectl port-forward com --address 0.0.0.0 e proxies de porta do Windows (netsh).

---



---

## Seguranca

O cluster passou por auditoria de seguranca em 10/06/2026. As seguintes medidas foram implementadas:

### Web (nginx + HTML)
- **Content-Security-Policy** (CSP) rigido: scripts apenas 'self', iframe apenas Grafana
- **X-Frame-Options: DENY** ? protecao contra clickjacking
- **X-Content-Type-Options: nosniff** ? protecao contra MIME sniffing
- **Referrer-Policy** e **Permissions-Policy** configurados

### Cluster (Kubernetes)
- **kubectl proxy restrito**: apenas endpoints `/api/v1/pods` e `/api/v1/nodes` via `--accept-paths`
- **Grafana**: port-forward restrito a localhost (`127.0.0.1`)
- **NetworkPolicies**: default-deny ingress + regras especificas para nginx (8080) e postgres (5432)
- **nginx**: `proxy_set_header Host localhost` ? evita host injection
- **Containers**: non-root (nginx user 101, postgres user 70) com `capabilities drop: ALL`

### Rede
- **TLS**: Cloudflare com certificado valido
- **Tunnel**: Cloudflare Tunnel (sem exposure de IP real)

> Para detalhes completos, veja [SECURITY.md](SECURITY.md).


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
