# Remediation script - Autodiscover SCP lockdown
# Runs in user context

$regPath = "HKCU:\Software\Microsoft\Office\16.0\Outlook\AutoDiscover"

$values = @{
    ExcludeScpLookup            = 1
    ExcludeHttpsRootDomain      = 1
    ExcludeHttpRedirect         = 1
    ExcludeSrvRecord            = 1
    ExcludeExplicitO365Endpoint = 0
    ExcludeHttpsAutoDiscoverDomain = 1
}

try {
    if (-not (Test-Path $regPath)) {
        New-Item -Path $regPath -Force | Out-Null
    }

    foreach ($name in $values.Keys) {
        Set-ItemProperty -Path $regPath -Name $name -Value $values[$name] -Type DWord -Force
    }

    Write-Output "All Autodiscover values remediated"
    exit 0
}
catch {
    Write-Output "Remediation error: $_"
    exit 1
}