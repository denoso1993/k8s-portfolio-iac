# Disaster Recovery Runbook

## Cenarios de Recuperacao

---

### Cenario 1: WSL2 / Docker Desktop crash

**Sintomas:** Cluster inacessivel, `kind get clusters` retorna vazio, Docker Desktop com icone vermelho.

**Recuperacao:**
1. Abrir Docker Desktop e aguardar "Engine Running"
2. Abrir terminal WSL (Ubuntu)
3. Executar:
   ```bash
   bash /home/administrator/k8s-portfolio-iac/scripts/ensure-cluster.sh
   ```
4. Aguardar ~2 minutos. O script:
   - Recria o cluster Kind (se deletado)
   - Reaplica os manifests
   - Reinicia kubectl proxy, port-forwards e daemon
5. Verificar: http://localhost:8083

**Prevencao:** O Scheduled Task `Portfolio-Daemon` (Windows) executa `ensure-cluster.sh` na inicializacao do PC.

---

### Cenario 2: Perda de dados do PostgreSQL

**Sintomas:** Postgres nao inicia, dados corrompidos, `kubectl logs postgres-sts-0` mostra erro de startup.

**Recuperacao:**
1. Verificar backups disponiveis:
   ```bash
   ls -la /home/administrator/k8s-portfolio-iac/backups/
   ```
2. Se houver backup:
   ```bash
   kubectl cp backups/portfolio-2026-xx-xx.sql default/postgres-sts-0:/tmp/restore.sql
   kubectl exec -n default postgres-sts-0 -- psql -U postgres -f /tmp/restore.sql
   ```
3. Se nao houver backup:
   - O banco e recriado vazio pelo StatefulSet
   - Dados anteriores foram perdidos permanentemente

**Prevencao:** O script `scripts/backup-postgres.sh` deve ser executado periodicamente (recomendado: diario via cron ou Scheduled Task).

---

### Cenario 3: Cloudflare Tunnel offline

**Sintomas:** Site inacessivel via denisdeoliveira.com.br, mas acessivel via http://localhost:8083

**Recuperacao:**
1. Verificar processo cloudflared:
   ```powershell
   Get-Process -Name cloudflared
   ```
2. Se parado, reiniciar manualmente:
   ```powershell
   Start-Process "C:\Program Files (x86)\cloudflared\cloudflared.exe" -ArgumentList "tunnel run --token SEU_TOKEN"
   ```
3. Ou aguardar o Scheduled Task `Portfolio-CloudflareTunnel` reiniciar (executa no logon)

**Prevencao:** Scheduled Task `Portfolio-CloudflareTunnel` configurado para iniciar automaticamente no logon do Windows.

---

### Cenario 4: Perda total (WSL + Docker + Windows restart)

**Sintomas:** Tudo parou. PC foi desligado.

**Recuperacao:**
1. Ligar o PC e fazer login no Windows
2. O Scheduled Task `Portfolio-CloudflareTunnel` inicia o tunnel automaticamente
3. O Scheduled Task `Portfolio-Daemon` (Startup) executa:
   ```bash
   bash /home/administrator/k8s-portfolio-iac/scripts/ensure-cluster.sh
   ```
4. Aguardar ~3 minutos para o cluster subir completamente
5. Verificar: https://denisdeoliveira.com.br

**NOTA:** O cluster Kind e efemero (volumes desaparecem com o cluster). Apenas dados no PostgreSQL com PVC persistem entre recreacoes do cluster.

---

### Cenario 5: NodePort 30080 exposto (scan detectado)

**Sintomas:** Scanner de rede encontra porta 30080 aberta no host.

**Acao:**
```powershell
# Bloquear a porta no firewall do Windows
New-NetFirewallRule -DisplayName "Block NodePort 30080" -Direction Inbound -LocalPort 30080 -Protocol TCP -Action Block
```

---

## Arquivos de Recuperacao

| Script | Funcao |
|--------|--------|
| `scripts/ensure-cluster.sh` | Garante cluster + proxy + port-forwards + daemon rodando |
| `scripts/portfolio-daemon.sh` | Monitor cont?nuo (loop 30s, reanima servicos) |
| `scripts/start-cluster.sh` | Startup inicial (usado internamente pelo daemon) |
| `scripts/backup-postgres.sh` | Backup do PostgreSQL para /backups/ |
| `RESTORE.md` | Restauracao dos manifests do Git para o cluster |

## Logs uteis

| Log | Localizacao |
|-----|-------------|
| Daemon monitor | `/tmp/portfolio-monitor.log` (WSL) |
| Kubectl proxy | `/tmp/kubectl-proxy.log` (WSL) |
| Port-forward nginx | `/tmp/port-forward-nginx.log` (WSL) |
| Port-forward grafana | `/tmp/port-forward-grafana.log` (WSL) |
| Ensure cluster | `/tmp/ensure-cluster.log` (WSL) |
| Cloudflare tunnel | Windows Event Viewer ou task manager |
