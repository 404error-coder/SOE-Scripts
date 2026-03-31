# 1. SRP — this is the other mechanism that returns error 1260
#    Check if any Software Restriction Policies exist
Get-ChildItem "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Safer\CodeIdentifiers" -Recurse -ErrorAction SilentlyContinue

# 2. MDM WMI store — Intune-delivered policies sometimes land here
Get-CimInstance -Namespace "root\cimv2\mdm\dmmap" -ClassName "MDM_AppLocker_ApplicationLaunchRestrictions01_EXE03" -ErrorAction SilentlyContinue
Get-CimInstance -Namespace "root\cimv2\mdm\dmmap" -ClassName "MDM_AppLocker_ApplicationLaunchRestrictions01_MSI03" -ErrorAction SilentlyContinue

# 3. Full SrpV2 dump — your earlier check may have missed sub-keys
Get-ChildItem "HKLM:\SOFTWARE\Policies\Microsoft\Windows\SrpV2" -Recurse -ErrorAction SilentlyContinue | 
    ForEach-Object { 
        Write-Host $_.PSPath -ForegroundColor Yellow
        $_.GetValueNames() | ForEach-Object { Write-Host "  $_" }
    }

# 4. Check the MDM diagnostics report — this shows EVERY policy delivered by Intune
Start-Process "mdmdiagnosticstool.exe" -ArgumentList "-out $env:UserProfile\Desktop\MDMDiag" -Wait
Write-Host "Diagnostics exported to $env:UserProfile\Desktop\MDMDiag"