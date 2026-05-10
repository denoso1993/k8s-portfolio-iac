# WSL Bridge - Contexto e Arquitetura

## Visao Geral

Projeto usa arquitetura hibrida Windows/WSL:
- Windows: C:\wsl_bridge\ - Scripts PowerShell
- WSL: /home/denoso/projeto-lab-sre/ - Terraform e Kubernetes
- Ponte: TCP localhost:5555

## Arquivos

### Windows (C:\wsl_bridge\)
- wsl_agent.ps1 - Cliente PowerShell
- stress_final.ps1 - Stress teste
- validate_security.ps1 - Validacao

### WSL (/home/denoso/projeto-lab-sre/)
- main.tf - Terraform principal
- security.tf - Seguranca (ResourceQuota, LimitRange, NetworkPolicy)
- hpa-nginx.yaml - HPA config (70% CPU)
- deployment-nginx.yaml - Nginx deployment

## Git
- URL: https://github.com/denoso1993/k8s-portfolio-iac
- SEMPRE: git add . && git commit -m msg && git push

## Seguranca (2026-05-10)
- ResourceQuota: CPU 4/8 cores, Memory 4Gi/8Gi
- LimitRange: CPU 500m, Memory 512Mi
- NetworkPolicies: default-deny, allow-dns, nginx-allow
- HPA: 70% CPU target, 1-5 replicas
