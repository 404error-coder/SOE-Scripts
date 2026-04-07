#Step 1
Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
                  'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' |
    Where-Object { $_.DisplayName -match 'Horizon|VMware|' } |
    Select-Object DisplayName, InstallLocation, Publisher

#Step 2
Get-Process | Where-Object { $_.Path -match 'VMware|Horizon' -and $_.Path } |
    ForEach-Object { 
        $_.Modules | Select-Object -ExpandProperty FileName 
    } |
    Sort-Object -Unique |
    ForEach-Object { Split-Path $_ -Parent } |
    Sort-Object -Unique

#Step 3
$searchPattern = 'VMware|Horizon'  # adjust per app

Write-Host "`n=== SERVICES ===" -ForegroundColor Cyan
Get-CimInstance -ClassName Win32_Service |
    Where-Object { $_.PathName -match $searchPattern } |
    Select-Object Name, DisplayName, State,
        @{N='Path';E={ if ($_.PathName -match '"([^"]+)"') { $matches[1] } else { ($_.PathName -split ' ')[0] } }},
        @{N='Directory';E={ 
            $p = if ($_.PathName -match '"([^"]+)"') { $matches[1] } else { ($_.PathName -split ' ')[0] }
            Split-Path $p -Parent
        }} |
    Format-List

Write-Host "`n=== KERNEL DRIVERS ===" -ForegroundColor Cyan
Get-CimInstance -ClassName Win32_SystemDriver |
    Where-Object { $_.PathName -match $searchPattern } |
    Select-Object Name, DisplayName, State,
        @{N='Path';E={ $_.PathName }},
        @{N='Directory';E={ Split-Path $_.PathName -Parent }} |
    Format-List
