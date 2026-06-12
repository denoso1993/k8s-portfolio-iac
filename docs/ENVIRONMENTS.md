# Ambientes do Cluster

## Mapa de Portas

| Ambiente | Porta | Service | Pod | URL |
|----------|-------|---------|-----|-----|
| 🟢 **PROD** | **8083** | nginx-service:80 | nginx-deployment | http://localhost:8083 |
| 🟡 **DEV** | **5599** | mobile-server-service:5599 | mobile-server | http://localhost:5599 |
| 📊 **GRAFANA** | **3000** | grafana:80 | grafana | http://localhost:3000 |

## Observações Importantes

- **PROD (8083)**: Portfolio Windows 95 completo. NÃO MEXER sem autorização.
- **DEV (5599)**: Espelha o conteúdo do PROD. Usado para testes de funcionalidade.
  - O conteúdo do DEV é copiado do PROD via ConfigMap `mobile-html-config`
  - O pod `mobile-server` serve o conteúdo via nginx na porta 8080 (traduzido para 5599 pelo service)
- **MOBILE**: Pod separado, não faz parte do ambiente DEV. Não mexer.
- **GRAFANA**: Dashboard Cluster SRE com métricas do cluster.

## Como Espelhar PROD no DEV (se necessário)

```bash
# 1. Extrair HTML do PROD
kubectl get cm -n default nginx-html-config -o json | python3 -c \
  "import sys,json; d=json.load(sys.stdin); \
   open(
