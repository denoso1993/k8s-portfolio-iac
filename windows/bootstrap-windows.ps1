<#
.SYNOPSIS
  PONTO DE ENTRADA ÚNICO — Bootstrap completo do Windows para k8s-portfolio-iac.
  Consolida: git setup, netsh portproxy, scheduled task, firewall, WSL + Docker.

.DESCRIPTION
  Este script deve ser executado como Administrador em uma máquina Windows NOVA.
  Ele configura todo o ambiente Windows necessário para rodar o cluster Kubernetes
  via WSL + Docker Engine + Kind.

  Etapas:
    1. Git — configura identidade, credential helper, clona repositórios
    2. Netsh PortProxy — detecta IPs dinâmicos (WSL + Kind) e cria regras
    3. Scheduled Task — auto-start do cluster no logon
    4. Firewall — libera portas de inbound
    5. WSL + Docker — instruções e validação

.NOTES
  Autor    : denoso1993
  Requisito: PowerShell como Administrador
  Versão   : 2.0 (consolidado W7)
#>

#requires -RunAsAdministrator
$ErrorActionPreference = "Stop"
$START_TIME = Get-Date

# ──────────────────────────────────────────────
# CONFIGURAÇÕES
# ──────────────────────────────────────────────
$PROJECT_ROOT = Split-Path -Parent $PSScriptRoot
$WINDOWS_DIR  = $PSScriptRoot
$SETUP_GIT    = Join-Path $WINDOWS_DIR "setup-git.ps1"

# Portas gerenciadas pelo portproxy
$PORTS = @(80, 443, 5500, 5599, 5598, 3000, 8002, 8083, 5501)

# ──────────────────────────────────────────────
# FUNÇÕES AUXILIARES
# ──────────────────────────────────────────────

function Write-Step {
    param([string]$Title, [string]$Status = "⏳")
    Write-Host ""
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
    Write-Host " $Status $Title" -ForegroundColor Cyan
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
}

function Write-OK {
    param([string]$Msg)
    Write-Host "  ✅ $Msg" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Msg)
    Write-Host "  ⚠️  $Msg" -ForegroundColor Yellow
}

function Write-Err {
    param([string]$Msg)
    Write-Host "  ❌ $Msg" -ForegroundColor Red
}

function Test-Admin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Err "Este script requer privilégios de Administrador!"
        Write-Host "  Execute como: PowerShell (Admin) e tente novamente." -ForegroundColor Yellow
        exit 1
    }
}

# ──────────────────────────────────────────────
# FUNÇÃO: HealthCheck
# ──────────────────────────────────────────────
function Invoke-HealthCheck {
    <#
    .SYNOPSIS
      Verifica saude dos servicos do portfolio.
    #>
    param([string]$LogFile = "$env:TEMP\portfolio-health-$(Get-Date -Format yyyyMMdd).log")

    function Log { param($msg) "$(Get-Date -Format HH:mm:ss) $msg" | Out-File -Path $LogFile -Append }
    Write-Host "  Executando health check..." -ForegroundColor Gray

    $checks = @(
        @{Name="Site (8083)"; Test={ try { (Invoke-WebRequest -Uri "http://localhost:8083/" -UseBasicParsing -TimeoutSec 5).StatusCode -eq 200 } catch { $false }}}
        @{Name="Grafana (3000)"; Test={ try { (Invoke-WebRequest -Uri "http://localhost:3000/api/health" -UseBasicParsing -TimeoutSec 5).StatusCode -eq 200 } catch { $false }}}
        @{Name="WSL Alive"; Test={ wsl -d Ubuntu -e bash -c "echo ok" 2>$null -eq "ok" }}
        @{Name="K8s API"; Test={ $r=wsl -d Ubuntu -e bash -c "kubectl version --short 2>/dev/null | grep -q Server" 2>$null; $LASTEXITCODE -eq 0 }}
    )

    $allOk = $true
    foreach ($check in $checks) {
        $result = & $check.Test
        if ($result) {
            Log "OK $($check.Name)"
        } else {
            Log "FAIL $($check.Name)"
            Write-Warn "Health: $($check.Name) FALHOU"
            $allOk = $false
        }
    }
    if ($allOk) {
        Write-OK "Health check: tudo OK"
    } else {
        Write-Warn "Health check: algumas falhas (veja $LogFile)"
    }
    return $allOk
}

