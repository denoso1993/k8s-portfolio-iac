# Laboratório Kubernetes SRE - Infraestrutura como Código

Projeto prático de Site Reliability Engineering (SRE) documentando minha jornada de aprendizado em Kubernetes, evoluindo do básico até implementações production-ready com infraestrutura 100% declarativa.

![Cluster Architecture](https://github.com/user-attachments/assets/f4d0563d-fbe8-44b8-88e7-74c77a47cb8d)

## Contexto e Objetivo

Este repositório tem dois propósitos principais:

1. **Portfólio Técnico**: Demonstrar competências práticas em Kubernetes e SRE
2. **Laboratório de Aprendizado**: Ambiente seguro para testar e validar conceitos antes de levar para produção

Diferente de tutoriais superficiais, este projeto mostra a implementação REAL de recursos que encontro no dia a dia como Senior Cloud Analyst, incluindo os desafios e lições aprendidas.

---

## O Que Foi Implementado

### 1. Cluster Kubernetes Local (Kind)

**Tecnologia:** Kubernetes v1.27.3 via Kind (Kubernetes in Docker)

**Por que Kind?**
- Permite rodar cluster completo localmente
- Ideal para testes e desenvolvimento
- Consome menos recursos que minikube
- Fácil de criar/destruir clusters

**Configuração:**
- Single-node cluster (suficiente para testes)
- WSL2 como base (Ubuntu)
- Containerd v1.7.1 como runtime
- Network policies habilitadas

**Como validar:**
```bash
kubectl get nodes
kubectl cluster-info
```

### 2. Infraestrutura como Código (Terraform)

**Tecnologia:** Terraform v1.6+

**Recursos provisionados:**
- Cluster Kind
- Namespaces
- ResourceQuotas
- LimitRanges
- Deployments
- Services
- ConfigMaps
- HPA
- Stack de monitoramento

**Benefícios:**
- 100% reprodutível
- Versionado no Git
- Documentação implícita
- Fácil rollback

### 3. Auto-Scaling (HPA)

**O que é:** Horizontal Pod Autoscaler - escala automática de pods baseado em métricas.

**Configuração atual:**
```yaml
Target CPU: 70%
Min Replicas: 1
Max Replicas: 5
Métrica: CPU usage
```

**Como testar:**
```bash
# Gerar carga
kubectl run -i --rm --restart=Never load-generator \
  --image=busybox \
  -- /bin/sh -c "while true; do wget -q -O- http://nginx-deployment; done"

# Observar scaling
kubectl get hpa nginx-hpa --watch
```

**O que esperar:**
- Sob carga > 70% CPU: escala de 1 → 5 réplicas
- Sem carga: reduz para 1 réplica após 300s
- Tempo de scale-up: ~1-2 minutos

![HPA Scaling](https://github.com/user-attachments/assets/8fce90cf-31c5-476b-8af1-37c57a47cb8d)

### 4. Segurança e Governança

#### ResourceQuota

**O que faz:** Limita recursos no namespace.

**Configuração:**
```yaml
CPU Requests:     4 cores
CPU Limits:       8 cores
Memory Requests:  4Gi
Memory Limits:    8Gi
Max Pods:         20
Max Services:     10
```

**Por que usar:**
- Previne "noisy neighbor"
- Garante recursos para workloads críticos
- Evita custos inesperados

#### LimitRange

**O que faz:** Define padrões para containers.

**Configuração:**
```yaml
Default CPU:      500m
Default Memory:   512Mi
Request CPU:      100m
Request Memory:   128Mi
```

**Por que usar:**
- Containers sem requests ganham limites padrão
- Essencial para HPA funcionar
- Evita pods sem limits

#### NetworkPolicies

**O que fazem:** Controlam tráfego de rede entre pods.

**Políticas ativas:**

1. **default-deny-all**: Bloqueia tudo por padrão
   - Segurança zero-trust
   - Requer políticas explícitas

2. **allow-dns**: Permite DNS (porta 53)
   - Necessário para resolução de nomes
   - Apenas para kube-system

3. **nginx-allow-ingress**: Permite tráfego no nginx
   - Porta 9000
   - Apenas pods com label app=nginx

**Como validar:**
```bash
kubectl get networkpolicies -n default
kubectl describe networkpolicy default-deny-all -n default
```

### 5. Monitoramento e Observabilidade

Stack completa implementada:

#### Prometheus
- Coleta métricas do cluster
- Métricas de nodes, pods, containers
- Armazenamento em série temporal

#### Grafana
- Dashboards visuais
- Alertas e notificações
- Provisionado via código

#### Loki + Promtail
- Loki: Armazenamento de logs
- Promtail: Coletor de logs
- Query language tipo LogQL

#### Metrics Server
- Fornece métricas de recursos
- Essencial para HPA
- Baixa latência

![Monitoring Stack](https://github.com/user-attachments/assets/3b997a4b-3152-4816-811b-d22ff4a56b12)

### 6. Workloads

#### Nginx (Web Server)

**Configuração:**
- Imagem: nginx (otimizada)
- Conteúdo via ConfigMap
- Porta: 9000
- Resource requests/limits definidos

**Por que ConfigMap?**
- Atualiza conteúdo sem rebuild
- Separação código/conteúdo
- Versionamento independente

#### PostgreSQL 15

**Configuração:**
- StatefulSet (estado persistente)
- PVC para dados
- Alpine image (menor)

**Por que StatefulSet?**
- Identidade única
- Ordem de deploy
- Persistência de dados

### 7. WSL Bridge (Diferencial)

**O que é:** Ponte que permite operar o cluster (WSL) via PowerShell (Windows).

**Como funciona:**
- Servidor Python no WSL (TCP 5555)
- Cliente PowerShell no Windows
- Comunicação via JSON-RPC

**Vantagens:**
- Opera K8s sem sair do Windows
- Automação via PowerShell
- Stress tests validados

**Exemplo de uso:**
```powershell
# Windows PowerShell
C:\wsl_bridge\wsl_agent.ps1 -Cmd "kubectl get nodes"
C:\wsl_bridge\stress_final.ps1
```

---

## Ferramentas de Operação (Roadmap)

Estas ferramentas fazem parte do roadmap e são mencionadas para contexto:

### k9s (Em implementação)
Terminal UI para Kubernetes. Permite navegar no cluster de forma interativa.

**Status:** Instalável via setup.sh

### Stern (Planejado)
Tail de logs em tempo real de múltiplos pods.

**Uso típico:**
```bash
stern nginx -n default
```

### Popeye (Planejado)
Scanner de saúde do cluster. Identifica problemas de configuração.

**Uso típico:**
```bash
popeye
```

### Goldilocks (Planejado)
Recomenda recursos (requests/limits) baseados em uso real.

**Vantagem:** Otimiza alocação de recursos

---

## Como Usar

### Pré-requisitos

- WSL2 (Ubuntu 20.04+)
- Docker Desktop
- Kind
- Terraform 1.6+
- kubectl

### Instalando

```bash
# Clone
git clone https://github.com/denoso1993/k8s-portfolio-iac.git
cd k8s-portfolio-iac

# Setup
./setup.sh

# Deploy
terraform init
terraform apply

# Valide
kubectl get nodes
kubectl get hpa
kubectl get pods -A
```

### Acessando as Aplicações

| Aplicação | Localhost | NodePort |
|-----------|-----------|----------|
| Nginx (Portfólio) | 8080 | 30000 |
| Grafana | 3000 | 30001 |
| Prometheus | 9090 | - |

---

## Operação Diária

### Windows (PowerShell)

```powershell
# Status do cluster
C:\wsl_bridge\wsl_agent.ps1 -Cmd "kubectl get nodes"

# Stress test HPA
C:\wsl_bridge\stress_final.ps1

# Validação
C:\wsl_bridge\validate_security.ps1
```

### WSL (Ubuntu)

```bash
cd ~/projeto-lab-sre

# Status
kubectl get all -A

# Health check
popeye  # quando instalado

# Logs
stern nginx  # quando instalado

# Otimização
./optimization.sh
```

---

## Roadmap Detalhado

### ✅ Concluído

- [x] Cluster Kind operacional
- [x] HPA (70% CPU, 1-5 réplicas)
- [x] ResourceQuota + LimitRange
- [x] 3 NetworkPolicies ativas
- [x] Prometheus + Grafana + Loki
- [x] WSL Bridge
- [x] Stress tests validados
- [x] PostgreSQL StatefulSet

### 🔄 Em Andamento

- [ ] k9s instalado e configurado
- [ ] Stern para logs
- [ ] Popeye para health checks
- [ ] Goldilocks para recommendations
- [ ] Dashboards Grafana importados

### ⏳ Planejado

- [ ] GitHub Actions (CI/CD)
- [ ] ArgoCD (GitOps)
- [ ] cert-manager (TLS)
- [ ] Trivy Operator (security scan)
- [ ] VPA (Vertical Pod Autoscaler)
- [ ] Velero (backup)

---

## Lições Aprendidas

### 1. Segurança Primeiro
ResourceQuotas e NetworkPolicies parecem burocracia até você precisar. Em produção, elas previnem:
- Vazamento de recursos
- Ataques de negação de serviço
- Configurações acidentais

### 2. IaC é Essencial
Tudo versionado e reprodutível. Já reconstruí este cluster 10+ vezes - sem IaC seria impossível.

### 3. Monitoramento Não é Opcional
Sem métricas, você está operando no escuro. Prometheus + Grafana me permitiram:
- Identificar gargalos
- Validar HPA
- Entender padrões de uso

### 4. HPA Precisa de Requests/Limits
Sem requests/limits definidos, o HPA não funciona. Ponto final.

### 5. Automação Economiza Tempo
Scripts de operação (WSL Bridge, stress tests) economizam horas de trabalho manual.

### 6. Kind é Subestimado
Para desenvolvimento/testes, Kind é imbatível. Rápido, leve e fácil de resetar.

---

## Estrutura do Repositório

```
projeto-lab-sre/
├── main.tf                    # Terraform principal
├── security.tf                # ResourceQuota, NetworkPolicy
├── provider.tf                # Providers (Kubernetes, Helm)
├── metrics-server.tf          # Metrics Server
├── hpa-nginx.yaml             # HPA configuration
├── deployment-nginx.yaml      # Nginx deployment
├── configmap-nginx.yaml       # Nginx ConfigMap
├── kind-config.yaml           # Kind cluster config
├── setup.sh                   # Setup script
├── optimization.sh            # Otimização de recursos
├── validate-cluster.sh        # Validação do cluster
└── README.md                  # Este arquivo
```

---

