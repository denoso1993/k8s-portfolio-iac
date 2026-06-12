# Guia de Setup do Zero

## Pre-requisitos

| Recurso | Requisito Minimo | Notas |
|---------|------------------|-------|
| **Sistema Operacional** | Windows 10/11 Pro/Enterprise | Home edition requer WSL2 manual |
| **WSL2** | Ubuntu 22.04+ | `wsl --install -d Ubuntu` |
| **Docker Desktop** | v4.25+ | Com WSL2 backend ativado |
| **RAM** | 4 GB disponivel | Cluster Kind usa ~1.5 GB |
| **Disco** | 10 GB livres | Imagens Docker + manifests |
| **Git** | v2.40+ | Para clonar o repositorio |
| **PowerShell** | 7+ (Windows) | Scripts de bootstrap |

> **Nota:** Todo o cluster roda dentro do WSL2. O Windows apenas faz proxy de portas (netsh) e gerencia scheduled tasks.

---

## Passo a passo completo

### 1. Instalar WSL2

```powershell
# Windows (PowerShell como Admin)
wsl --install -d Ubuntu
wsl --set-default-version 2
wsl --set-default Ubuntu
```

Reinicie a maquina apos a instalacao.

### 2. Instalar Docker Desktop

1. Baixe de https://www.docker.com/products/docker-desktop/
2. Durante a instalacao, ative **Settings > Resources > WSL Integration > Enable integration with Ubuntu**
3. Apos instalado, va em **Settings > Kubernetes** e desmarque "Enable Kubernetes" (usaremos Kind)
4. Verifique:

```powershell
docker info
```

### 3. Configurar WSL Memory (opcional, mas recomendado)

Crie `%USERPROFILE%\.wslconfig` no Windows:

```ini
[wsl2]
memory=4GB
processors=2
localhostForwarding=true
```

Aplique:

```powershell
copy .wslconfig %USERPROFILE%\.wslconfig
wsl --shutdown
```

### 4. Clonar o repositorio

```bash
# Dentro do WSL (Ubuntu)
git clone https://github.com/denoso1993/k8s-portfolio-iac.git
cd k8s-portfolio-iac
```

### 5. Instalar ferramentas (kubectl, kind, helm)

O repositorio possui um script que instala tudo automaticamente:

```bash
bash scripts/bootstrap.sh
```

Ou manualmente:

```bash
# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl && sudo mv kubectl /usr/local/bin/

# kind
curl -Lo ./kind https://kind.sigs.k8s.io/dl/latest/kind-linux-amd64
chmod +x ./kind && sudo mv ./kind /usr/local/bin/kind

# helm
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Verificar
kubectl version --client
kind version
helm version
```

### 6. Criar cluster e aplicar TUDO (comando unico)

```bash
bash scripts/ensure-cluster.sh
```

Este script:
- Cria o cluster Kind `lab-sre-denoso` (se nao existir)
- Aplica `k8s/infrastructure/` (ArgoCD, ingress, etc.)
- Aplica `k8s/security/` (NetworkPolicies, quotas)
- Aplica `k8s/services/portfolio/` (nginx, mobile, dev-server)
- Aplica `k8s/services/postgres/` (StatefulSet + PVC)
- Aplica `k8s/platform/` (Kyverno)
- Instala stack de monitoramento (Prometheus + Grafana + Loki)
- Importa dashboard Grafana "Cluster SRE"

Aguardar ~2 minutos para todos os pods ficarem prontos:

```bash
kubectl get pods -A
```

### 7. Configurar Windows (netsh + Scheduled Tasks)

No Windows (PowerShell como **Administrador**):

```powershell
# 7a. Recriar regras de portproxy (ip dinamico do WSL)
powershell -File bootstrap/netsh-recreate.ps1

# 7b. Instalar Scheduled Tasks (auto-start na inicializacao)
powershell -File bootstrap/install-tasks.ps1
```

> **O que cada script faz:**
> - `netsh-recreate.ps1` — Detecta IP do WSL e cria regras portproxy (80, 443, 5501, 5599)
> - `install-tasks.ps1` — Cria a Scheduled Task `Portfolio-Daemon` para iniciar o cluster automaticamente no login

### 8. Verificar URLs de acesso

| Ambiente | Porta | URL | Descricao |
|----------|-------|-----|-----------|
| PROD | **8083** | http://localhost:8083 | Portfolio Windows 95 completo |
| DEV | **5599** | http://localhost:5599 | Espelho do PROD para testes |
| GRAFANA | **3000** | http://localhost:3000 | Dashboard Cluster SRE |
| API | **8001** | http://localhost:8001 | kubectl proxy (pods/nodes) |

---

## Credenciais

| Servico | Usuario | Senha | Como obter |
|---------|---------|-------|------------|
| **Grafana** | `admin` | `admin` | Definido no deployment (`k8s/monitoring/grafana-deployment.yaml`) |
| **ArgoCD** | `admin` | (auto-gerada) | `kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d` |
| **PostgreSQL** | `postgres` | (auto-gerada) | Gerado por `scripts/generate-postgres-secret.sh` |
| **ArgoCD Web UI** | — | — | `kubectl port-forward svc/argo-cd-argocd-server -n argocd 8080:443` (acesso local) |

---

## Auto-Start (Daemon)

O cluster possui um daemon que garante funcionamento 24/7:

```
Windows (Scheduled Task)
  └── Login do usuario
       └── bootstrap/start-cluster.ps1
            └── WSL: scripts/portfolio-daemon.sh
                 ├── Verifica cluster (cria se perdido)
                 ├── Inicia port-forwards (8083, 3000, 5500, 5599, 8001)
                 └── Monitora a cada 15 segundos
```

Para detalhes completos do fluxo de auto-start, consulte `docs/STARTUP-CHAIN.md`.

---

## Port-Forwards Gerenciados

O daemon `portfolio-daemon.sh` mantem os seguintes port-forwards ativos:

| Porta Host | Servico K8s | Namespace | Escopo |
|-----------|-------------|-----------|--------|
| 8083 | svc/nginx-service | default | 0.0.0.0 (publico) |
| 3000 | svc/grafana | monitoring | 127.0.0.1 (localhost) |
| 5501 | svc/dev-server-service | default | 0.0.0.0 (publico) |
| 5599 | svc/mobile-server-service | default | 0.0.0.0 (publico) |
| 8001 | kubectl proxy | system | 0.0.0.0 (pods/nodes) |

> Os port-forwards sao automaticamente recriados pelo daemon se cairem.

---

## Troubleshooting

| Problema | Solucao |
|----------|---------|
| Cluster nao sobe | `kind delete cluster --name lab-sre-denoso && bash scripts/ensure-cluster.sh` |
| Site nao abre (8083) | Verificar port-forward: `pgrep -a -f "port-forward.*nginx"` |
| netsh parou de funcionar | Executar `powershell -File bootstrap/netsh-recreate.ps1` (IP do WSL mudou) |
| Daemon nao esta rodando | `wsl -d Ubuntu -e bash -c "bash ~/k8s-portfolio-iac/scripts/portfolio-daemon.sh"` |
| Porta ocupada | `netstat -ano | findstr :8083` e matar processo conflitante |