# ──────────────────────────────────────────────
# FUNÇÃO: Start-Cluster
# ──────────────────────────────────────────────
function Start-PortfolioCluster {
    <#
    .SYNOPSIS
      Inicia todo o cluster (Docker + WSL + Kind + Daemon).
    #>
    param([switch]$Force)
    $logFile = "$env:TEMP\portfolio-startup-$(Get-Date -Format yyyyMMdd).log"

    function Log { param($msg) "$(Get-Date -Format HH:mm:ss) $msg" | Out-File -Path $logFile -Append; Write-Host "  $msg" -ForegroundColor Gray }

    Write-Host "  Aguardando Docker Engine..." -ForegroundColor Gray
    $timeout = 120; $elapsed = 0
    while ($elapsed -lt $timeout) {
        try { docker info 2>$null | Out-Null; Log "Docker OK"; break } catch {}
        Start-Sleep -Seconds 2; $elapsed += 2
    }

    Log "Aguardando WSL..."
    wsl -d Ubuntu -e bash -c "echo ready" 2>$null
    Log "WSL OK"

    $clusterUp = wsl -d Ubuntu -e bash -c "kind get clusters 2>/dev/null | grep -q lab-sre-denoso && echo YES || echo NO" 2>$null
    if ($clusterUp -ne "YES" -or $Force) {
        Log "Cluster nao encontrado. Recriando..."
        wsl -d Ubuntu -e bash -c "cd ~/k8s-portfolio-iac && bash scripts/ensure-cluster.sh" 2>&1 | ForEach-Object { Log "  $_" }
    } else {
        Log "Cluster OK"
    }

    Log "Iniciando daemon..."
    wsl -d Ubuntu -e bash -c "cd ~/k8s-portfolio-iac && bash scripts/portfolio-daemon.sh > /dev/null 2>&1 &" 2>$null
    Start-Sleep -Seconds 15

    try {
        $r = Invoke-WebRequest -Uri "http://localhost:8083/" -UseBasicParsing -TimeoutSec 5
        Log "Site: $($r.StatusCode)"
    } catch {
        Log "ALERTA: Site nao respondeu"
    }
    Log "=== STARTUP COMPLETO ==="
}

