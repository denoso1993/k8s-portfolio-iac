# Auditoria Completa do Repositorio - 16/06/2026

## Escopo
Revisao total de ~85 arquivos: scripts, manifests, documentacao, infra as code.

---

## 1. CRITICO - Corrigir imediatamente

### 1.1 Credenciais vazadas
| Arquivo | Linha | Conteudo | Risco |
|---------|-------|----------|-------|
| docs/ENVIRONMENTS.md | 18 | admin / LpKFnTWLhKaZnEDj (ArgoCD) | Critico |
| archive/reports/RELATORIO-FINAL-2026-05-12.md | 30 | Senha: Denera1993 (root) | Critico |
| terraform/main.tf | 224 | POSTGRES_PASSWORD = sre_password_123 | Critico |
| terraform/main.tf | 157 | adminPassword = admin | Medio |
| k8s/monitoring/grafana-helm-values.yaml | 2 | adminPassword: admin | Medio |

### 1.2 IPs hardcoded que quebram no restart
| Arquivo | Linha | IP | Problema |
|---------|-------|----|----------|
| k8s/services/portfolio/nginx-secure.conf | 35 | 172.19.105.82:8001 | IP do WSL bridge muda |
| scripts/bootstrap-wsl.sh | 13-14 | 172.18.0.2:31701... | IP do Kind container muda |

### 1.3 Paths incorretos
| Arquivo | Path | Problema |
|---------|------|----------|
| scripts/cluster-check.sh | /home/denoso/ | Username incorreto (deveria ser administrator) |

---

## 2. ALTO - Precisa de atencao

### 2.1 Proxies inseguros (5 scripts)
Usam --accept-hosts=.* e --address=0.0.0.0:
- scripts/portfolio-daemon.sh (linhas 66, 109)
- scripts/daemon-watchdog.sh (linha 18)
- scripts/start-pfs-bridge.sh (linha 60)
- scripts/restore-all.sh (linha 29)

### 2.2 Port-forward legado
6 servicos em scripts/setup/pf-*.service - substituidos por socat.

### 2.3 Terraform duplicado
terraform/ + archive/terraform/ - 100% duplicados, deprecated no README.

### 2.4 Helm dumps enormes
~42.000+ linhas em 6 arquivos (argocd 16MB, cert-manager 3MB, ingress, prometheus, grafana, loki)

### 2.5 Network policy duplicada
k8s/security/network-policies/network-policy-nginx.yaml duplica allow-nginx.yaml + allow-postgres.yaml

---

## 3. MEDIO - Melhorias

### 3.1 CI/CD ausente
- Sem Makefile, sem GitHub Actions, sem Taskfile

### 3.2 Arquivos orfaos
- kind-config-v2.yaml, argocd-app-no-prune.yaml, pf-watchdog.sh

### 3.3 Codigo duplicado
- local-dev/dev-server.py e pyserver.py - mesmo proposito
- bootstrap-wsl.sh na raiz scripts/ e em scripts/setup/

### 3.4 Paths Windows hardcoded
- bootstrap/healthcheck.ps1, start-cluster.ps1, netsh-recreate.ps1 usam C:\wsl_bridge
### 3.5 YAMLs com metadados runtime
resourceVersion, uid, status nos manifests - poluem diff

---

## 4. ARQUITETURA - Proposta de reestruturacao

### Principio: TUDO no WSL, Windows so o essencial

WSL (100% do cluster + tooling):
- Kind cluster + K8s
- socat forwarders (via systemd)
- kubectl proxy seguro (--accept-hosts=localhost)
- Scripts de bootstrap/manutencao
- Git operations

Windows (so o minimo):
- netsh portproxy (loopback para cloudflared)
- cloudflared tunnel
- Scheduled tasks (startup do cluster)

---

## 5. PROXIMOS PASSOS (Forca-Tarefa)

### Fase 1 - Seguranca (1h)
- Remover credenciais vazadas dos docs
- Corrigir IP hardcoded no nginx-secure.conf
- Corrigir path no cluster-check.sh
- Substituir proxies inseguros (5 scripts)

### Fase 2 - Limpeza (30min)
- Deletar pf-*.service legados
- Deletar terraform/ + archive/terraform/
- Deletar arquivos orfaos
- Consolidar bootstrap-wsl.sh

### Fase 3 - Estrutura (2h)
- Criar Makefile com targets: cluster, deploy, clean, test, lint
- Substituir Helm dumps por valores + template
- Remover metadados runtime dos YAMLs
- Consolidar local-dev/

### Fase 4 - CI/CD (2h)
- Criar GitHub Actions workflow: lint, test, deploy
- Adicionar security scan (gitleaks)

---

## Estatisticas
| Categoria | Qtde |
|-----------|------|
| Total arquivos | ~85 |
| Shell scripts | 23 |
| PowerShell | 5 |
| YAML manifests | 30+ |
| Documentos | 13 |
| Python | 4 |
