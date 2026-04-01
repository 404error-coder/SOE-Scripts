# Check all Office app add-in registrations
$paths = @(
    "HKLM:\SOFTWARE\Microsoft\Office\Word\Addins",
    "HKLM:\SOFTWARE\Microsoft\Office\Excel\Addins",
    "HKLM:\SOFTWARE\Microsoft\Office\Outlook\Addins",
    "HKLM:\SOFTWARE\Microsoft\Office\PowerPoint\Addins",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Office\Word\Addins",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Office\Excel\Addins",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Office\Outlook\Addins",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Office\PowerPoint\Addins"
)

foreach ($path in $paths) {
    if (Test-Path $path) {
        Get-ChildItem $path | ForEach-Object {
            if ($_.PSChildName -like "*Janus*" -or $_.PSChildName -like "*Seal*") {
                Write-Output "$path\$($_.PSChildName)"
                Get-ItemProperty $_.PSPath | Format-List *
            }
        }
    }
}