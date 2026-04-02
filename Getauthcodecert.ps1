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


$vfsPath = "PASTE_YOUR_VFS_SMART_TAG_FOLDER_PATH"
Get-ChildItem "$vfsPath\*.dll" | ForEach-Object {
    $sig = Get-AuthenticodeSignature $_.FullName
    [PSCustomObject]@{
        File       = $_.Name
        Thumbprint = $sig.SignerCertificate.Thumbprint
    }
} | Format-Table -AutoSize


$vfsPath = "PASTE_YOUR_VFS_SMART_TAG_FOLDER_PATH"

$certs = Get-ChildItem "$vfsPath\*.dll" | ForEach-Object {
    $sig = Get-AuthenticodeSignature $_.FullName
    $sig.SignerCertificate
} | Where-Object { $_ } | Sort-Object Thumbprint -Unique

$i = 1
foreach ($cert in $certs) {
    $b64 = [System.Convert]::ToBase64String($cert.Export('Cert'))
    $guid = [guid]::NewGuid().ToString()
    
    Write-Host "=== CERTIFICATE $i ===" -ForegroundColor Cyan
    Write-Host "Subject:     $($cert.Subject)"
    Write-Host "Thumbprint:  $($cert.Thumbprint)"
    Write-Host "Expires:     $($cert.NotAfter)"
    Write-Host ""
    Write-Host "OMA-URI:"
    Write-Host "./Device/Vendor/MSFT/RootCATrustedCertificates/TrustedPublisher/$guid/EncodedCertificate"
    Write-Host ""
    Write-Host "BASE64 VALUE:" -ForegroundColor Yellow
    Write-Host $b64
    Write-Host ""
    Write-Host ("=" * 60)
    Write-Host ""
    $i++
}


#VSTOEE
$vstoPath = Get-ChildItem -Path "${env:ProgramFiles}\Microsoft Office\root" -Recurse -Filter "vstoee.dll" -ErrorAction SilentlyContinue | Select -First 1 -ExpandProperty FullName

if ($vstoPath) {
    $sig = Get-AuthenticodeSignature $vstoPath
    Write-Host "Path:        $vstoPath"
    Write-Host "Thumbprint:  $($sig.SignerCertificate.Thumbprint)"
    Write-Host "Subject:     $($sig.SignerCertificate.Subject)"
} else {
    Write-Warning "vstoee.dll not found under C2R root"
}