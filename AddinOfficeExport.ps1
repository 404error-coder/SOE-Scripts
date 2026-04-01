$apps = @("Word", "Excel", "PowerPoint")
$bases = @("HKLM:\SOFTWARE\Microsoft\Office", "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Office", "HKCU:\SOFTWARE\Microsoft\Office")

foreach ($base in $bases) {
    foreach ($app in $apps) {
        $path = "$base\$app\Addins"
        if (Test-Path $path) {
            Write-Output "`n=== $path ==="
            Get-ChildItem $path | ForEach-Object {
                Write-Output "  $($_.PSChildName)"
            }
        }
    }
}