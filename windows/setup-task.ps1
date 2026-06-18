# Creates scheduled task to auto-start cluster at Windows logon
# Run as Administrator: powershell -File setup-task.ps1

$action = New-ScheduledTaskAction -Execute "wsl.exe" -Argument "-d Ubuntu -- bash -c 'systemctl start cluster.target'"
$trigger = New-ScheduledTaskTrigger -AtLogOn
$principal = New-ScheduledTaskPrincipal -UserId "$env:USERNAME" -RunLevel Highest
Register-ScheduledTask -TaskName "k8s-portfolio-start" -Action $action -Trigger $trigger -Principal $principal -Force
Write-Host "Task k8s-portfolio-start created!"
