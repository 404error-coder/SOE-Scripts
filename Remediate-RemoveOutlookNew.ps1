try {
    # Remove provisioned package (prevents install for new user profiles)
    $provisioned = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -eq 'Microsoft.OutlookForWindows' }
    if ($provisioned) {
        Remove-AppxProvisionedPackage -Online -PackageName $provisioned.PackageName
        Write-Output "Removed provisioned package"
    }

    # Remove per-user installs across all profiles
    $installed = Get-AppxPackage -AllUsers -Name 'Microsoft.OutlookForWindows' -ErrorAction SilentlyContinue
    if ($installed) {
        $installed | Remove-AppxPackage -AllUsers
        Write-Output "Removed installed package for all users"
    }

    exit 0
}
catch {
    Write-Output "Remediation failed: $_"
    exit 1
}