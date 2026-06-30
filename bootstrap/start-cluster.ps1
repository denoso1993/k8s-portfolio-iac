<# .SYNOPSIS Inicia todo o cluster via sistema systemd do WSL #>
param([switch]$Force)
$logFile = "C:\wsl_bridge\logs\startup-$(Get-Date -Format yyyyMMdd).log"
function Log { param($msg) "$(Get-Date -Format HH:mm:ss) $msg" | Out-File -Path $logFile -Append; Write-Host $msg }
Log "=== INICIANDO CLUSTER ==="
Log "Aguardando Docker Engine..."
$timeout = 120; $elapsed = 0
while ($elapsed -lt $timeout) {
    try { docker info 2>$null | Out-Null; Log "Docker OK"; break } catch {}
    Start-Sleep -Seconds 2; $elapsed += 2
}
Log "Aguardando WSL..."
wsl -d Ubuntu -e bash -c 'echo ready' 2>$null; Log "WSL OK"
Log "Iniciando cluster.target via systemd..."
wsl -d Ubuntu -e bash -c 'sudo systemctl start cluster.target' 2>&1 | ForEach-Object { Log "  $_" }
Log "Aguardando recovery..."
Start-Sleep -Seconds 30
try { $r = Invoke-WebRequest -Uri 'http://localhost:8083/' -UseBasicParsing -TimeoutSec 10; Log "Site: $($r.StatusCode)" }
catch { Log "ALERTA: Site nao respondeu - $($_.Exception.Message)" }
try { $g = Invoke-WebRequest -Uri 'http://localhost:3000/' -UseBasicParsing -TimeoutSec 10; Log "Grafana: $($g.StatusCode)" }
catch { Log "ALERTA: Grafana nao respondeu - $($_.Exception.Message)" }
Log "=== STARTUP COMPLETO ==="
