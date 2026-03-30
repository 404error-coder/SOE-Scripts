# Remediate GSA Client registry hardening + Kerberos negative cache remediation

try {
    # --- GSA Client settings ---
    $gsaPath = "HKLM:\SOFTWARE\Microsoft\Global Secure Access Client"
    $gsaSettings = @{
        "HideSignOutButton"             = 1
        "HideDisablePrivateAccessButton" = 1
        "HideDisableButton"             = 1
        "RestrictNonPrivilegedUsers"    = 1
    }

    if (-not (Test-Path $gsaPath)) {
        New-Item -Path $gsaPath -Force | Out-Null
    }

    foreach ($setting in $gsaSettings.GetEnumerator()) {
        Set-ItemProperty -Path $gsaPath -Name $setting.Key -Value $setting.Value -Type DWord -Force | Out-Null
        Write-Output "Set $($setting.Key) to $($setting.Value)"
    }

    # --- Kerberos negative cache ---
    $kerbPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\Kerberos\Parameters"

    if (-not (Test-Path $kerbPath)) {
        New-Item -Path $kerbPath -Force | Out-Null
    }

    Set-ItemProperty -Path $kerbPath -Name "FarKdcTimeout" -Value 0 -Type DWord -Force | Out-Null
    Write-Output "Set FarKdcTimeout to 0 (disabled Kerberos negative caching)"

    exit 0
}
catch {
    Write-Output "Remediation failed: $_"
    exit 1
}