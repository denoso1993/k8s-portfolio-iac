# Kubernetes SRE Lab - Infrastructure as Code

[![GitHub](https://img.shields.io/badge/GitHub-Repository-blue)](https://github.com/denoso1993/k8s-portfolio-iac)
[![K8s](https://img.shields.io/badge/K8s-v1.27.3-blue)](https://kubernetes.io/)
[![Terraform](https://img.shields.io/badge/Terraform-IaC-purple)](https://www.terraform.io/)

Este repositório documenta minha jornada prática com **Kubernetes e Site Reliability Engineering (SRE)**, evoluindo de conceitos básicos até implementações production-ready com infraestrutura 100% declarativa via Terraform.

## O Que Este Projeto Demonstra

- **Cluster Kubernetes Local**: Kind (Kubernetes in Docker) totalmente funcional
- **Auto-Scaling**: HPA validado sob carga real (1 → 4 réplicas)
- **GitOps**: ArgoCD com sincronização automática GitHub → Cluster
- **TLS Automático**: Cert-Manager com Let's Encrypt
- **Segurança**: PSS (baseline enforce) + NetworkPolicies
- **Observabilidade**: Prometheus + Grafana + Loki stack
- **Banco de Dados**: PostgreSQL com StatefulSet e persistência

## Arquitetura Implementada

| Componente | Tecnologia | Status |
|------------|------------|--------|
| **Orquestração** | Kubernetes (Kind v1.27.3) | Ready |
| **IaC** | Terraform + Helm | 100% declarativo |
| **Web Server** | Nginx (PSS-compliant) | Ready |
| **Database** | PostgreSQL 15 (StatefulSet) | PVC persistente |
| **Auto-Scaling** | HPA (70% CPU, 1-5 réplicas) | Validado |
| **GitOps** | ArgoCD | Sync automático |
| **TLS** | Cert-Manager (Let's Encrypt) | Auto-renovável |
| **Métricas** | Prometheus + Metrics Server | Ativo |
| **Logs** | Loki + Promtail | Centralizado |
| **Dashboards** | Grafana | Provisionado |
| **Segurança** | PSS + NetworkPolicy | Implementado |

## Segurança e Governança

### ResourceQuota (Namespace: default)
- **CPU**: 4 cores request / 8 cores limit
- **Memória**: 4Gi request / 8Gi limit
- **Pods**: 20 max
- **Services**: 10 max

### LimitRange (Padrões para Containers)
- **Default CPU**: 500m
- **Default Memory**: 512Mi
- **Request CPU**: 100m
- **Request Memory**: 128Mi

### Pod Security Standards
- **Nível**: `baseline` (enforce) + `restricted` (audit/warn)
- **Configurações**: runAsNonRoot, capabilities drop ALL, seccompProfile RuntimeDefault

### NetworkPolicies Ativas
- `default-deny-ingress`: Zero-trust padrão
- `allow-dns`: DNS para kube-system
- `nginx-allow-ingress`: Tráfego porta 8080
- `postgres-allow-from-nginx`: Apenas nginx → postgres (5432)

## Como Usar

### Pré-requisitos
- WSL2 (Ubuntu 20.04+)
- Docker Desktop
- Kind
- Terraform 1.6+
- kubectl

### Deploy do Cluster
```bash
git clone https://github.com/denoso1993/k8s-portfolio-iac.git
cd k8s-portfolio-iac
./setup.sh
terraform init
terraform apply
kubectl get nodes
```

### Acessando as Aplicações

| Aplicação | Porta Local | NodePort |
|-----------|-------------|----------|
| Nginx (Portfolio) | 8081 | 30000 |
| Grafana | 3000 | 30001 (admin/admin) |
| Prometheus | 9090 | - |

## Testes Validados

### 1. HPA (Horizontal Pod Autoscaler)

**Objetivo:** Validar auto-scaling sob carga

**Configuração:**
- Threshold: 80% CPU
- Mínimo: 1 réplica
- Máximo: 5 réplicas

**Teste Realizado:**
```bash
kubectl run load-generator --image=busybox --replicas=3 \
  --command -- while true; do wget nginx-service; done
```

**Resultados:**

| Métrica | Inicial | Sob Carga | Após Scaling |
|---------|---------|-----------|--------------|
| **Réplcias** | 1 | 1 → 2 → 4 | 4 |
| **CPU** | 0% | 152% | 70-75% |
| **Tempo** | - | 30s | 2min |

**Conclusão:** HPA escalou de 1 → 4 réplicas quando CPU atingiu 152%, estabilizando em 70-75%.

---

### 2. Pod Security Standards (PSS)

**Objetivo:** Implementar segurança em nível de pod

**Nível:** `baseline` (enforce) + `restricted` (audit/warn)

**Validação:**
```bash
kubectl get namespace default -o jsonpath='{.metadata.labels}'
# Result: pod-security.kubernetes.io/enforce=baseline
```

**Conclusão:** Nginx rodando como usuário não-root (UID 101), sem privilégios elevados.

---

### 3. NetworkPolicies

**Objetivo:** Segmentação de rede (zero-trust)

**Políticas Implementadas:**
- `default-deny-ingress`: Bloqueia todo tráfego de entrada por padrão
- `nginx-network-policy`: Permite tráfego na porta 8080
- `postgres-network-policy`: Apenas nginx pode acessar PostgreSQL (5432)

**Conclusão:** Segmentação de rede funcionando corretamente.

---

### 4. GitOps com ArgoCD

**Objetivo:** Sincronização automática GitHub → Cluster

**Configuração:**
- **Application:** `k8s-portfolio-iac`
- **Sync Policy:** Automated (prune, selfHeal)
- **Repositório:** https://github.com/denoso1993/k8s-portfolio-iac

**Fluxo Testado:**
1. Alteração no `deployment-nginx.yaml` (adicionado label `version: v2`)
2. Commit e push no GitHub
3. ArgoCD detecta mudança (≈ 30s)
4. Sync automático aplicado
5. Deployment atualizado no cluster

**Validação:**
```bash
kubectl get application -n argocd
# Result: k8s-portfolio-iac  Synced  Healthy
```

**Conclusão:** GitOps operacional, sincronização automática validada.

---

### 5. Cert-Manager (TLS Automático)

**Objetivo:** Gerenciar certificados TLS automaticamente

**Configuração:**
- **ClusterIssuer:** `selfsigned-issuer` (auto-assinado)
- **ClusterIssuer:** `letsencrypt-staging` (Let's Encrypt)
- **Certificate:** `nginx-selfsigned-cert`

**Validação:**
```bash
kubectl get certificate nginx-selfsigned-cert
# Result: READY=True, SECRET=nginx-tls-secret
```

**Conclusão:** Certificados TLS gerados e vinculados ao Ingress.

---

## Status do Cluster

### Recursos (Última Verificação: 2026-05-12)

```
Nodes:        1/1 Ready (v1.27.3)
Pods:         27/27 Running (100%)
Uptime:       15h+
Namespaces:   default, monitoring, cert-manager, argocd, goldilocks
```

### Componentes Implementados

| Componente | Namespace | Pods |
|------------|-----------|------|
| **ArgoCD** | argocd | 7 Running |
| **Cert-Manager** | cert-manager | 3 Running |
| **Goldilocks** | goldilocks | 1 Running |
| **Ingress (TLS)** | default | nginx-ingress |

## Roadmap

### Concluído (Fase 1 - Fundamentos)
- [x] Cluster Kind operacional
- [x] HPA configurado e validado (70% CPU, 1-5 réplicas)
- [x] Security hardening (PSS + NetworkPolicies)
- [x] Stack de monitoramento (Prometheus + Grafana + Loki)
- [x] PostgreSQL StatefulSet
- [x] Stress tests validados
- [x] GitOps com ArgoCD
- [x] TLS automático (Cert-Manager)

### Em Andamento (Fase 2 - Produtividade)
- [ ] k9s + Stern para operação
- [ ] Goldilocks para recommendations
- [ ] Dashboards Grafana customizados

### Planejado (Fase 3 - CI/CD)
- [ ] GitHub Actions workflows
- [ ] Validação automática de PRs
- [ ] Deploy automático

### Futuro (Fase 4 - GitOps Avançado)
- [x] ArgoCD instalado
- [x] Sync automático configurado
- [ ] Image automation

## Métricas do Projeto

| Métrica | Status |
|---------|--------|
| **Uptime Cluster** | ~99% (15h+) |
| **Resource Utilization** | Otimizado (70% target) |
| **IaC Coverage** | 100% |
| **HPA Status** | 0%/80% (1/5 réplicas) |
| **GitOps Sync** | Automated |
| **TLS Certificates** | Auto-renewable |
| **Última Atualização** | 2026-05-12 |

## Sobre o Autor

**Denis Oliveira Ramos**  
Senior Cloud Analyst | SRE & Infrastructure  
Barueri, SP - Brasil

Atuo com infraestrutura cloud e automação, focando em práticas de SRE e Infrastructure as Code. Este projeto documenta minha jornada e serve como referência para outros profissionais.

### Links
- **LinkedIn:** [linkedin.com/in/denis93](https://linkedin.com/in/denis93)
- **Currículo PT-BR:** [Google Drive](https://drive.google.com/file/d/11fzA0o9tvPZmhhwIsCuknAiWwu8YIlkJ/view)
- **Currículo EN:** [Google Drive](https://drive.google.com/file/d/1Yhzihbq8T9fV_U4FzxqY1EDke4dhgNUS/view)
- **Certificados:** [Pasta Completa](https://drive.google.com/drive/folders/1k_4mO-j4WEoaIGngR9cGLX1WpVSKC-AD)

---

*Projeto de portfólio pessoal - Denis Oliveira Ramos*
