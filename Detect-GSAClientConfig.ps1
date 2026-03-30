# Detect GSA Client registry hardening + Kerberos negative cache detection

$nonCompliant = $false

# --- GSA Client settings ---
$gsaPath = "HKLM:\SOFTWARE\Microsoft\Global Secure Access Client"
$gsaSettings = @{
    "HideSignOutButton"             = 1
    "HideDisablePrivateAccessButton" = 1
    "HideDisableButton"             = 1
    "RestrictNonPrivilegedUsers"    = 1
}

foreach ($setting in $gsaSettings.GetEnumerator()) {
    $currentValue = (Get-ItemProperty -Path $gsaPath -Name $setting.Key -ErrorAction SilentlyContinue).$($setting.Key)
    if ($currentValue -ne $setting.Value) {
        Write-Output "Non-compliant: $($setting.Key) is $currentValue, expected $($setting.Value)"
        $nonCompliant = $true
    }
}

# --- Detect Kerberos negative cache ---
$kerbPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\Kerberos\Parameters"
$farKdc = (Get-ItemProperty -Path $kerbPath -Name "FarKdcTimeout" -ErrorAction SilentlyContinue).FarKdcTimeout

if ($farKdc -ne 0) {
    Write-Output "Non-compliant: FarKdcTimeout is $farKdc, expected 0"
    $nonCompliant = $true
}

# --- Result ---
if (-not $nonCompliant) {
    Write-Output "Compliant"
    exit 0
} else {
    Write-Output "Non-compliant"
    exit 1
}