# Laboratório Kubernetes SRE - Infraestrutura como Código

Projeto prático de Site Reliability Engineering (SRE) focado em implementar e documentar um cluster Kubernetes production-ready usando infraestrutura declarativa via Terraform.

![Cluster Architecture](https://github.com/user-attachments/assets/f4d0563d-fbe8-44b8-88e7-74c77a47cb8d)

## Contexto do Projeto

Este repositório documenta minha jornada de aprendizado em Kubernetes, evoluindo de conceitos básicos até a implementação de recursos encontrados em ambientes de produção. O cluster roda localmente usando Kind (Kubernetes in Docker) dentro do WSL2, o que permite simular um ambiente real com custo zero e total controle.

O diferencial deste projeto é a abordagem de Infraestrutura como Código (IaC), onde todo o ambiente é provisionado de forma declarativa via Terraform, eliminando configurações manuais e garantindo reprodutibilidade.

## O Que Foi Implementado

### 1. Cluster e Infraestrutura

O ambiente é composto por um cluster Kubernetes single-node rodando em Kind, com todos os componentes essenciais para um ambiente production-like:

- **Kubernetes v1.27.3** via Kind
- **Infraestrutura 100% declarativa** com Terraform
- **WSL2** como base (Ubuntu)
- **Containerd v1.7.1** como runtime
- **Network policies** para segmentação de rede

### 2. Workloads

Duas aplicações principais rodam no cluster:

- **Nginx** como web server, com conteúdo servido via ConfigMap (permite atualizações sem rebuild da imagem)
- **PostgreSQL 15** em StatefulSet com PVC para persistência de dados

### 3. Auto-Scaling (HPA)

Horizontal Pod Autoscaler configurado para escalar automaticamente baseado em uso de CPU:

- Target: 70% de utilização de CPU
- Mínimo: 1 réplica
- Máximo: 5 réplicas
- Métrica: CPU usage do container

O HPA foi testado e validado com stress tests, escalando de 1 para 4-5 réplicas sob carga.

![HPA Configuration](https://github.com/user-attachments/assets/8fce90cf-31c5-476b-8af1-37c57a47cb8d)

### 4. Segurança e Governança

Foram implementados controles de segurança no namespace default para garantir boas práticas:

**ResourceQuota:**
- CPU: 4 cores para requests, 8 cores para limits
- Memória: 4Gi para requests, 8Gi para limits
- Máximo de 20 pods
- Máximo de 10 services

**LimitRange:**
- CPU padrão: 500m
- Memória padrão: 512Mi
- Request mínimo: 100m CPU, 128Mi memória

**NetworkPolicies (3 ativas):**
1. default-deny-all: Bloqueia todo tráfego ingress/egress por padrão
2. allow-dns: Permite resolução DNS (porta 53) para kube-system
3. nginx-allow-ingress: Permite tráfego na porta 9000 para o nginx

### 5. Monitoramento e Observabilidade

Stack completa de monitoramento implementada:

- **Prometheus**: Coleta de métricas do cluster e aplicações
- **Grafana**: Dashboards provisionados via código
- **Loki + Promtail**: Centralização e busca de logs
- **Metrics Server**: Fornece métricas de recursos para o HPA

![Monitoring Stack](https://github.com/user-attachments/assets/3b997a4b-3152-4816-811b-d22ff4a56b12)

### 6. Automação e Ponte Windows-WSL

Um dos diferenciais deste projeto é a WSL Bridge, que permite operar o cluster Kubernetes (que roda no WSL) diretamente do Windows via PowerShell, facilitando o dia a dia de operações.

## Como Usar

### Pré-requisitos

- WSL2 (Ubuntu 20.04 ou superior)
- Docker Desktop
- Kind instalado no WSL
- Terraform 1.6+
- kubectl configurado

### Instalando

```bash
# Clone o repositório
git clone https://github.com/denoso1993/k8s-portfolio-iac.git
cd k8s-portfolio-iac

# Rode o script de setup
./setup.sh

# Aplique a infraestrutura
terraform init
terraform apply

# Valide o cluster
kubectl get nodes
kubectl get hpa
kubectl get pods -A
```

### Acessando as Aplicações

**Nginx (Portfólio):**
- Localhost: 8080 (via port-forward)
- NodePort: 30000

**Grafana:**
- Localhost: 3000 (via port-forward)
- NodePort: 30001

**Prometheus:**
- Localhost: 9090 (via port-forward)

## Operação Diária

### Do Windows (PowerShell)

```powershell
# Usando a ponte WSL para operar o cluster
C:\wsl_bridge\wsl_agent.ps1 -Cmd "kubectl get nodes"

# Testar auto-scaling do HPA
C:\wsl_bridge\stress_final.ps1

# Validar segurança
C:\wsl_bridge\validate_security.ps1
```

### Do WSL (Ubuntu)

```bash
cd ~/projeto-lab-sre

# Status do cluster
kubectl get all -A

# Health check
popeye

# Logs em tempo real
stern nginx
```

## Roadmap

### Concluído

- Cluster Kind operacional
- HPA configurado (70% CPU, 1-5 réplicas)
- Security hardening (ResourceQuota, LimitRange, NetworkPolicies)
- WSL Bridge para operação Windows-WSL
- Stress tests validados
- Prometheus + Grafana + Loki

### Em Andamento

- Instalação de k9s, Stern e Popeye para operação
- Goldilocks para recommendations de recursos
- Dashboards Grafana importados

### Planejado

- GitHub Actions para validação automática de Terraform
- ArgoCD para GitOps
- cert-manager para TLS automático
- Trivy Operator para scan de vulnerabilidades

## Lições Aprendidas

Durante a implementação deste projeto, algumas lições foram fundamentais:

1. **Segurança primeiro**: ResourceQuotas e NetworkPolicies previnem problemas em produção
2. **IaC é essencial**: Tudo versionado e reprodutível, sem configurações manuais
3. **Monitoramento não é opcional**: Sem métricas, você está operando no escuro
4. **HPA precisa de requests/limits**: Sem isso, o auto-scaling não funciona
5. **Automação economiza tempo**: Scripts de operação fazem diferença no dia a dia

## Estrutura do Repositório

```
projeto-lab-sre/
├── main.tf                    # Terraform principal
├── security.tf                # ResourceQuota, NetworkPolicy
├── provider.tf                # Providers (Kubernetes, Helm)
├── metrics-server.tf          # Metrics Server
├── hpa-nginx.yaml             # HPA configuration
├── deployment-nginx.yaml      # Nginx deployment
├── kind-config.yaml           # Kind cluster config
├── setup.sh                   # Script de setup
├── optimization.sh            # Otimização de recursos
├── validate-cluster.sh        # Validação do cluster
└── README.md                  # Este arquivo
```

## Sobre o Autor

**Denis Oliveira Ramos**  
Senior Cloud Analyst | SRE & Infrastructure  
Barueri, SP - Brasil

- **LinkedIn:** [linkedin.com/in/denis93](https://linkedin.com/in/denis93)
- **Currículo:** [Google Drive](https://drive.google.com/open?id=1AtSEc-qtGJzdPCroJEleJrU8U6OsDz2w)
- **Certificados:** [Pasta Completa](https://drive.google.com/drive/folders/1k_4mO-j4WEoaIGngR9cGLX1WpVSKC-AD)

---

MIT License
