<#
.SYNOPSIS
    WDAC Supplemental Policy - App Discovery Script
.DESCRIPTION
    Discovers all file system locations for a given app to inform WDAC
    supplemental policy scan paths. Outputs to console and exports to file.
.NOTES
    Run as Administrator on a device with the target app installed.
    Launch the app before running for best results (captures loaded modules).
#>

# ============================================================================
# CONFIGURATION - Change these for each app
# ============================================================================

$AppName       = "VMwareHorizon"                # Short name for output files
$SearchPattern = 'VMware|Horizon'               # Regex pattern to match app
$ProcessMatch  = 'vmware|horizon|vmware-view'   # Regex to match running processes
$OutputDir     = "C:\Temp\WDAC\Discovery"       # Where to save output

# Examples for your other apps:
# $AppName = "JanusSeal";  $SearchPattern = 'Janus';             $ProcessMatch = 'janus|jsoutlook|js4office'
# $AppName = "ControlUp";  $SearchPattern = 'ControlUp|Smart-X'; $ProcessMatch = 'cuAgent|controlup|smart-x'

# ============================================================================
# SETUP
# ============================================================================

$ErrorActionPreference = 'SilentlyContinue'

if (-not (Test-Path $OutputDir)) {
    New-Item -Path $OutputDir -ItemType Directory -Force | Out-Null
}

$timestamp   = Get-Date -Format "yyyyMMdd_HHmmss"
$reportFile  = Join-Path $OutputDir "$($AppName)_Discovery_$timestamp.txt"
$pathsFile   = Join-Path $OutputDir "$($AppName)_ScanPaths_$timestamp.csv"
$allPaths    = [System.Collections.Generic.List[string]]::new()

# Helper to write to both console and file
function Write-Report {
    param([string]$Text, [string]$Color = 'White')
    Write-Host $Text -ForegroundColor $Color
    Add-Content -Path $reportFile -Value $Text
}

function Add-ScanPath {
    param([string]$Path, [string]$Source)
    if ([string]::IsNullOrWhiteSpace($Path)) { return }
    if (-not (Test-Path $Path)) { return }
    
    # Normalise to directory
    $dir = if ((Get-Item $Path -ErrorAction SilentlyContinue).PSIsContainer) {
        $Path
    } else {
        Split-Path $Path -Parent
    }
    
    # Exclude Windows system paths (covered by Allow Microsoft base)
    $excludePatterns = @(
        '^C:\\Windows\\System32$',
        '^C:\\Windows\\SysWOW64$',
        '^C:\\Windows\\WinSxS',
        '^C:\\Windows\\Installer',
        '^C:\\Windows\\assembly',
        '\\Logs$',
        '\\Logs\\',
        '\\Cache$',
        '\\Cache\\',
        '\\Temp$',
        '\\Temp\\'
    )
    
    foreach ($pattern in $excludePatterns) {
        if ($dir -match $pattern) { return }
    }
    
    $allPaths.Add([PSCustomObject]@{
        Path   = $dir
        Source = $Source
    })
}

# ============================================================================
# HEADER
# ============================================================================

Write-Report ""
Write-Report "================================================================" 'Cyan'
Write-Report "  WDAC APP DISCOVERY REPORT" 'Cyan'
Write-Report "================================================================" 'Cyan'
Write-Report "  App Name:        $AppName"
Write-Report "  Search Pattern:  $SearchPattern"
Write-Report "  Process Match:   $ProcessMatch"
Write-Report "  Generated:       $(Get-Date)"
Write-Report "  Computer:        $env:COMPUTERNAME"
Write-Report "================================================================" 'Cyan'
Write-Report ""

# ============================================================================
# METHOD 1: Registry Uninstall Keys
# ============================================================================

Write-Report ""
Write-Report "=== [1/5] REGISTRY UNINSTALL KEYS ===" 'Yellow'
Write-Report ""

$uninstallKeys = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
)

$installedApps = Get-ItemProperty $uninstallKeys -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName -match $SearchPattern }

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

$matchedProcesses = Get-Process | Where-Object {
    ($_.Name -match $ProcessMatch) -or 
    ($_.Path -and $_.Path -match $SearchPattern)
}

