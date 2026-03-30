try {
    $provisioned = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -eq 'Microsoft.OutlookForWindows' }
    $installed = Get-AppxPackage -AllUsers -Name 'Microsoft.OutlookForWindows' -ErrorAction SilentlyContinue

    if ($provisioned -or $installed) {
        Write-Output "New Outlook detected"
        exit 1
    }
    Write-Output "New Outlook not present"
    exit 0
}
catch {
    Write-Output "Error: $_"
    exit 1
}