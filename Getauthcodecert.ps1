# Export the cert from one of the signed DLLs
$sig = Get-AuthenticodeSignature "C:\Program Files\Common Files\Microsoft Shared\Smart Tag\MOFL.DLL"
$cert = $sig.SignerCertificate
$bytes = $cert.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cer)
[System.Convert]::ToBase64String($bytes) | Set-Clipboard