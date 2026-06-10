# Analise de Seguranca - Portfolio Cluster

## Data: 10/06/2026 (atualizado)
## Ambiente: Kind (WSL2) + Cloudflare Tunnel

---

## 1. RESUMO EXECUTIVO

| Nivel | Encontrados | Corrigidos | Status |
|-------|-------------|------------|--------|
| ?? Critico | 2 | 2 | ? RESOLVIDO |
| ?? Alto | 3 | 3 | ? RESOLVIDO |
| ?? Medio | 3 | 1 | ?? Parcial |
| ?? Baixo | 4 | 0 | ? OK (monitorado) |

---

## 2. ?? CRITICO - RESOLVIDOS

### 2.1 Kubectl Proxy - RESTRITO
**Antes:** `--accept-hosts=.*` (qualquer host, qualquer path)
**Depois:** `--accept-hosts=localhost` + `--accept-paths=^/api/v1/(pods|nodes)(/|$)$`

Apenas endpoints de pods e nodes sao acessiveis via proxy. Secrets, configmaps e outros recursos estao bloqueados (HTTP 403 Forbidden).

### 2.2 Grafana - LOCALHOST APENAS
**Antes:** `--address 0.0.0.0` (acessivel na rede)
**Depois:** `--address 127.0.0.1` (apenas localhost)

---

## 3. ?? ALTO - RESOLVIDOS

### 3.1 Security Headers (nginx + HTML)
Headers implementados no nginx.conf e via meta tags no HTML:

| Header | Valor | Onde |
|--------|-------|------|
| `Content-Security-Policy` | default-src 'self'; frame-src https://grafana.denisdeoliveira.com.br; connect-src 'self' /k8s/ | HTML meta tag |
| `X-Frame-Options` | DENY | nginx + HTML |
| `X-Content-Type-Options` | nosniff | nginx + HTML |
| `Referrer-Policy` | no-referrer-when-downgrade | nginx + HTML |
| `Permissions-Policy` | geolocation=(), microphone=(), camera=() | nginx |

### 3.2 Network Policies
Tres politicas aplicadas no namespace default:

| Policy | Funcao |
|--------|--------|
| `default-deny-ingress` | Bloqueia todo trafego de entrada por padrao |
| `allow-nginx` | Permite trafego na porta 8080 para pods nginx |
| `allow-postgres` | Permite trafego na porta 5432 para pods postgres (apenas de pods nginx) |

### 3.3 nginx proxy Host header
**Antes:** `proxy_set_header Host $host;` (envia o host original)
**Depois:** `proxy_set_header Host localhost;` (forca localhost para o kubectl proxy)

---

## 4. ?? MEDIO - PARCIAL

| Item | Status |
|------|--------|
| Pod Security Standards (PSS) | ? Nao configurado (requer cluster com suporte a PSS nativo) |
| Kyverno politicas | ?? Removidas (estavam em modo audit apenas) |
| NodePort 30080 exposto | ?? Mantido para compatibilidade com ingress-nginx |

---

## 5. ?? BAIXO - OK

| Item | Status |
|------|--------|
| Containers non-root | ? nginx (user 101), postgres (user 70) |
| Capabilities drop ALL | ? nginx e postgres |
| Resource quotas | ? default: max 20 pods, 4 CPU, 4GB RAM |
| TLS via Cloudflare | ? HTTPS ativo |
| Secrets em K8s secrets | ? Nada hardcoded |
| LimitRange | ? Container padrao: 100m CPU / 128MB RAM |
| PostgreSQL StatefulSet com PVC | ? 1GB persistente |

---

## 6. ARQUIVOS DE SEGURANCA NO REPO

| Arquivo | Descricao |
|---------|-----------|
| `k8s/services/portfolio/nginx-secure.conf` | Config do nginx com security headers |
| `k8s/security/network-policies/default-deny.yaml` | NetworkPolicy: bloqueio total ingress |
| `k8s/security/network-policies/allow-nginx.yaml` | NetworkPolicy: libera nginx:8080 |
| `k8s/security/network-policies/allow-postgres.yaml` | NetworkPolicy: libera postgres:5432 |
| `scripts/monitor.sh` | Monitor com configuracoes seguras |
| `scripts/start-cluster.sh` | Startup com configuracoes seguras |
| `SECURITY.md` | Este documento |

---

## 7. RECOMENDACOES FUTURAS

1. Configurar Pod Security Standards (K8s 1.27+ suporta nativo)
2. Reativar Kyverno com politicas uteis (disallow-privileged, require-resources)
3. Adicionar HSTS no Cloudflare (painel Cloudflare > SSL/TLS > Edge Certificates)
4. Rodar `kubectl proxy` via systemd ao inves de nohup
5. Configurar auditoria de logs do Kubernetes
