# Guia de Setup do Zero

## Pre-requisitos
- Windows 10/11 com WSL2
- Docker Desktop
- Git
- 4GB RAM disponivel

## Passo a passo

### 1. Instalar WSL2
```powershell
wsl --install -d Ubuntu
wsl --set-default-version 2
```

### 2. Instalar Docker Desktop
Baixar de https://www.docker.com/products/docker-desktop/
Ativar WSL2 backend nas settings.

### 3. Clonar repositorio
```bash
git clone https://github.com/denoso1993/k8s-portfolio-iac.git
cd k8s-portfolio-iac
```

### 4. Instalar ferramentas
```bash
# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl && sudo mv kubectl /usr/local/bin/

# kind
curl -Lo ./kind https://kind.sigs.k8s.io/dl/latest/kind-linux-amd64
chmod +x ./kind && sudo mv ./kind /usr/local/bin/kind

# helm
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

### 5. Configurar WSL memory
Copiar .wslconfig para %USERPROFILE%
```powershell
copy .wslconfig %USERPROFILE%\.wslconfig
wsl --shutdown
```

### 6. Criar cluster e aplicar tudo
```bash
bash scripts/restore-all.sh
```

### 7. Verificar
http://localhost:8083 - Site
http://localhost:8083/grafana/ - Grafana
http://localhost:3000 - Grafana (admin/admin)
