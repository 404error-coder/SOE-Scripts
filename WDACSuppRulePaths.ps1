<#
.SYNOPSIS
    WDAC Supplemental Policy - App Discovery Script

.DESCRIPTION
    Discovers all file system locations for a given app to inform WDAC
    supplemental policy scan paths in AppControl Manager.
    
    Uses five discovery methods:
      1. Registry uninstall keys
      2. Running processes and their loaded modules
      3. Windows services
      4. Kernel-mode drivers
      5. File system search under Program Files / ProgramData / drivers

.NOTES
    - Run as Administrator on a device with the target app installed
    - Launch the app BEFORE running for best loaded-module coverage
    - Run from 64-bit PowerShell (not Windows PowerShell x86) to enumerate
      64-bit process modules
    - Outputs TXT report + CSV of unique scan paths to $OutputDir
#>

#Requires -RunAsAdministrator

# ============================================================================
# CONFIGURATION - Change these for each app
# ============================================================================

$AppName       = "VMwareHorizon"                # Short name for output files
$SearchPattern = 'VMware|Horizon'               # Regex to match app name/path
$ProcessMatch  = 'vmware|horizon|vmware-view'   # Regex to match running processes
$OutputDir     = "C:\Temp\WDAC\Discovery"       # Output directory

# Examples for your other apps (uncomment and comment out the Horizon block above):
# $AppName = "JanusSeal"
# $SearchPattern = 'Janus'
# $ProcessMatch  = 'janus|jsoutlook|js4office'

# $AppName = "ControlUp"
# $SearchPattern = 'ControlUp|Smart-X'
# $ProcessMatch  = 'cuAgent|controlup|smart-x'

# ============================================================================
# SETUP
# ============================================================================

# Ensure output directory exists
if (-not (Test-Path $OutputDir)) {
    New-Item -Path $OutputDir -ItemType Directory -Force | Out-Null
}

$timestamp  = Get-Date -Format "yyyyMMdd_HHmmss"
$reportFile = Join-Path $OutputDir "$($AppName)_Discovery_$timestamp.txt"
$pathsFile  = Join-Path $OutputDir "$($AppName)_ScanPaths_$timestamp.csv"

# Track discovered paths - keyed by path for deduplication with source merging
$discoveredPaths = @{}

# Exclusion patterns - paths matching any of these are skipped
$excludePatterns = @(
    '^C:\\Windows\\System32$'
    '^C:\\Windows\\SysWOW64$'
    '^C:\\Windows\\WinSxS'
    '^C:\\Windows\\Installer'
    '^C:\\Windows\\assembly'
    '\\Logs$'
    '\\Logs\\'
    '\\Cache$'
    '\\Cache\\'
    '\\Temp$'
    '\\Temp\\'
    '\\CrashDumps'
)

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

function Write-Report {
    param(
        [Parameter(Mandatory)][string]$Text,
        [string]$Color = 'White',
        [switch]$NoConsole
    )
    if (-not $NoConsole) {
        Write-Host $Text -ForegroundColor $Color
    }
    Add-Content -Path $script:reportFile -Value $Text -Encoding UTF8
}

function Resolve-DriverPath {
    param([string]$RawPath)
    
    if ([string]::IsNullOrWhiteSpace($RawPath)) { return $null }
    
    # Handle NT-style paths that Win32_SystemDriver sometimes returns
    $resolved = $RawPath
    $resolved = $resolved -replace '^\\\?\?\\', ''
    $resolved = $resolved -replace '^\\SystemRoot\\', "$env:SystemRoot\"
    $resolved = $resolved -replace '^System32\\', "$env:SystemRoot\System32\"
    
    # If still relative, assume System32
    if ($resolved -notmatch '^[A-Za-z]:\\') {
        $resolved = Join-Path "$env:SystemRoot\System32" $resolved
    }
    
    return $resolved
}

function Resolve-ServiceExePath {
    param([string]$PathName)
    
    if ([string]::IsNullOrWhiteSpace($PathName)) { return $null }
    
    # Handles: "C:\path with spaces\svc.exe" -args
    # Also:    C:\path\svc.exe -args
    # Also:    C:\path\svc.exe
    if ($PathName -match '^"([^"]+)"') {
        return $Matches[1]
    }
    elseif ($PathName -match '^(\S+\.exe)') {
        return $Matches[1]
    }
    else {
        return ($PathName -split ' ')[0]
    }
}