# ──────────────────────────────────────────────
# FUNÇÃO: Setup-NetshPortProxy
# ──────────────────────────────────────────────
function Setup-NetshPortProxy {
    <#
    .SYNOPSIS
      Configura netsh portproxy com detecção dinâmica de IPs (WSL + Kind).
    #>
    Write-Step "Netsh PortProxy" "🔄"

    # Detectar IP do WSL dinamicamente
    Write-Host "  Detectando IP do WSL..." -ForegroundColor Gray
    $WSL_IP = wsl -- hostname -I 2>$null | ForEach-Object { $_.Trim() }
    if (-not $WSL_IP) {
        $WSL_IP = wsl -d Ubuntu -- ip addr show eth0 2>$null | Select-String -Pattern 'inet\s+(\d+\.\d+\.\d+\.\d+)' | ForEach-Object { $_.Matches.Groups[1].Value }
    }
    if (-not $WSL_IP) {
        Write-Err "Não foi possível detectar o IP do WSL"
        Write-Warn "Execute 'wsl -- hostname -I' manualmente e edite este script"
        return $false
    }
    Write-OK "WSL IP detectado: $WSL_IP"

    # Detectar IP do nó Kind dinamicamente
    Write-Host "  Detectando IP do nó Kind..." -ForegroundColor Gray
    $NODE_IP = wsl -d Ubuntu -- docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' lab-sre-denoso-control-plane 2>$null
    if (-not $NODE_IP) {
        $NODE_IP = wsl -d Ubuntu -- kubectl get node lab-sre-denoso-control-plane -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}' 2>$null
    }
    if (-not $NODE_IP) {
        Write-Warn "Não foi possível detectar o IP do nó Kind. Usando WSL_IP como fallback."
        $NODE_IP = $WSL_IP
    }
    Write-OK "Node IP detectado: $NODE_IP"

    # Limpar rules antigas
    Write-Host "  Limpando regras antigas..." -ForegroundColor Gray
    foreach ($p in $PORTS) {
        netsh interface portproxy delete v4tov4 listenport=$p listenaddress=0.0.0.0 2>$null
        netsh interface portproxy delete v4tov4 listenport=$p listenaddress=127.0.0.1 2>$null
    }

    # Rules para tráfego EXTERNO (0.0.0.0) → NodePort
    $rules_ext = @(
        @{Port=80;    Dest=$WSL_IP;  DestPort=8082}   # Ingress
        @{Port=443;   Dest=$WSL_IP;  DestPort=443}    # Ingress HTTPS
        @{Port=5500;  Dest=$NODE_IP; DestPort=32286}  # Dev
        @{Port=5599;  Dest=$NODE_IP; DestPort=31807}  # Mobile PROD
        @{Port=5598;  Dest=$NODE_IP; DestPort=31804}  # Mobile DEV
        @{Port=3000;  Dest=$NODE_IP; DestPort=32039}  # Grafana
        @{Port=8002;  Dest=$WSL_IP;  DestPort=8002}   # K8s API proxy
        @{Port=8083;  Dest=$NODE_IP; DestPort=31701}  # Nginx PROD
        @{Port=5501;  Dest=$WSL_IP;  DestPort=5500}   # Dev (alt)
    )

    # Rules para LOOPBACK (127.0.0.1) → WSL (socat)
    $rules_loop = @(
        @{Port=8083; Dest=$WSL_IP; DestPort=8083}
        @{Port=5500; Dest=$WSL_IP; DestPort=5500}
        @{Port=5599; Dest=$WSL_IP; DestPort=5599}
        @{Port=5598; Dest=$WSL_IP; DestPort=5598}
        @{Port=3000; Dest=$WSL_IP; DestPort=3000}
    )

    Write-Host "  Criando regras externas (0.0.0.0)..." -ForegroundColor Gray
    foreach ($r in $rules_ext) {
        netsh interface portproxy add v4tov4 listenport=$($r.Port) listenaddress=0.0.0.0 connectport=$($r.DestPort) connectaddress=$($r.Dest)
        Write-Host "    0.0.0.0:$($r.Port) → $($r.Dest):$($r.DestPort)" -ForegroundColor DarkGray
    }

    Write-Host "  Criando regras loopback (127.0.0.1)..." -ForegroundColor Gray
    foreach ($r in $rules_loop) {
        netsh interface portproxy add v4tov4 listenport=$($r.Port) listenaddress=127.0.0.1 connectport=$($r.DestPort) connectaddress=$($r.Dest)
        Write-Host "    127.0.0.1:$($r.Port) → $($r.Dest):$($r.DestPort)" -ForegroundColor DarkGray
    }

    # Mostrar resultado
    Write-Host ""
    Write-Host "  Regras finais:" -ForegroundColor Gray
    $proxyOutput = netsh interface portproxy show v4tov4
    $proxyOutput | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }

    Write-OK "Netsh PortProxy configurado"
    return $true
}

# ──────────────────────────────────────────────
# FUNÇÃO: Setup-ScheduledTask
# ──────────────────────────────────────────────
function Setup-ScheduledTask {
    <#
    .SYNOPSIS
      Cria Scheduled Task para auto-start do cluster no logon do Windows.
    #>
    Write-Step "Scheduled Task" "⏰"

    $taskName = "k8s-portfolio-start"
    $existing = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue

    if ($existing) {
        Write-OK "Scheduled Task '$taskName' já existe"
        return
    }

    $action = New-ScheduledTaskAction -Execute "wsl.exe" -Argument "-d Ubuntu -- bash -c 'systemctl start cluster.target'"
    $trigger = New-ScheduledTaskTrigger -AtLogOn
    $principal = New-ScheduledTaskPrincipal -UserId "$env:USERNAME" -RunLevel Highest
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Force

    Write-OK "Scheduled Task '$taskName' criada (auto-start no logon)"
}

