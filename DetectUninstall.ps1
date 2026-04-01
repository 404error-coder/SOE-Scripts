# Check recent application uninstall events
Get-WinEvent -LogName "Microsoft-Windows-AppXDeploymentServer/Operational" -MaxEvents 50 |
    Where-Object { $_.Message -match "Teams" } |
    Select-Object TimeCreated, Id, Message | Format-List

# Check if your debloat remediation ran recently
Get-WinEvent -LogName "Microsoft-Windows-DeviceManagement-Enterprise-Diagnostics-Provider/Admin" -MaxEvents 100 |
    Where-Object { $_.Message -match "remediation|proactive" } |
    Select-Object TimeCreated, Message | Format-List