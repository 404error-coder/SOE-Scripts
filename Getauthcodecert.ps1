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

#Base64
$sig = Get-AuthenticodeSignature "PASTE_THE_VFS_PATH_TO_MOFL.DLL"
if ($sig.SignerCertificate) {
    $bytes = $sig.SignerCertificate.Export('Cert')
    $b64 = [System.Convert]::ToBase64String($bytes)
    $b64 | Set-Clipboard
    Write-Host "Base64 copied to clipboard — Thumbprint: $($sig.SignerCertificate.Thumbprint)" -ForegroundColor Green
} else {
    Write-Warning "No signer certificate found — check the file path"
}