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
   html = d['data']['index.html']; \
   open('/tmp/prod-index.html','w').write(html); \
   print('HTML extraido: ' + str(len(html)) + ' bytes')"

# 2. Atualizar o ConfigMap do DEV com o HTML do PROD
kubectl create cm mobile-html-config -n default \
  --from-file=index.html=/tmp/prod-index.html \
  --dry-run=client -o yaml | kubectl patch cm mobile-html-config -n default \
  --patch-file=/dev/stdin

# 3. Reiniciar o pod mobile-server para aplicar
kubectl rollout restart deployment mobile-server -n default
kubectl rollout status deployment mobile-server -n default --timeout=60s

# 4. Verificar
curl -s http://localhost:5599/ | head -c 200

## Port-Forwards Gerenciados

Os port-forwards sao mantidos pelo daemon (`scripts/portfolio-daemon.sh`):

| Servico | Porta Host | Namespace | Escopo | Comando |
|---------|-----------|-----------|--------|---------|
| Portfolio (PROD) | 8083 | default | 0.0.0.0 (publico) | `kubectl port-forward --address 0.0.0.0 svc/nginx-service 8083:80` |
| Grafana | 3000 | monitoring | 127.0.0.1 (localhost) | `kubectl port-forward --address 127.0.0.1 svc/grafana 3000:80` |
| Dev Server | 5500 | default | 0.0.0.0 (publico) | `kubectl port-forward --address 0.0.0.0 svc/dev-server-service 5500:5500` |
| Mobile (DEV) | 5599 | default | 0.0.0.0 (publico) | `kubectl port-forward --address 0.0.0.0 svc/mobile-server-service 5599:5599` |
| kubectl proxy | 8001 | system | 0.0.0.0 (pods/nodes) | `kubectl proxy --address=0.0.0.0 --port=8001` |

> O daemon verifica e recria os port-forwards a cada 15 segundos se necessario.

## Exposicao Externa (Cloudflare Tunnel)

O cluster utiliza Cloudflare Tunnel para exposicao HTTPS publica:

```bash
# O tunel redireciona:
# cloudflare.com:443  ->  localhost:8083  (PROD)
# cloudflare.com:443/grafana/  ->  localhost:3000  (Grafana)
```

O tunel e gerenciado pelo daemon e recriado automaticamente se cair.

## Netsh Portproxy (Windows)

O Windows utiliza `netsh interface portproxy` para encaminhar portas do host para o WSL:

| Porta Windows | Destino WSL | Servico |
|--------------|-------------|---------|
| 80 | :8082 | HTTP alternativo |
| 443 | :443 | HTTPS (Cloudflare) |
| 5501 | :5500 | Dev Server alternativo |
| 5599 | :5599 | Mobile (DEV) |

As regras sao recriadas ao executar `bootstrap/netsh-recreate.ps1` (necessario quando o IP do WSL muda).
