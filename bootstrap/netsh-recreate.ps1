<# .SYNOPSIS Recria regras netsh portproxy com IP dinâmico do WSL #>
param([switch]$DryRun)
$logFile = "C:\wsl_bridge\logs\netsh-$(Get-Date -Format yyyyMMdd).log"
function Log { param($msg) "$(Get-Date -Format HH:mm:ss) $msg" | Out-File -Path $logFile -Append; if (-not $DryRun) { Write-Host $msg } }
try {
    $wslIp = (wsl -d Ubuntu -e hostname -I).Trim().Split()[0]
    Log "WSL IP detectado: $wslIp"
    if (-not $DryRun) {
        netsh interface portproxy reset
        Log "Regras antigas removidas"
        $ports = @( @{listen=80; connectport=8082}, @{listen=443; connectport=443}, @{listen=5501; connectport=5500}, @{listen=5599; connectport=5599} )
        foreach ($p in $ports) {
            netsh interface portproxy add v4tov4 listenport=$($p.listen) connectaddress=$wslIp connectport=$($p.connectport)
            Log "Regra $($p.listen) -> $wslIp:$($p.connectport)"
        }
        Log "netsh configurado com sucesso"
    }
} catch { Log "ERRO: $_"; exit 1 }