function Add-ScanPath {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Source
    )
    
    if ([string]::IsNullOrWhiteSpace($Path)) { return }
    
    # Resolve to full path and determine if file or directory
    $item = Get-Item -LiteralPath $Path -ErrorAction SilentlyContinue
    if (-not $item) { return }
    
    $dir = if ($item.PSIsContainer) {
        $item.FullName
    } else {
        Split-Path -Path $item.FullName -Parent
    }
    
    if ([string]::IsNullOrWhiteSpace($dir)) { return }
    
    # Apply exclusion patterns
    foreach ($pattern in $script:excludePatterns) {
        if ($dir -match $pattern) { return }
    }
    
    # Normalise trailing backslash
    $dir = $dir.TrimEnd('\')
    
    # Add or merge source attribution
    if ($script:discoveredPaths.ContainsKey($dir)) {
        $existing = $script:discoveredPaths[$dir]
        if ($existing -notcontains $Source) {
            $script:discoveredPaths[$dir] = @($existing) + $Source
        }
    } else {
        $script:discoveredPaths[$dir] = @($Source)
    }
}

# ============================================================================
# HEADER
# ============================================================================

# Initialise report file (truncate if exists)
Set-Content -Path $reportFile -Value "" -Encoding UTF8

Write-Report ""
Write-Report "================================================================" 'Cyan'
Write-Report "  WDAC APP DISCOVERY REPORT" 'Cyan'
Write-Report "================================================================" 'Cyan'
Write-Report "  App Name:        $AppName"
Write-Report "  Search Pattern:  $SearchPattern"
Write-Report "  Process Match:   $ProcessMatch"
Write-Report "  Generated:       $(Get-Date)"
Write-Report "  Computer:        $env:COMPUTERNAME"
Write-Report "  User:            $env:USERNAME"
Write-Report "  PS Version:      $($PSVersionTable.PSVersion)"
Write-Report "  $psArch = if ([Environment]::Is64BitProcess) { '64-bit' } else { '32-bit' }
Write-Report "  PS Architecture: $psArch"
Write-Report "================================================================" 'Cyan'
Write-Report ""

if (-not [Environment]::Is64BitProcess) {
    Write-Report "WARNING: Running in 32-bit PowerShell. Cannot enumerate modules" 'Yellow'
    Write-Report "         from 64-bit processes. Re-run in 64-bit PowerShell for" 'Yellow'
    Write-Report "         complete coverage." 'Yellow'
    Write-Report ""
}

# ============================================================================
# METHOD 1: Registry Uninstall Keys
# ============================================================================

Write-Report ""
Write-Report "=== [1/5] REGISTRY UNINSTALL KEYS ===" 'Yellow'
Write-Report ""

$uninstallKeyPaths = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall'
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
)

$installedApps = foreach ($keyPath in $uninstallKeyPaths) {
    if (Test-Path $keyPath) {
        Get-ChildItem -Path $keyPath -ErrorAction SilentlyContinue | ForEach-Object {
            try {
                $props = Get-ItemProperty -Path $_.PSPath -ErrorAction Stop
                if ($props.DisplayName -match $SearchPattern) {
                    $props
                }
            } catch {
                # Skip keys we can't read
            }
        }
    }
}

if ($installedApps) {
    foreach ($app in $installedApps) {
        Write-Report "Product:         $($app.DisplayName)"
        Write-Report "Version:         $($app.DisplayVersion)"
        Write-Report "Publisher:       $($app.Publisher)"
        Write-Report "InstallLocation: $($app.InstallLocation)"
        Write-Report "InstallSource:   $($app.InstallSource)"
        Write-Report "UninstallString: $($app.UninstallString)"
        Write-Report ""
        
        if ($app.InstallLocation) {
            Add-ScanPath -Path $app.InstallLocation -Source "Registry:InstallLocation"
        }
    }
} else {
    Write-Report "  No matching products found in registry." 'Gray'
}

# ============================================================================
# METHOD 2: Running Processes and Loaded Modules
# ============================================================================

