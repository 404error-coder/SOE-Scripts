z# Remediate-OutlookAutostart.ps1
# Runs in user context
$regPath  = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$regName  = "Outlook"
$regValue = '"C:\Program Files\Microsoft Office\root\Office16\OUTLOOK.EXE"' 

try {
    if (-not (Test-Path $regPath)) {
        New-Item -Path $regPath -Force | Out-Null
    }
    Set-ItemProperty -Path $regPath -Name $regName -Value $regValue -Type String -Force
    Write-Output "Remediated – Outlook autostart key set."
    exit 0
} catch {
    Write-Output "Failed to set Outlook autostart key: $_"
    exit 1
}


# Remediate-OutlookAutostart.ps1
$regPath  = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$regName  = "Outlook"
$regValue = '"C:\Program Files\Microsoft Office\root\Office16\OUTLOOK.EXE"'

try {
    New-ItemProperty -Path $regPath -Name $regName -Value $regValue -PropertyType String -Force | Out-Null
    Write-Output "Remediated - Outlook autostart key set."
    exit 0
} catch {
    Write-Output "Failed to set Outlook autostart key: $_"
    exit 1
}



# Remediate-OutlookAutostart.ps1
$regPath  = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$regName  = 'Outlook'
$regValue = '"C:\Program Files\Microsoft Office\root\Office16\OUTLOOK.EXE"'

try {
    New-ItemProperty -Path $regPath -Name $regName -Value $regValue -PropertyType String -Force | Out-Null
    Write-Output 'Remediated - Outlook autostart key set.'
    exit 0
}
catch {
    Write-Output ('Failed to set Outlook autostart key: ' + $_.Exception.Message)
    exit 1
}