# Set-BitLockerPIN-UserPrompt.ps1
# Run in user context via Intune Win32 app or logon script.

$ErrorActionPreference = 'Stop'
$osDrive = $env:SystemDrive

# Skip if PIN already configured
$protectors = (Get-BitLockerVolume -MountPoint $osDrive).KeyProtector.KeyProtectorType
if ($protectors -contains 'TpmPin' -or $protectors -contains 'TpmPinStartupKey') {
    Write-Output "TPM+PIN already configured. Exiting."
    exit 0
}

Add-Type -AssemblyName Microsoft.VisualBasic
do {
    $pin1 = [Microsoft.VisualBasic.Interaction]::InputBox(
        "Set a BitLocker startup PIN (6+ characters, alphanumeric allowed).`n`nYou will enter this each time you power on your device.",
        "SOE Security - BitLocker PIN Setup", "")

    if ($pin1.Length -lt 6) {
        [System.Windows.Forms.MessageBox]::Show("PIN must be at least 6 characters.")
        continue
    }

    $pin2 = [Microsoft.VisualBasic.Interaction]::InputBox(
        "Confirm PIN.", "SOE Security - BitLocker PIN Setup", "")

} while ($pin1 -ne $pin2)

$securePin = ConvertTo-SecureString $pin1 -AsPlainText -Force

# Remove TPM-only protector, add TPM+PIN
$tpmProtector = (Get-BitLockerVolume -MountPoint $osDrive).KeyProtector |
                Where-Object { $_.KeyProtectorType -eq 'Tpm' }

Add-BitLockerKeyProtector -MountPoint $osDrive -TpmAndPinProtector -Pin $securePin
Remove-BitLockerKeyProtector -MountPoint $osDrive -KeyProtectorId $tpmProtector.KeyProtectorId

# Force recovery key re-escrow to Entra
$recoveryProtector = (Get-BitLockerVolume -MountPoint $osDrive).KeyProtector |
                     Where-Object { $_.KeyProtectorType -eq 'RecoveryPassword' }
BackupToAAD-BitLockerKeyProtector -MountPoint $osDrive -KeyProtectorId $recoveryProtector.KeyProtectorId

Write-Output "TPM+PIN configured successfully."