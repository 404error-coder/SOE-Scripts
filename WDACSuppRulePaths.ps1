#Step 1
Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
                  'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' |
    Where-Object { $_.DisplayName -match 'Horizon|VMware|Omnissa' } |
    Select-Object DisplayName, InstallLocation, Publisher

#Step 2
Get-Process | Where-Object { $_.Path -match 'VMware|Horizon|Omnissa' -and $_.Path } |
    ForEach-Object { 
        $_.Modules | Select-Object -ExpandProperty FileName 
    } |
    Sort-Object -Unique |
    ForEach-Object { Split-Path $_ -Parent } |
    Sort-Object -Unique

#Step 3
Get-CimInstance Win32_Service, Win32_SystemDriver |
    Where-Object { $_.PathName -match 'VMware|Horizon|Omnissa' } |
    Select-Object Name, @{N='Path';E={ ($_.PathName -split '"')[1] }}, 
                  @{N='Directory';E={ Split-Path (($_.PathName -split '"')[1]) -Parent }}
