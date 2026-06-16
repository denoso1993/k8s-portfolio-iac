# bootstrap-windows.ps1 ? Configura netsh portproxy no Windows
# Uso: PowerShell como Admin:  .\bootstrap-windows.ps1

$ErrorActionPreference = "Stop"
$WSL_IP = "172.19.105.82"
$NODE_IP = "172.18.0.2"

Write-Host "=== Configurando netsh portproxy ==="

# Limpar rules antigas das portas que vamos gerenciar
$ports = @(80, 443, 5500, 5599, 5598, 3000, 8002, 8083, 5501)
foreach ($p in $ports) {
    netsh interface portproxy delete v4tov4 listenport=$p listenaddress=0.0.0.0 2>$null
    netsh interface portproxy delete v4tov4 listenport=$p listenaddress=127.0.0.1 2>$null
}

# Rules para trafego EXTERNO (0.0.0.0) - vai direto pro NodePort
$rules_ext = @(
    @{Port=80;    Dest=$WSL_IP; DestPort=8082},   # Ingress
    @{Port=443;   Dest=$WSL_IP; DestPort=443},    # Ingress HTTPS
    @{Port=5500;  Dest=$NODE_IP; DestPort=32286}, # Dev
    @{Port=5599;  Dest=$NODE_IP; DestPort=31807}, # Mobile PROD
    @{Port=5598;  Dest=$NODE_IP; DestPort=31804}, # Mobile DEV
    @{Port=3000;  Dest=$NODE_IP; DestPort=32039}, # Grafana
    @{Port=8002;  Dest=$WSL_IP; DestPort=8002},   # K8s API proxy
    @{Port=8083;  Dest=$NODE_IP; DestPort=31701}, # Nginx PROD
    @{Port=5501;  Dest=$WSL_IP; DestPort=5500}    # Dev (alt)
)

# Rules para LOOPBACK (127.0.0.1) - vai pro WSL (socat)
$rules_loop = @(
    @{Port=8083;  Dest=$WSL_IP; DestPort=8083},
    @{Port=5500;  Dest=$WSL_IP; DestPort=5500},
    @{Port=5599;  Dest=$WSL_IP; DestPort=5599},
    @{Port=5598;  Dest=$WSL_IP; DestPort=5598},
    @{Port=3000;  Dest=$WSL_IP; DestPort=3000}
)

foreach ($r in $rules_ext) {
    netsh interface portproxy add v4tov4 listenport=$($r.Port) listenaddress=0.0.0.0 connectport=$($r.DestPort) connectaddress=$($r.Dest)
    Write-Host "  0.0.0.0:$($r.Port) -> $($r.Dest):$($r.DestPort)"
}

foreach ($r in $rules_loop) {
    netsh interface portproxy add v4tov4 listenport=$($r.Port) listenaddress=127.0.0.1 connectport=$($r.DestPort) connectaddress=$($r.Dest)
    Write-Host "  127.0.0.1:$($r.Port) -> $($r.Dest):$($r.DestPort)"
}

Write-Host ""
Write-Host "=== Rules finais ==="
netsh interface portproxy show v4tov4

Write-Host ""
Write-Host "? bootstrap-windows.ps1 COMPLETO"
