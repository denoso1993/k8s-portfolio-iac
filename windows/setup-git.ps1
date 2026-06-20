# setup-git.ps1 — Configura Git em PC novo para o repositório k8s-portfolio-iac
# Execute como: powershell -ExecutionPolicy Bypass -File .\setup-git.ps1

$ErrorActionPreference = "Continue"
$REPO_URL = "https://github.com/denoso1993/k8s-portfolio-iac.git"
$BRIDGE_URL = "https://github.com/denoso1993/WSL-Opencode-Bridge.git"
$PROJECTS_DIR = "$env:USERPROFILE\Documents\Projects"
$REPO_DIR = "$PROJECTS_DIR\k8s-portfolio-iac"
$BRIDGE_DIR = "$PROJECTS_DIR\WSL-Opencode-Bridge"

Write-Host "=== Setup Git para k8s-portfolio-iac ===" -ForegroundColor Cyan
Write-Host ""

# 1. Verificar Git
Write-Host "[1/5] Verificando Git..." -ForegroundColor Yellow
try {
    $gitVersion = git --version 2>&1
    Write-Host "  ✅ Git instalado: $gitVersion" -ForegroundColor Green
} catch {
    Write-Host "  ❌ Git não encontrado!" -ForegroundColor Red
    Write-Host "  Baixe e instale de: https://git-scm.com/download/win" -ForegroundColor Yellow
    Write-Host "  Após instalar, execute este script novamente." -ForegroundColor Yellow
    exit 1
}

# 2. Configurar identidade
Write-Host ""
Write-Host "[2/5] Configurando identidade Git..." -ForegroundColor Yellow

$currentName = git config --global user.name 2>$null
$currentEmail = git config --global user.email 2>$null

if (-not $currentName) {
    git config --global user.name "denoso1993"
    Write-Host "  ✅ user.name configurado: denoso1993" -ForegroundColor Green
} else {
    Write-Host "  ✅ user.name já configurado: $currentName" -ForegroundColor Green
}

if (-not $currentEmail) {
    git config --global user.email "denoso1993@gmail.com"
    Write-Host "  ✅ user.email configurado: denoso1993@gmail.com" -ForegroundColor Green
} else {
    Write-Host "  ✅ user.email já configurado: $currentEmail" -ForegroundColor Green
}

# 3. Configurar credential helper
Write-Host ""
Write-Host "[3/5] Configurando credenciais..." -ForegroundColor Yellow
$credHelper = git config --global credential.helper 2>$null
if (-not $credHelper) {
    git config --global credential.helper manager
    Write-Host "  ✅ credential.helper configurado: manager" -ForegroundColor Green
    Write-Host "  ℹ️  Na primeira vez que fizer git push, o Windows pedirá login." -ForegroundColor Gray
    Write-Host "     Use seu GitHub Personal Access Token como senha." -ForegroundColor Gray
} else {
    Write-Host "  ✅ credential.helper já configurado: $credHelper" -ForegroundColor Green
}

# 4. Clonar repositórios
Write-Host ""
Write-Host "[4/5] Clonando repositórios..." -ForegroundColor Yellow

# Criar diretório de projetos
if (-not (Test-Path $PROJECTS_DIR)) {
    New-Item -ItemType Directory -Path $PROJECTS_DIR -Force | Out-Null
    Write-Host "  ✅ Diretório $PROJECTS_DIR criado" -ForegroundColor Green
}

# Clonar k8s-portfolio-iac
if (-not (Test-Path "$REPO_DIR\.git")) {
    Write-Host "  Clonando k8s-portfolio-iac..." -ForegroundColor Gray
    try {
        git clone $REPO_URL $REPO_DIR 2>&1 | Out-Null
        Write-Host "  ✅ k8s-portfolio-iac clonado" -ForegroundColor Green
    } catch {
        Write-Host "  ❌ Falha ao clonar: $_" -ForegroundColor Red
        Write-Host "  Execute manualmente: git clone $REPO_URL `"$REPO_DIR`"" -ForegroundColor Yellow
    }
} else {
    Write-Host "  ✅ k8s-portfolio-iac já existe em $REPO_DIR" -ForegroundColor Green
}

# Clonar WSL-Opencode-Bridge
if (-not (Test-Path "$BRIDGE_DIR\.git")) {
    Write-Host "  Clonando WSL-Opencode-Bridge..." -ForegroundColor Gray
    try {
        git clone $BRIDGE_URL $BRIDGE_DIR 2>&1 | Out-Null
        Write-Host "  ✅ WSL-Opencode-Bridge clonado" -ForegroundColor Green
    } catch {
        Write-Host "  ❌ Falha ao clonar: $_" -ForegroundColor Red
        Write-Host "  Execute manualmente: git clone $BRIDGE_URL `"$BRIDGE_DIR`"" -ForegroundColor Yellow
    }
} else {
    Write-Host "  ✅ WSL-Opencode-Bridge já existe em $BRIDGE_DIR" -ForegroundColor Green
}

# 5. Instruções finais
Write-Host ""
Write-Host "[5/5] Configuração concluída!" -ForegroundColor Yellow
Write-Host ""
Write-Host "=== PRÓXIMOS PASSOS ===" -ForegroundColor Cyan
Write-Host "1. Entre no WSL: wsl -d Ubuntu" -ForegroundColor White
Write-Host "2. Vá para o diretório: cd ~/k8s-portfolio-iac" -ForegroundColor White
Write-Host "3. Execute o bootstrap: bash wsl/scripts/bootstrap-wsl.sh" -ForegroundColor White
Write-Host "4. Configure o token do Cloudflare (se necessário)" -ForegroundColor White
Write-Host ""
Write-Host "Para configurar o token do Cloudflare:" -ForegroundColor Yellow
Write-Host "  echo 'SEU_TOKEN' | sudo tee /etc/cloudflared-token" -ForegroundColor Gray
Write-Host "  sudo systemctl restart cloudflared-tunnel.service" -ForegroundColor Gray
Write-Host "========================" -ForegroundColor Cyan
