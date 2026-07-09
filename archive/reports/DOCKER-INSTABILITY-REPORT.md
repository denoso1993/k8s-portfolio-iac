# Docker Engine Instability Report

## Problem
Kubernetes cluster (Kind) crashes repeatedly after ~30 seconds of operation.

## Symptoms
1. Cluster starts successfully
2. kubectl commands work for ~30 seconds
3. API server becomes unreachable: `connection refused to 127.0.0.1:40073`
4. Container exits with code 128

## Root Cause Analysis

### Possible Causes:
1. **Docker Engine WSL2 Integration Unstable**
   - WSL2 networking layer may be corrupted
   - Docker Engine process may need restart

2. **Resource Constraints**
   - Insufficient memory allocated to Docker
   - CPU throttling

3. **Port Conflicts**
   - Port 40073 may be in use
   - WSL2 proxy issues

## Immediate Solution

### Step 1: Restart Docker Engine
```powershell
# Run as Administrator
wsl --shutdown
Start-Sleep -Seconds 10
# Then restart WSL
wsl -d Ubuntu
```

### Step 2: Verify Cluster
```bash
docker start lab-sre-denoso-control-plane
sleep 30
kubectl get nodes
```

### Step 3: Test Nginx
```bash
kubectl port-forward svc/nginx-service 8081:80 &
sleep 5
curl http://localhost:8081
```

## If Problem Persists

### Option A: Recreate Cluster
```bash
kind delete cluster --name lab-sre-denoso
kind create cluster --name lab-sre-denoso --config kind-config.yaml
```

### Option B: Increase Docker Resources
1. Configure `.wslconfig` no Windows:
   ```ini
   [wsl2]
   memory=4GB
   ```
2. Apply: `wsl --shutdown`

### Option C: Check Logs
```bash
docker logs lab-sre-denoso-control-plane
wsl -d Ubuntu -e journalctl -u docker
```

## Current Status

- ✅ Cluster starts successfully
- ⚠️ Cluster unstable (crashes after ~30s)
- ⚠️ Nginx deployment exists but unreachable
- ⚠️ Port-forward fails due to instability

## Next Steps

1. **IMMEDIATE**: Restart Docker Engine
2. **VERIFY**: Cluster stability
3. **TEST**: Nginx access
4. **DOCUMENT**: Results

---

*Created: 2026-05-12 23:45*  
*Severity: Critical*  
*Impact: Portfolio inaccessible*
