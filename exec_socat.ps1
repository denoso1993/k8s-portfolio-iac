# PASSO 1: Ver NodePorts atuais
Write-Host "=== PASSO 1: NodePorts ==="
wsl -d Ubuntu -e bash -l -c "kubectl get svc nginx-service -n default -o jsonpath='{.spec.ports[0].nodePort}' 2>&1" | ForEach-Object { "nginx: $_" }
wsl -d Ubuntu -e bash -l -c "kubectl get svc dev-server-service -n default -o jsonpath='{.spec.ports[0].nodePort}' 2>&1" | ForEach-Object { "dev: $_" }
wsl -d Ubuntu -e bash -l -c "kubectl get svc mobile-server-service -n default -o jsonpath='{.spec.ports[0].nodePort}' 2>&1" | ForEach-Object { "mobile: $_" }
wsl -d Ubuntu -e bash -l -c "kubectl get svc mobile-dev-server-service -n default -o jsonpath='{.spec.ports[0].nodePort}' 2>&1" | ForEach-Object { "mobile-dev: $_" }

# PASSO 2: Atualizar socat services
Write-Host "`n=== PASSO 2: Atualizar socat services ==="

# socat-8084
$svc8084 = @'
[Unit]
Description=Socat forward port 8084 to nginx NodePort 31701
After=docker.service network-online.target
Requires=docker.service
[Service]
Type=exec
ExecStart=/usr/local/bin/socat-forward.sh 8084 31701
Restart=always
RestartSec=5
User=root
[Install]
WantedBy=cluster.target
'@
$tmp8084 = [System.IO.Path]::GetTempFileName()
Set-Content -Path $tmp8084 -Value $svc8084 -Encoding ASCII
wsl -d Ubuntu -e bash -l -c "sudo tee /etc/systemd/system/socat-8084.service > /dev/null" < $tmp8084 2>&1 | Out-Null
Remove-Item $tmp8084
Write-Host "8084_OK"

# socat-5500
$svc5500 = @'
[Unit]
Description=Socat forward port 5500 to dev-server NodePort 32286
After=docker.service network-online.target
Requires=docker.service
[Service]
Type=exec
ExecStart=/usr/local/bin/socat-forward.sh 5500 32286
Restart=always
RestartSec=5
User=root
[Install]
WantedBy=cluster.target
'@
$tmp5500 = [System.IO.Path]::GetTempFileName()
Set-Content -Path $tmp5500 -Value $svc5500 -Encoding ASCII
wsl -d Ubuntu -e bash -l -c "sudo tee /etc/systemd/system/socat-5500.service > /dev/null" < $tmp5500 2>&1 | Out-Null
Remove-Item $tmp5500
Write-Host "5500_OK"

# socat-5599
$svc5599 = @'
[Unit]
Description=Socat forward port 5599 to mobile-server NodePort 31807
After=docker.service network-online.target
Requires=docker.service
[Service]
Type=exec
ExecStart=/usr/local/bin/socat-forward.sh 5599 31807
Restart=always
RestartSec=5
User=root
[Install]
WantedBy=cluster.target
'@
$tmp5599 = [System.IO.Path]::GetTempFileName()
Set-Content -Path $tmp5599 -Value $svc5599 -Encoding ASCII
wsl -d Ubuntu -e bash -l -c "sudo tee /etc/systemd/system/socat-5599.service > /dev/null" < $tmp5599 2>&1 | Out-Null
Remove-Item $tmp5599
Write-Host "5599_OK"

# socat-5598
$svc5598 = @'
[Unit]
Description=Socat forward port 5598 to mobile-dev-server NodePort 31804
After=docker.service network-online.target
Requires=docker.service
[Service]
Type=exec
ExecStart=/usr/local/bin/socat-forward.sh 5598 31804
Restart=always
RestartSec=5
User=root
[Install]
WantedBy=cluster.target
'@
$tmp5598 = [System.IO.Path]::GetTempFileName()
Set-Content -Path $tmp5598 -Value $svc5598 -Encoding ASCII
wsl -d Ubuntu -e bash -l -c "sudo tee /etc/systemd/system/socat-5598.service > /dev/null" < $tmp5598 2>&1 | Out-Null
Remove-Item $tmp5598
Write-Host "5598_OK"

# PASSO 3: Recarregar systemd
Write-Host "`n=== PASSO 3: systemctl daemon-reload ==="
wsl -d Ubuntu -e bash -l -c "sudo systemctl daemon-reload 2>&1 && echo 'DAEMON_RELOADED'"

# PASSO 4: Reiniciar cada socat
Write-Host "`n=== PASSO 4: Restart services ==="
wsl -d Ubuntu -e bash -l -c "for s in socat-8083 socat-8084 socat-5500 socat-5599 socat-5598; do sudo systemctl restart \$s.service 2>&1; done; echo 'SERVICES_RESTARTED'"

# PASSO 5: Verificar todos ativos
Write-Host "`n=== PASSO 5: Status ==="
wsl -d Ubuntu -e bash -l -c "for s in socat-8083 socat-8084 socat-5500 socat-5599 socat-5598; do echo \"\$s: \$(systemctl is-active \$s.service)\"; done"

# PASSO 6: Testar todos os endpoints
Write-Host "`n=== PASSO 6: Endpoints ==="
wsl -d Ubuntu -e bash -l -c "for p in 8083 8084 5500 5599 5598; do echo \"porta \$p: \$(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 5 http://localhost:\$p/ 2>&1)\"; done"

# PASSO 7: Testar externo
Write-Host "`n=== PASSO 7: Teste externo ==="
wsl -d Ubuntu -e bash -l -c "curl -s -o /dev/null -w 'EXTERNO: %{http_code}\n' --connect-timeout 10 https://denisdeoliveira.com.br/ 2>&1"
