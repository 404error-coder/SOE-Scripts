# Detect-OutlookAutostart.ps1
# Runs in user context
$regPath  = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$regName  = "Outlook"
$expected = "`"C:\Program Files\Microsoft Office\root\Office16\OUTLOOK.EXE`""

try {
    $current = (Get-ItemProperty -Path $regPath -Name $regName -ErrorAction Stop).$regName
    if ($current -eq $expected) {
        Write-Output "Compliant – Outlook autostart key present and correct."
        exit 0
    } else {
        Write-Output "Non-compliant – value mismatch: $current"
        exit 1
    }
} catch {
    Write-Output "Non-compliant – Outlook autostart key missing."
    exit 1
}