<# .SYNOPSIS Verifica saude do cluster a cada 5 minutos #>
$logFile = "C:\wsl_bridge\logs\health-$(Get-Date -Format yyyyMMdd).log"
function Log { param($msg) "$(Get-Date -Format HH:mm:ss) $msg" | Out-File -Path $logFile -Append }
$checks = @(
    @{Name="Site (8083)"; Test={ try { (Invoke-WebRequest -Uri "http://localhost:8083/" -UseBasicParsing -TimeoutSec 5).StatusCode -eq 200 } catch { $false }}},
    @{Name="Grafana (3000)"; Test={ try { (Invoke-WebRequest -Uri "http://localhost:3000/api/health" -UseBasicParsing -TimeoutSec 5).StatusCode -eq 200 } catch { $false }}},
    @{Name="WSL Alive"; Test={ wsl -d Ubuntu -e bash -c "echo ok" 2>$null -eq "ok" }},
    @{Name="K8s API"; Test={ $r=wsl -d Ubuntu -e bash -c "kubectl version --short 2>/dev/null | grep -q Server" 2>$null; $LASTEXITCODE -eq 0 }})
$allOk = $true
foreach ($check in $checks) { $result = & $check.Test; if ($result) { Log "OK $($check.Name)" } else { Log "FAIL $($check.Name)"; $allOk = $false } }
if (-not $allOk) { Log "ALERTA: Recovery acionado!"; & "C:\wsl_bridge\start-cluster.ps1" -Force | Out-Null }
