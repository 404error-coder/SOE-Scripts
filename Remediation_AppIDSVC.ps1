#Remediation AppIDSVC WDAC Managed Installer Service

try {
    Set-Service -Name AppIDSvc -StartupType Automatic -ErrorAction Stop
    Start-Service -Name AppIDSvc -ErrorAction Stop
    Write-Output "AppIDSvc set to Automatic and started."
    exit 0
} catch {
    Write-Output "Failed to configure AppIDSvc: $_"
    exit 1
}
