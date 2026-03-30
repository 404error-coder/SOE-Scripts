# Detection script - Autodiscover SCP lockdown
# Runs in user context

$regPath = "HKCU:\Software\Microsoft\Office\16.0\Outlook\AutoDiscover"

$expectedValues = @{
    ExcludeScpLookup            = 1
    ExcludeHttpsRootDomain      = 1
    ExcludeHttpRedirect         = 1
    ExcludeSrvRecord            = 1
    ExcludeExplicitO365Endpoint = 0
    ExcludeHttpsAutoDiscoverDomain = 1
}

try {
    if (-not (Test-Path $regPath)) {
        Write-Output "Registry path missing"
        exit 1
    }

    foreach ($name in $expectedValues.Keys) {
        $current = Get-ItemProperty -Path $regPath -Name $name -ErrorAction SilentlyContinue
        if ($null -eq $current.$name -or $current.$name -ne $expectedValues[$name]) {
            Write-Output "$name is non-compliant: expected $($expectedValues[$name]), got $($current.$name)"
            exit 1
        }
    }

    Write-Output "All Autodiscover values compliant"
    exit 0
}
catch {
    Write-Output "Detection error: $_"
    exit 1
}