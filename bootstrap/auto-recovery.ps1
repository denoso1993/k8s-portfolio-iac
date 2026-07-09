# auto-recovery.ps1
param([string]$LogFile = "$env:USERPROFILE\portfolio-recovery.log")
$ErrorActionPreference = "Continue"
function Write-Log { param([string]$m)
    $t = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$t] $m"; Add-Content -Path $LogFile -Value "[$t] $m"
}
Write-Log "=== PORTFOLIO AUTO-RECOVERY ==="
$wslIP = $null
for ($i = 0; $i -lt 30; $i++) {
    try { $wslIP = wsl -d Ubuntu hostname -I 2>$null; if ($wslIP) { $wslIP = ($wslIP -split " ")[0]; break } } catch {}
    Start-Sleep 10
}
if (-not $wslIP) { Write-Log "ERRO: WSL IP"; exit 1 }
Write-Log "WSL IP: $wslIP"
wsl -d Ubuntu bash -c "bash /home/administrator/k8s-portfolio-iac/scripts/restore-all.sh 2>&1" | ForEach-Object { Write-Log "  $_" }
Start-Sleep 10
$ports = @(8002, 8083, 3000, 5500, 5599)
foreach ($port in $ports) {
    netsh interface portproxy delete v4tov4 listenport=$port listenaddress=0.0.0.0 2>$null
    netsh interface portproxy add v4tov4 listenport=$port listenaddress=0.0.0.0 connectport=$port connectaddress=$wslIP 2>$null
    Write-Log "Portproxy: $port -> $wslIP"
}
foreach ($t in @(@{Port=8083;Name="Site"},@{Port=3000;Name="Grafana"},@{Port=5500;Name="Dev"},@{Port=5599;Name="Mobile"})) {
    try { $r = Invoke-WebRequest -Uri "http://127.0.0.1:$($t.Port)" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop; Write-Log "OK: $($t.Name) HTTP $($r.StatusCode)" }
    catch { Write-Log "FAIL: $($t.Name)" }
}
Write-Log "=== RECOVERY FINALIZADO ==="