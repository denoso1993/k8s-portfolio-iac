# RSO Operational Memory - k8s-portfolio-iac

## Last Session
- Date: 2026-06-05 13:59
- Focus: Cluster audit, critical fixes, git sync to GitHub
- Completed:
  - Comprehensive cluster audit (docs/CLUSTER_AUDIT.md)
  - Installed metrics-server v0.8.1 (--kubelet-insecure-tls, --cert-dir=/tmp, --secure-port=10250)
  - Fixed HPA (now shows 0%/70%)
  - Fixed ApplicationSet CRD (controller was in CrashLoopBackOff)
  - Removed duplicate TLS certificate (ingress annotation conflict)
  - Initialized git repo and pushed to denoso1993/k8s-portfolio-iac (commit d553a90)
- Next: Phase 2 improvements (PSS, ResourceQuota, Kyverno)

## Active Issues
| Issue | Status | Priority |
|-------|--------|----------|
| HPA not working | Fixed | P0 |
| ApplicationSet crashing | Fixed | P0 |
| Duplicate cert | Fixed | P0 |
| Git repo disconnected | Fixed | P0 |
| No Ingress Controller | Pending | P1 |
| No PSS labels | Pending | P1 |
| No ResourceQuota | Pending | P1 |