Write-Report ""
Write-Report "=== [2/5] RUNNING PROCESSES & LOADED MODULES ===" 'Yellow'
Write-Report ""
Write-Report "NOTE: Launch the app before running for best results." 'Gray'
Write-Report ""

$matchedProcesses = Get-Process -ErrorAction SilentlyContinue | Where-Object {
    ($_.Name -match $ProcessMatch) -or 
    ($_.Path -and ($_.Path -match $SearchPattern))
}

if ($matchedProcesses) {
    Write-Report "Found $($matchedProcesses.Count) matching process(es):"
    Write-Report ""
    
    $moduleDirCounts = @{}
    
    foreach ($proc in $matchedProcesses) {
        $procPath = if ($proc.Path) { $proc.Path } else { "<unknown>" }
        Write-Report "  PID $($proc.Id): $($proc.Name) - $procPath"
        
        if ($proc.Path) {
            Add-ScanPath -Path $proc.Path -Source "Process:$($proc.Name)"
        }
        
        try {
            $modules = $proc.Modules
            foreach ($mod in $modules) {
                if ($mod.FileName) {
                    $dir = Split-Path -Path $mod.FileName -Parent
                    if ([string]::IsNullOrWhiteSpace($dir)) { continue }
                    
                    if ($moduleDirCounts.ContainsKey($dir)) {
                        $moduleDirCounts[$dir]++
                    } else {
                        $moduleDirCounts[$dir] = 1
                    }
                }
            }
        } catch {
            Write-Report "    [!] Cannot read modules for PID $($proc.Id): $($_.Exception.Message)" 'Red'
        }
    }
    
    Write-Report ""
    Write-Report "Loaded module directories (excluding Windows system paths):"
    Write-Report ""
    
    $sortedDirs = $moduleDirCounts.GetEnumerator() |
        Where-Object { $_.Key -notmatch '^C:\\Windows' } |
        Sort-Object -Property Value -Descending
    
    if ($sortedDirs) {
        foreach ($entry in $sortedDirs) {
            Write-Report ("  [{0,4} files] {1}" -f $entry.Value, $entry.Key)
            Add-ScanPath -Path $entry.Key -Source "LoadedModules"
        }
    } else {
        Write-Report "  (All loaded modules were from Windows system paths)" 'Gray'
    }
} else {
    Write-Report "  No matching processes currently running." 'Gray'
    Write-Report "  Launch the app and re-run this script for better coverage." 'Gray'
}

# ============================================================================
# METHOD 3: Windows Services
# ============================================================================

Write-Report ""
Write-Report "=== [3/5] WINDOWS SERVICES ===" 'Yellow'
Write-Report ""

$services = Get-CimInstance -ClassName Win32_Service -ErrorAction SilentlyContinue |
    Where-Object { 
        ($_.Name -match $SearchPattern) -or 
        ($_.DisplayName -match $SearchPattern) -or 
        ($_.PathName -match $SearchPattern) 
    }

if ($services) {
    foreach ($svc in $services) {
        $exePath = Resolve-ServiceExePath -PathName $svc.PathName
        
        Write-Report "Service:     $($svc.Name)"
        Write-Report "  Display:   $($svc.DisplayName)"
        Write-Report "  State:     $($svc.State)"
        Write-Report "  StartMode: $($svc.StartMode)"
        Write-Report "  ExePath:   $exePath"
        Write-Report ""
        
        if ($exePath) {
            Add-ScanPath -Path $exePath -Source "Service:$($svc.Name)"
        }
    }
} else {
    Write-Report "  No matching services found." 'Gray'
}

# ============================================================================
# METHOD 4: Kernel Drivers
# ============================================================================

Write-Report ""
Write-Report "=== [4/5] KERNEL DRIVERS ===" 'Yellow'
Write-Report ""

$drivers = Get-CimInstance -ClassName Win32_SystemDriver -ErrorAction SilentlyContinue |
    Where-Object { 
        ($_.Name -match $SearchPattern) -or 
        ($_.DisplayName -match $SearchPattern) -or 
        ($_.PathName -match $SearchPattern) 
    }

