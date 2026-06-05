# Roadmap - K8s Portfolio IAC

**Data:** 2026-05-12  
**Cluster:** lab-sre-denoso (Kind v1.27.3)  
**Status:** Produção

## Concluído (2026-05-12)

### Infraestrutura Base
- [x] Cluster Kind operacional (17h+ uptime)
- [x] HPA validado (1 → 4 réplicas sob carga)
- [x] Metrics Server ativo
- [x] Prometheus + Grafana + Loki stack
- [x] ResourceQuota + LimitRange
- [x] NetworkPolicies (zero-trust)
- [x] Pod Security Standards (baseline enforce)

### GitOps e Automação
- [x] ArgoCD instalado e operacional
- [x] GitOps validado (sync automático GitHub → Cluster)
- [x] Cert-Manager com TLS automático
- [x] Goldilocks instalado (coleta de dados)

### Ferramentas
- [x] k9s instalado (v0.32.5)
- [x] Documentação profissional (README limpo)
- [x] Git histórico limpo (9+ commits)

### Monitoramento
- [x] Prometheus ativo
- [x] Grafana provisionado
- [x] Loki + Promtail (logs)
- [x] Dashboards básicos

## Em Andamento

### Produtividade
- [ ] Stern (download falhando - tentar snap/apt)
- [ ] GitHub Actions (token precisa escopo "workflow")
- [ ] k9s no PATH (atualmente /tmp/k9s)

### Dashboards Grafana
- [ ] Importar dashboard 6417 (Kubernetes Cluster)
- [ ] Importar dashboard 13332 (Kubernetes Monitoring)
- [ ] Configurar home dashboard
- [ ] Alertas (CPU > 80%, Memory > 85%)

## Backlog (Priorizado)

### Fase 1 - Essencial (1-2 dias)
1. **GitHub Actions** - CI/CD workflows
   - Validar Terraform em PRs
   - Apply automático na main
   - Security scan (Trivy)

2. **Stern** - Logs em tempo real
   - Alternativa: usar `kubectl logs -f` temporariamente

3. **VPA** - Vertical Pod Autoscaler
   - Complementar HPA
   - Goldilocks recommendations

### Fase 2 - Segurança (2-3 dias)
1. **Trivy Operator** - Scan de vulnerabilidades
2. **OPA Gatekeeper** - Políticas de conformidade
3. **Pod Security Standards** - restricted mode

### Fase 3 - Produção (3-5 dias)
1. **Velero** - Backup e disaster recovery
2. **Ingress com TLS** - cert-manager + Let's Encrypt
3. **Longhorn** - CSI storage

### Fase 4 - Avançado (futuro)
1. **Service Mesh** - Linkerd (mais leve que Istio)
2. **Multi-cluster** - Kind múltiplo
3. **Cluster API** - Gerenciamento via CRDs

## Métricas de Sucesso

- [x] Zero downtime deployments
- [ ] < 5min recovery time (RTO)
- [ ] < 1h data loss (RPO)
- [x] > 90% resource utilization (HPA 70%)
- [ ] Security scan em todo PR
- [x] Auto-recovery de falhas (GitOps)

## Status Atual

```
Cluster: lab-sre-denoso (Kind v1.27.3)
Uptime: 17h+
Nodes: 1/1 Ready
Pods: 26/27 Running (96%)
Git: 91470e6 (main)
ArgoCD: GitOps validado
```

---

*Última atualização: 2026-05-12*  
*Próxima revisão: 2026-05-19*
