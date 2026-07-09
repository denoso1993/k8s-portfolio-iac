# Get ClusterIP
$clusterIP = bash -c "sudo kubectl get svc nginx-service -n default -o jsonpath='{.spec.clusterIP}' 2>&1"
Write-Host "ClusterIP=$clusterIP"

# Build service file content
$content = @"
[Unit]
Description=Socat forward 8083 -> nginx ClusterIP
After=network-online.target

[Service]
Type=exec
ExecStart=/usr/bin/socat TCP-LISTEN:8083,fork,reuseaddr TCP:${clusterIP}:80
Restart=always
RestartSec=3
User=root

[Install]
WantedBy=cluster.target
"@

# Write to temp file
$tmpFile = [System.IO.Path]::GetTempFileName()
$content | Set-Content -Path $tmpFile -Encoding ASCII

# Copy to WSL
$null = bash -c "sudo cp '$tmpFile' /etc/systemd/system/socat-8083.service 2>&1"

# Cleanup
Remove-Item -LiteralPath $tmpFile -Force

# Verify
Write-Host "=== VERIFYING ==="
bash -c "cat /etc/systemd/system/socat-8083.service 2>&1"
