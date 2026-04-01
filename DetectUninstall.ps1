# 1. Check if the MSIX is still registered (if empty, it was uninstalled)
Get-AppxPackage -AllUsers *MSTeams* | Select-Object Name, PackageFullName, Status

# 2. Check IME log for any Win32 app that ran an uninstall post-ESP
$imelog = Get-Content "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension.log" -Raw
# Look for uninstall commands that fired recently
($imelog | Select-String -Pattern "uninstall|remove" -AllMatches).Matches | 
    Select-Object -Last 20

# 3. Check for scheduled tasks that smell like cleanup
Get-ScheduledTask | Where-Object { 
    $_.Actions.Execute -match "powershell|cmd" -and 
    $_.State -ne "Disabled" 
} | ForEach-Object {
    [PSCustomObject]@{
        Name    = $_.TaskName
        Path    = $_.TaskPath
        Command = ($_.Actions | ForEach-Object { "$($_.Execute) $($_.Arguments)" }) -join "; "
        LastRun = ($_ | Get-ScheduledTaskInfo).LastRunTime
    }
} | Sort-Object LastRun -Descending | Select-Object -First 20 | Format-List

# 4. Check Application event log for MsiInstaller uninstall events
Get-WinEvent -LogName Application -MaxEvents 200 |
    Where-Object { $_.ProviderName -eq "MsiInstaller" -and $_.Message -match "teams|remove|uninstall" } |
    Select-Object TimeCreated, Message | Format-List

# 5. Check if teamsbootstrapper left a breadcrumb
Get-WinEvent -FilterHashtable @{LogName="Application"; StartTime=(Get-Date).AddHours(-1)} -MaxEvents 200 |
    Where-Object { $_.Message -match "teams" } |
    Select-Object TimeCreated, ProviderName, Id, Message | Format-List