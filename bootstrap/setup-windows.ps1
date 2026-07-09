# setup-windows.ps1
Write-Host "=== Setup Windows Portfolio ==="

# 1. Create Scheduled Tasks
$action = New-ScheduledTaskAction -Execute "wsl.exe" -Argument "-d Ubuntu -u administrator bash -c 'bash /home/administrator/k8s-portfolio-iac/scripts/portfolio-daemon.sh > /tmp/daemon.log 2>&1 &'"
$trigger = New-ScheduledTaskTrigger -AtLogOn -RandomDelay "00:01:00"
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
Register-ScheduledTask -TaskName "Portfolio-Daemon" -Action $action -Trigger $trigger -Settings $settings -Force

# 2. Configure netsh
$wslIP = wsl -d Ubuntu hostname -I 2>$null
if ($wslIP) { $wslIP = ($wslIP -split " ")[0] }
if ($wslIP) {
    $ports = @(8083, 3000, 5500, 5599, 8002)
    foreach ($port in $ports) {
        netsh interface portproxy delete v4tov4 listenport=$port listenaddress=0.0.0.0 2>$null
        netsh interface portproxy add v4tov4 listenport=$port listenaddress=0.0.0.0 connectport=$port connectaddress=$wslIP 2>$null
    }
}

# 3. Firewall
foreach ($port in @(8083,3000,5500,5599,8002)) {
    New-NetFirewallRule -DisplayName "Portfolio-$port" -Direction Inbound -Action Allow -LocalPort $port -Protocol TCP -ErrorAction SilentlyContinue
}

Write-Host "=== Setup Windows Completo ==="