if ($matchedProcesses) {
    Write-Report "Found $($matchedProcesses.Count) matching process(es):"
    Write-Report ""
    
    $moduleDirs = @{}
    
    foreach ($proc in $matchedProcesses) {
        Write-Report "  PID $($proc.Id): $($proc.Name) - $($proc.Path)"
        
        if ($proc.Path) {
            Add-ScanPath -Path $proc.Path -Source "Process:$($proc.Name)"
        }
        
        try {
            foreach ($mod in $proc.Modules) {
                if ($mod.FileName) {
                    $dir = Split-Path $mod.FileName -Parent
                    if ($moduleDirs.ContainsKey($dir)) {
                        $moduleDirs[$dir]++
                    } else {
                        $moduleDirs[$dir] = 1
                    }
                }
            }
        } catch {
            Write-Report "    [!] Cannot read modules for PID $($proc.Id) - $($_.Exception.Message)" 'Red'
        }
    }
    
    Write-Report ""
    Write-Report "Loaded module directories (excluding Windows system paths):"
    Write-Report ""
    
    $moduleDirs.GetEnumerator() | 
        Where-Object { $_.Key -notmatch '^C:\\Windows' } |
        Sort-Object Value -Descending |
        ForEach-Object {
            Write-Report ("  [{0,4} files] {1}" -f $_.Value, $_.Key)
            Add-ScanPath -Path $_.Key -Source "LoadedModules"
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
        # Extract exe path from PathName (handles quoted paths with arguments)
        $exePath = if ($svc.PathName -match '^"([^"]+)"') { 
            $matches[1] 
        } elseif ($svc.PathName -match '^(\S+)') {
            $matches[1]
        } else {
            $svc.PathName
        }
        
        Write-Report "Service:    $($svc.Name)"
        Write-Report "  Display:  $($svc.DisplayName)"
        Write-Report "  State:    $($svc.State)"
        Write-Report "  StartMode:$($svc.StartMode)"
        Write-Report "  ExePath:  $exePath"
        Write-Report ""
        
        Add-ScanPath -Path $exePath -Source "Service:$($svc.Name)"
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
        Write-Report "Driver:     $($drv.Name)"
        Write-Report "  Display:  $($drv.DisplayName)"
        Write-Report "  State:    $($drv.State)"
        Write-Report "  StartMode:$($drv.StartMode)"
        Write-Report "  Path:     $($drv.PathName)"
        Write-Report ""
        
        Add-ScanPath -Path $drv.PathName -Source "Driver:$($drv.Name)"
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
    'C:\Program Files',
    'C:\Program Files (x86)',
    'C:\ProgramData',
    'C:\Windows\System32\drivers'
)

foreach ($root in $searchRoots) {
    if (-not (Test-Path $root)) { continue }
    
    Write-Report "Searching: $root"
    
    $matches = Get-ChildItem -Path $root -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match $SearchPattern }
    
    if ($matches) {
        foreach ($match in $matches) {
            Write-Report "  Found: $($match.FullName)"
            Add-ScanPath -Path $match.FullName -Source "FileSystem:$root"
            
            # Also check one level deeper for nested vendor folders
            $subDirs = Get-ChildItem -Path $match.FullName -Directory -ErrorAction SilentlyContinue
            foreach ($sub in $subDirs) {
                Write-Report "    Sub:   $($sub.FullName)"
            }
        }
    }
    
    # Also search for files matching the pattern in drivers folder
    if ($root -eq 'C:\Windows\System32\drivers') {
        $driverFiles = Get-ChildItem -Path $root -File -Filter "*.sys" -ErrorAction SilentlyContinue |
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

$uniquePaths = $allPaths | 
    Group-Object Path | 
    ForEach-Object {
        [PSCustomObject]@{
            Path    = $_.Name
            Sources = ($_.Group.Source | Sort-Object -Unique) -join '; '
            Count   = $_.Count
        }
    } |
    Sort-Object Path

if ($uniquePaths) {
    foreach ($p in $uniquePaths) {
        Write-Report ""
        Write-Report "  PATH:    $($p.Path)" 'Green'
        Write-Report "  SOURCES: $($p.Sources)"
    }
    
    Write-Report ""
    Write-Report "Total unique scan paths: $($uniquePaths.Count)" 'Cyan'
    
    # Export to CSV
    $uniquePaths | Export-Csv -Path $pathsFile -NoTypeInformation
    Write-Report ""
    Write-Report "Scan paths exported to CSV: $pathsFile" 'Cyan'
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