if ($drivers) {
    foreach ($drv in $drivers) {
        $resolvedPath = Resolve-DriverPath -RawPath $drv.PathName
        
        Write-Report "Driver:       $($drv.Name)"
        Write-Report "  Display:    $($drv.DisplayName)"
        Write-Report "  State:      $($drv.State)"
        Write-Report "  StartMode:  $($drv.StartMode)"
        Write-Report "  RawPath:    $($drv.PathName)"
        Write-Report "  Resolved:   $resolvedPath"
        Write-Report ""
        
        if ($resolvedPath) {
            Add-ScanPath -Path $resolvedPath -Source "Driver:$($drv.Name)"
        }
    }
} else {
    Write-Report "  No matching kernel drivers found." 'Gray'
}

# ============================================================================
# METHOD 5: File System Search
# ============================================================================

Write-Report ""
Write-Report "=== [5/5] FILE SYSTEM SEARCH ===" 'Yellow'
Write-Report ""

$searchRoots = @(
    'C:\Program Files'
    'C:\Program Files (x86)'
    'C:\ProgramData'
    'C:\Windows\System32\drivers'
)

foreach ($root in $searchRoots) {
    if (-not (Test-Path $root)) { continue }
    
    Write-Report "Searching: $root"
    
    # Search for matching directories
    $foundDirs = Get-ChildItem -Path $root -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match $SearchPattern }
    
    if ($foundDirs) {
        foreach ($dir in $foundDirs) {
            Write-Report "  Found: $($dir.FullName)"
            Add-ScanPath -Path $dir.FullName -Source "FileSystem:$root"
            
            # Show one level of sub-directories for context
            $subDirs = Get-ChildItem -Path $dir.FullName -Directory -ErrorAction SilentlyContinue
            foreach ($sub in $subDirs) {
                Write-Report "    Sub: $($sub.FullName)"
            }
        }
    }
    
    # Also search for matching .sys driver files when scanning drivers folder
    if ($root -eq 'C:\Windows\System32\drivers') {
        $driverFiles = Get-ChildItem -Path $root -File -Filter '*.sys' -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match $SearchPattern }
        
        foreach ($drv in $driverFiles) {
            Write-Report "  Driver file: $($drv.FullName)"
            Add-ScanPath -Path $drv.FullName -Source "FileSystem:DriverFile"
        }
    }
}

# ============================================================================
# CONSOLIDATED SCAN PATH LIST
# ============================================================================

Write-Report ""
Write-Report "================================================================" 'Green'
Write-Report "  RECOMMENDED SCAN PATHS FOR APPCONTROL MANAGER" 'Green'
Write-Report "================================================================" 'Green'
Write-Report ""

if ($discoveredPaths.Count -gt 0) {
    # Build ordered list for export
    $exportList = $discoveredPaths.GetEnumerator() |
        Sort-Object -Property Key |
        ForEach-Object {
            [PSCustomObject][ordered]@{
                Path    = $_.Key
                Sources = ($_.Value | Sort-Object -Unique) -join '; '
            }
        }
    
    foreach ($entry in $exportList) {
        Write-Report ""
        Write-Report "  PATH:    $($entry.Path)" 'Green'
        Write-Report "  SOURCES: $($entry.Sources)"
    }
    
    Write-Report ""
    Write-Report "Total unique scan paths: $($exportList.Count)" 'Cyan'
    
    # Export to CSV
    try {
        $exportList | Export-Csv -Path $pathsFile -NoTypeInformation -Encoding UTF8 -Force
        Write-Report ""
        Write-Report "Scan paths exported to CSV: $pathsFile" 'Cyan'
    } catch {
        Write-Report "ERROR exporting CSV: $($_.Exception.Message)" 'Red'
    }
} else {
    Write-Report "  No scan paths discovered." 'Red'
    Write-Report "  Verify the app is installed and the search pattern is correct." 'Red'
}

# ============================================================================
# FOOTER
# ============================================================================

Write-Report ""
Write-Report "================================================================" 'Cyan'
Write-Report "  DISCOVERY COMPLETE" 'Cyan'
Write-Report "================================================================" 'Cyan'
Write-Report "  Full report: $reportFile"
Write-Report "  Scan paths:  $pathsFile"
Write-Report "================================================================" 'Cyan'
Write-Report ""

# Open the output directory
Write-Host ""
Write-Host "Opening output directory..." -ForegroundColor Gray
Start-Process explorer.exe -ArgumentList $OutputDir