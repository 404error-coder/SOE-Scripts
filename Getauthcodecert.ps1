# C2R VFS root for common files
$vfsPaths = @(
    "${env:ProgramFiles}\Microsoft Office\root\VFS\ProgramFilesCommonX86\Microsoft Shared\Smart Tag",
    "${env:ProgramFiles}\Microsoft Office\root\VFS\ProgramFilesCommonX64\Microsoft Shared\Smart Tag",
    "${env:ProgramFiles}\Microsoft Office\root\VFS\ProgramFilesCommon\Microsoft Shared\Smart Tag"
)

foreach ($p in $vfsPaths) {
    if (Test-Path $p) {
        Write-Host "Found: $p" -ForegroundColor Green
        Get-ChildItem $p -Filter *.dll | Select Name, Length
    }
}


#Broad Search
Get-ChildItem -Path "${env:ProgramFiles}\Microsoft Office\root" -Recurse -Filter "MOFL.DLL" -ErrorAction SilentlyContinue | Select FullName


#Authenticode extract
$moflPath = # paste the actual path from above
$sig = Get-AuthenticodeSignature $moflPath
$sig | Format-List *
$sig.SignerCertificate | Format-List Subject, Issuer, Thumbprint, NotAfter