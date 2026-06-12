# Ambientes do Cluster

## Mapa de Ambientes

| Ambiente | Porta | Pod | URL | Conteudo |
|----------|-------|-----|-----|----------|
| 🟢 **PROD** | **8083** | nginx | http://localhost:8083 | Portfolio Win95 (767KB) |
| 🟡 **DEV** | **5500** | dev-server | http://localhost:5500 | Espelhado do PROD para testes |
| 📱 **MOBILE** | **5599** | mobile-server | http://localhost:5599 | Versao mobile com wallpaper |
| 📊 **GRAFANA** | **3000** | grafana | http://localhost:3000 | Dashboard Cluster SRE |

## Observacoes Importantes

- **PROD (8083)**: Portfolio completo. NAO MEXER sem autorizacao.
- **DEV (5500)**: Espelha o conteudo do PROD. Usado para testes de funcionalidade antes de ir para producao.
- **MOBILE (5599)**: Versao mobile do portfolio com wallpaper. NAO MEXER, esta OK.
- **GRAFANA (3000)**: Dashboard Cluster SRE com metricas do cluster em tempo real (refresh 5s).
- **ArgoCD**: Credenciais admin / LpKFnTWLhKaZnEDj (senha obtida via secret)

## Como Espelhar PROD no DEV (se necessario)

```bash
kubectl get cm -n default nginx-html-config -o json | python3 -c \
  "import sys,json; d=json.load(sys.stdin); \
   open(chr(47)+chr(116)+chr(109)+chr(112)+chr(47)+chr(104)+chr(116)+chr(109)+chr(108)+chr(46)+chr(116)+chr(120)+chr(116),chr(119)).write(d[chr(100)+chr(97)+chr(116)+chr(97)][chr(105)+chr(110)+chr(100)+chr(101)+chr(120)+chr(46)+chr(104)+chr(116)+chr(109)+chr(108)])"
kubectl delete cm -n default dev-html-config --ignore-not-found
kubectl create cm -n default dev-html-config --from-file=index.html=/tmp/html.txt
kubectl delete pod -n default -l app=dev-server --force --grace-period=0
sleep 10
curl http://localhost:5500/
```

## Port-Forwards Gerenciados

```bash
8083 -> nginx-service:80           # PROD
5500 -> dev-server-service:5500    # DEV
5599 -> mobile-server-service:5599 # MOBILE
3000 -> grafana:80                 # GRAFANA (127.0.0.1 - restrito)
8001 -> kubectl proxy              # K8s API
```

## Netsh Portproxy (Windows-side)

```powershell
127.0.0.1:5501 -> WSL:5500  # DEV
127.0.0.1:5599 -> WSL:5599  # MOBILE
0.0.0.0:80     -> WSL:8082  # HTTP (Cloudflare)
0.0.0.0:443    -> WSL:443   # HTTPS (Cloudflare)
```
