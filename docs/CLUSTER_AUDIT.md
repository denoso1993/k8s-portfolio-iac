# Cluster Audit Report - lab-sre-denoso

**Date:** 2026-06-05
**Auditor:** RSO
**Cluster:** Kind lab-sre-denoso (K8s v1.27.3, single node)

---

## 1. SUMMARY

| Category | Status |
|----------|--------|
| Nodes | OK - 1 control-plane (16 vCPU, 16Gi RAM) |
| Workloads | 29 pods, 28 Running, 1 CrashLoopBackOff |
| Monitoring | OK - Prometheus + Grafana + Loki |
| GitOps | WARN - ArgoCD installed, ApplicationSet crashing |
| Certs | WARN - Duplicate cert pointing to same secret |
| Storage | WARN - 1 PVC Pending (expected) |
| Autoscaling | FAIL - HPA broken (no metrics-server) |
| Security | FAIL - No PSS labels, no ResourceQuota |
| Ingress | WARN - Resource defined but no Controller |

## 2. CRITICAL ISSUES

### 2.1 HPA Not Functioning
- HPA shows <unknown>/70%
- Root cause: metrics-server not installed
- Fix: Install metrics-server

### 2.2 ArgoCD ApplicationSet CrashLoopBackOff
- Error: no matches for kind ApplicationSet
- Root cause: ApplicationSet CRD not registered
- Fix: Install ApplicationSet CRD or disable controller

### 2.3 Duplicate TLS Certificate
- Two Certificate resources write to same nginx-tls-secret
- Fix: Remove duplicate cert

## 3. ROADMAP

### Phase 1 - Critical (P0)
1. Install metrics-server
2. Fix ApplicationSet CRD
3. Fix duplicate cert
4. Init git + push to GitHub

### Phase 2 - Security (P1)
5. PSS labels
6. ResourceQuota + LimitRange
7. Kyverno

### Phase 3 - Availability (P1)
8. nginx-ingress-controller
9. MetalLB

### Phase 4 - Observability (P2)
10. PrometheusRule alerts
11. Grafana K8s dashboards

### Phase 5 - GitOps (P2)
12. Wire ArgoCD to GitHub
13. Keda

