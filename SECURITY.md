# Analise de Seguranca - Portfolio Cluster

## Data: 10/06/2026
## Ambiente: Kind (WSL2) + Cloudflare Tunnel

---

## 1. RESUMO EXECUTIVO

| Nivel | Qtd | Acoes Recomendadas |
|-------|-----|--------------------|
| ?? Critico | 2 | Kubectl proxy exposto + Grafana admin:admin |
| ?? Alto | 3 | NetworkPolicies ausentes, Ingress travado, CSP ausente |
| ?? Medio | 3 | PSS nao configurado, Kyverno vazio, NodePort exposto |
| ?? Baixo | 4 | Containers non-root, TLS ok, quotas ok |

---

## 2. ?? CRITICO

### 2.1 Kubectl Proxy sem autenticacao
**Severidade: CRITICA** | **Porta: 8001**

O `kubectl proxy` esta rodando com:
- `--address=0.0.0.0` (acessivel de qualquer lugar na rede)
- `--accept-hosts=.*` (aceita qualquer host)
- **SEM autenticacao** - qualquer requisicao GET tem acesso total a API do K8s

Isso significa que QUALQUER processo/container na mesma rede pode listar secrets, criar pods, etc.

**Risco:** Alguem no mesmo Wi-Fi (se a porta estiver exposta) ou um container malicioso dentro do cluster pode executar `curl http://host:8001/api/v1/secrets` e obter todos os secrets.

**Correcao imediata:**
- Adicionar `--accept-paths=^/api/v1/pods,^/api/v1/nodes` para limitar os paths permitidos
- OU rodar com `--bind-address=127.0.0.1` ao inves de 0.0.0.0
- OU usar `kubectl proxy --port=8001` sem `--address=0.0.0.0`

### 2.2 Grafana - credencial admin:admin ativa
**Severidade: CRITICA** | **Porta: 3000**

O Grafana aceita login com `admin:admin`. Embora a senha real esteja num secret K8s, a credencial padrao ainda funciona. Qualquer um com acesso a porta 3000 pode acessar o dashboard.

**Risco:** Vazamento de metricas do cluster, acesso a dados de monitoramento.

**Correcao:**
- Desabilitar o login admin:admin apos configurar a senha real
- OU restringir acesso a porta 3000 apenas para localhost (`--address=127.0.0.1`)

---

## 3. ?? ALTO

### 3.1 Network Policies ausentes
**Severidade: ALTA**

Nenhuma NetworkPolicy foi encontrada em nenhum namespace. Isso significa que qualquer pod pode se comunicar com qualquer outro pod, sem restricoes.

**Correcao:**
- Aplicar default-deny em namespaces criticalos (default, monitoring)
- Permitir apenas trafego necessario (nginx:8080 para o mundo, postgres:5432 apenas para quem precisa, etc.)

### 3.2 HTML sem headers de seguranca
**Severidade: ALTA**

O site nao possui:
- `Content-Security-Policy` (CSP) - risco de XSS
- `X-Frame-Options` - risco de clickjacking
- `X-Content-Type-Options` - risco de MIME sniffing
- `Referrer-Policy`

**Correcao:**
- Adicionar no nginx.conf headers de seguranca
- Adicionar CSP no HTML via meta tag

### 3.3 Ingress-nginx travado ha 25h
**Severidade: ALTA**

O ingress-nginx controller esta em `ContainerCreating` ha mais de 25h. O roteamento HTTP/HTTPS externo via ingress nao esta funcional.

**Impacto:** O site so funciona via port-forward (localhost:8083), nao via ingress. O Cloudflare Tunnel esta apontando para a porta exposta.

---

## 4. ?? MEDIO

### 4.1 Pod Security Standards (PSS) nao configurados
Nenhum namespace possui PSS enforce. Em ambientes reais, pelo menos `restricted` ou `baseline` deveriam ser aplicados.

### 4.2 Kyverno sem politicas ativas
As politicas Kyverno que existiam (disallow-privileged, require-resources) nao estao sendo aplicadas.

### 4.3 NodePort 30080 exposto
O ingress-nginx expoe NodePort 30080 (HTTP) e 30443 (HTTPS) que podem ser acessados diretamente pelo IP do host.

---

## 5. ?? BAIXO (OK)

| Item | Status |
|------|--------|
| Containers non-root | ? nginx (user 101), postgres (user 70) |
| Capabilities drop ALL | ? nginx e postgres |
| Resource quotas configurados | ? default namespace (max 20 pods, 4 CPU, 4GB RAM) |
| TLS via Cloudflare | ? HTTPS funcional, certificado valido |
| Secrets armazenados (nao hardcoded) | ? Grafana e PostgreSQL usam secrets K8s |
| LimitRange configurado | ? Container padrao: 100m CPU / 128MB RAM |
| PostgreSQL StatefulSet com PVC | ? 1GB persistente |

---

## 6. RECOMENDACOES PRIORITARIAS

### Imediato (fazer agora):
1. [ ] **kubectl proxy**: trocar `--address=0.0.0.0` para `--address=127.0.0.1` OU adicionar `--accept-paths=^/api/v1/(pods|nodes)`
2. [ ] **HTML**: adicionar meta tag CSP no cabecalho do site
3. [ ] **Grafana**: mudar `--address 0.0.0.0` para `--address 127.0.0.1`

### Curto prazo (essa semana):
4. [ ] Network Policies: aplicar default-deny + regras especificas
5. [ ] Consertar ingress-nginx controller
6. [ ] Remover ou proteger NodePort 30080

### Medio prazo:
7. [ ] Configurar Pod Security Standards (pelo menos baseline)
8. [ ] Reativar Kyverno com politicas uteis
9. [ ] Adicionar HSTS via Cloudflare
10. [ ] Rodar `kubectl proxy` via monitor.sh com auto-restart
