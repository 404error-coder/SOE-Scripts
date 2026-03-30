#Detection AppIDSVC WDAC Managed Installer Service

$svc = Get-Service -Name AppIDSvc -ErrorAction SilentlyContinue
if ($svc -and $svc.StartType -eq 'Automatic' -and $svc.Status -eq 'Running') {
    Write-Output "AppIDSvc is Automatic and Running."
    exit 0
} else {
    Write-Output "AppIDSvc requires remediation. StartType: $($svc.StartType), Status: $($svc.Status)"
    exit 1
}