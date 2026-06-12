<# .SYNOPSIS Inicia todo o cluster #>
param([switch]$Force)
$logFile = "C:\wsl_bridge\logs\startup-$(Get-Date -Format yyyyMMdd).log"
function Log { param($msg) "$(Get-Date -Format HH:mm:ss) $msg" | Out-File -Path $logFile -Append; Write-Host $msg }
Log "=== INICIANDO CLUSTER ==="
Log "Aguardando Docker Desktop..."
$timeout = 120; $elapsed = 0
while ($elapsed -lt $timeout) {
    try { docker info 2>$null | Out-Null; Log "Docker OK"; break } catch {}
    Start-Sleep -Seconds 2; $elapsed += 2
}
Log "Aguardando WSL..."
wsl -d Ubuntu -e bash -c "echo ready" 2>$null; Log "WSL OK"
$clusterUp = wsl -d Ubuntu -e bash -c "kind get clusters 2>/dev/null | grep -q lab-sre-denoso && echo YES || echo NO" 2>$null
if ($clusterUp -ne "YES" -or $Force) {
    Log "Cluster nao encontrado. Recriando..."
    wsl -d Ubuntu -e bash -c "cd ~/k8s-portfolio-iac && bash scripts/ensure-cluster.sh" 2>&1 | ForEach-Object { Log "  $_" }
} else { Log "Cluster OK" }
Log "Iniciando daemon..."
wsl -d Ubuntu -e bash -c "cd ~/k8s-portfolio-iac && bash scripts/portfolio-daemon.sh > /dev/null 2>&1 &" 2>$null
Start-Sleep -Seconds 15
try { $r = Invoke-WebRequest -Uri "http://localhost:8083/" -UseBasicParsing -TimeoutSec 5; Log "Site: $($r.StatusCode)" }
catch { Log "ALERTA: Site nao respondeu" }
Log "=== STARTUP COMPLETO ==="
