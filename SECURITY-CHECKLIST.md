# Security Checklist — Repositorio PUBLICO

> ⚠️ **Este repositorio e PUBLICO.** Tudo que esta aqui pode ser visto por qualquer pessoa na internet.

## ❌ NUNCA commitar neste repositorio

| Item | Exemplo | Risco |
|------|---------|-------|
| Tokens de API | `ghp_...`, `sk-...` | Acesso total a servicos |
| Senhas | `POSTGRES_PASSWORD=123` | Banco de dados exposto |
| Chaves SSH | `-----BEGIN OPENSSH PRIVATE KEY-----` | Acesso a servidores |
| Certificados TLS | `-----BEGIN CERTIFICATE-----` | Identidade comprometida |
| IPs internos fixos | `172.19.105.82` | Mapeamento de rede |
| Dados pessoais | Nomes, emails, telefones | LGPD/GPDR |

## ✅ O que pode ir no repositorio

| Item | Exemplo |
|------|---------|
| Manifests Kubernetes | `deployment.yaml`, `service.yaml` |
| Scripts de bootstrap | `bootstrap-wsl.sh` |
| Documentacao tecnica | `docs/ARCHITECTURE.md` |
| Dashboards Grafana | JSON exports |
| Helm values (sem senhas) | `values.yaml` |
| Makefile | Comandos de automacao |

## 🔒 Onde guardar segredos

- **Tokens GitHub**: Windows Credential Manager (`credential.helper manager`)
- **Senhas Kubernetes**: `kubectl create secret generic`
- **Token Cloudflare**: `/etc/cloudflared-token` (fora do repo)
- **API keys**: Variaveis de ambiente locais (`.env` no `.gitignore`)

## ✅ Pre-commit check rapido

```bash
# Verificar credenciais no diff antes de commitar
git diff --cached | grep -iE 'ghp_|sk-|api_key|password|secret|token' && echo "⚠️  CREDENCIAL DETECTADA!"
git diff --cached | grep -E '^[[:space:]]+(172\.|10\.|192\.168\.)' && echo "⚠️  IP INTERNO DETECTADO!"
```

> **Regra de ouro:** Se voce nao colocaria num post do LinkedIn, nao coloque aqui.