# ──────────────────────────────────────────────
# FUNÇÃO: Setup-Firewall
# ──────────────────────────────────────────────
function Setup-Firewall {
    <#
    .SYNOPSIS
      Libera portas no Firewall do Windows para acesso externo ao cluster.
    #>
    Write-Step "Firewall" "🔒"

    $fwPorts = @(80, 443, 3000, 5500, 5599, 5598, 8002, 8083, 5501)
    $added = 0
    foreach ($port in $fwPorts) {
        $ruleName = "Portfolio-$port"
        $exists = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
        if (-not $exists) {
            New-NetFirewallRule -DisplayName $ruleName -Direction Inbound -Action Allow -LocalPort $port -Protocol TCP -ErrorAction SilentlyContinue | Out-Null
            $added++
        }
    }
    Write-OK "Firewall: $added regras adicionadas ($($fwPorts.Count - $added) já existiam)"
}

# ──────────────────────────────────────────────
# FUNÇÃO: Show-WslDockerInstructions
# ──────────────────────────────────────────────
function Show-WslDockerInstructions {
    Write-Step "WSL + Docker (nativo)" "📖"

    Write-Host ""
    Write-Host "┌── Docker Engine (WSL nativo) ──────────────────────" -ForegroundColor Cyan
    Write-Host "✅ Docker Engine sera instalado AUTOMATICAMENTE" -ForegroundColor Green
    Write-Host "   pelo bootstrap dentro do WSL (wsl/scripts/bootstrap-wsl.sh)" -ForegroundColor White
    Write-Host "   Nao e necessario instalar Docker Desktop no Windows." -ForegroundColor White
    Write-Host "   O Docker Engine roda nativamente dentro do WSL2." -ForegroundColor White
    Write-Host "└───────────────────────────────────────────────────" -ForegroundColor Cyan
}


# ══════════════════════════════════════════════
# EXECUÇÃO PRINCIPAL
# ══════════════════════════════════════════════

Write-Host ""
Write-Host "▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓" -ForegroundColor DarkCyan
Write-Host "▓                                                         ▓" -ForegroundColor DarkCyan
Write-Host "▓   BOOTSTRAP WINDOWS — k8s-portfolio-iac                ▓" -ForegroundColor DarkCyan
Write-Host "▓   Ponto de entrada único                               ▓" -ForegroundColor DarkCyan
Write-Host "▓                                                         ▓" -ForegroundColor DarkCyan
Write-Host "▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓" -ForegroundColor DarkCyan
Write-Host ""

# 0. Verificar Admin
Test-Admin

# 1. Git Setup
Write-Step "Git Setup" "🔧"
if (Test-Path $SETUP_GIT) {
    Write-Host "  Executando setup-git.ps1..." -ForegroundColor Gray
    & $SETUP_GIT
    Write-OK "Git configurado"
} else {
    Write-Warn "setup-git.ps1 não encontrado em $SETUP_GIT — pulando configuração Git"
}

# 2. Netsh PortProxy
Setup-NetshPortProxy

# 3. Firewall
Setup-Firewall

# 4. Scheduled Task
Setup-ScheduledTask

# 5. Instruções WSL + Docker
Show-WslDockerInstructions

# ── Resumo Final ──
$DURATION = [math]::Round(((Get-Date) - $START_TIME).TotalSeconds, 1)
Write-Host ""
Write-Host "▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓" -ForegroundColor DarkCyan
Write-Host "" -ForegroundColor DarkCyan
Write-OK "Bootstrap Windows CONCLUÍDO em ${DURATION}s"
Write-Host ""
Write-Host "  Resumo:" -ForegroundColor White
Write-Host "  ✔ Git configurado" -ForegroundColor Green
Write-Host "  ✔ Netsh PortProxy configurado (IPs dinâmicos)" -ForegroundColor Green
Write-Host "  ✔ Firewall liberado" -ForegroundColor Green
Write-Host "  ✔ Scheduled Task criada (auto-start no logon)" -ForegroundColor Green
Write-Host "  ✔ Instruções WSL + Docker exibidas" -ForegroundColor Green
Write-Host ""
Write-Host "  Para verificar a saúde do cluster execute:" -ForegroundColor Gray
Write-Host "    Invoke-HealthCheck" -ForegroundColor White
Write-Host ""
Write-Host "  Para iniciar o cluster manualmente execute:" -ForegroundColor Gray
Write-Host "    Start-PortfolioCluster" -ForegroundColor White
Write-Host ""
Write-Host "▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓" -ForegroundColor DarkCyan
Write-Host ""
