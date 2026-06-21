# Nginx Access Issue - Troubleshooting

## Problem
Nginx pod is Running but not accessible via:
- localhost:8081 (port-forward)
- localhost:30000 (NodePort)
- 10.96.250.147:80 (ClusterIP)

## Diagnostics

### 1. Pod Status: ✅ Running
```bash
kubectl get pods -l app=nginx
# nginx-deployment-5f78b65b77-j2h82  1/1 Running
```

### 2. Nginx Process: ✅ Working
```bash
kubectl exec deployment/nginx-deployment -- cat /usr/share/nginx/html/index.html
# Returns: <!DOCTYPE html><html>...
```

### 3. Service Config: ✅ Correct
- NodePort: 30000
- Port: 80
- TargetPort: 8080
- Endpoint: 10.244.0.13:8080 ✅

### 4. Port-forward: ❌ Failing
- Connection reset by peer
- Address already in use

## Root Cause

**Firewall do Windows** está bloqueando conexões de entrada no WSL2.

## Solutions

### Solution 1: Windows Firewall Rule (Recommended)
```powershell
# Run as Administrator in PowerShell
New-NetFirewallRule -DisplayName "WSL2 Incoming" -Direction Inbound -Action Allow -Profile Any
```

### Solution 2: Access via WSL IP
```bash
# Get WSL IP
wsl hostname -I | awk '{print $1}'

# Access via that IP
curl http://<WSL_IP>:30000
```

### Solution 3: Docker Engine Config
1. Verificar se o Docker Engine esta rodando no WSL:
   ```bash
   sudo systemctl status docker
   ```
2. Se necessario, reiniciar:
   ```bash
   sudo systemctl restart docker
   ```

### Solution 4: Use kubectl from WSL directly
```bash
# Inside WSL
curl http://localhost:8080

# Or from Windows PowerShell
wsl bash -c "curl http://localhost:8080"
```

## Current Status

- Cluster: ✅ 31/31 pods Running
- Nginx: ✅ Serving content
- Port-forward: ⚠️ Blocked by firewall
- NodePort: ⚠️ Blocked by firewall

## Next Steps

1. Apply firewall rule (Solution 1)
2. Test access: http://localhost:8081
3. Update documentation

---

*Created: 2026-05-12 23:00*
