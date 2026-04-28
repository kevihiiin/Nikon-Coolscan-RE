#!/usr/bin/env bash
# install_driver_in_vm.sh — bind the Coolscan kernel driver to the LS-50 in the
# Win11 IoT LTSC VM, idempotent.
#
# Strategy
# --------
# Win11 x64 won't match Nikon's 2003 NksUSB.INF because that INF is missing the
# NTamd64 architecture decoration. Plain pnputil also rejects unsigned INFs.
# The transparent fix (NikonScan still uses its own NKDUSCAN.dll → usbscan.sys
# stack unmodified): generate a minimally-modified INF with NTamd64 sections,
# self-sign the catalog with a test cert that we add to TrustedPublisher, then
# pnputil installs it cleanly. Test mode (`bcdedit /set testsigning on`) plus
# Secure Boot off are required for the runtime kernel to load the driver — both
# are part of the VM's persistent BCD/nvram state.
#
# Prereqs (one-time, captured in the `driver-bound` snapshot)
# ----------------------------------------------------------
#   * Secure Boot disabled in libvirt domain XML (loader OVMF_CODE_4M.fd, no MS keys)
#   * `bcdedit /set testsigning on` + `bcdedit /set nointegritychecks on`
#   * NikonScan 4.0.3 already installed (so NKScnUSD.dll is at the expected path)
#   * usbip-win2 already installed
#   * qemu-guest-agent reachable via /tmp/vm-exec.sh
#
# Usage:
#   /tmp/vm-exec.sh "$(cat install_driver_in_vm.sh | sed -n '/^cat <<.PS_SCRIPT./,/^PS_SCRIPT$/{ /^PS_SCRIPT$/!{ /^cat /!p } }')"
# (or copy the PS_SCRIPT inline block out by hand)
#
# Verification: device shows in Get-PnpDevice with Status=OK, Service=usbscan,
# Problem=CM_PROB_NONE. Snapshot before this script: `nikonscan-installed`.
# Snapshot after this script: `driver-bound`.

set -euo pipefail

VM=${VM:-win10-ltsc-nikonscan}

PS_SCRIPT=$(cat <<'PS_SCRIPT'
$ErrorActionPreference = "Stop"
$dir = "C:\Coolscan-Driver"
New-Item -Path $dir -ItemType Directory -Force | Out-Null

# 1. Stage the user-mode DLL the INF references.
Copy-Item "C:\Program Files (x86)\Common Files\Nikon\Driver\ScanUSB\NKScnUSD.dll" "$dir\NKScnUSD.dll" -Force

# 2. Write our minimally-modified INF with NTamd64 decoration.
#    Differences from Nikon's NksUSB.INF:
#    - Signature changed from $CHICAGO$ to $Windows NT$
#    - [Manufacturer] declares NTamd64 architecture
#    - [DeviceModels.NTamd64] section added with VID/PID matches
#    - CatalogFile points at our self-signed NksUSB-Win11.cat
#    - Removed [NKUSBSCN.CopyUSBFiles] (usbscan.sys is already in System32 from sti.inf)
$inf = @'
; NksUSB-Win11.INF -- amd64-decorated install for Nikon Coolscan over USB/IP
; Original (c) Nikon 2003. Modifications for Win11 x64 (c) Coolscan-RE project.

[Version]
Signature="$Windows NT$"
Class=Image
ClassGUID={6bdd1fc6-810f-11d0-bec7-08002be2092f}
Provider=%NikonStr%
DriverVer=04/28/2026,4.0.0.1
CatalogFile=NksUSB-Win11.cat

[ControlFlags]
ExcludeFromSelect=*

[Manufacturer]
%NikonStr%=DeviceModels,NTamd64

[DeviceModels.NTamd64]
%DeviceDescLS0040%=NKUSBSCN.Install,USB\VID_04B0&PID_4000
%DeviceDescLS0050%=NKUSBSCN.Install,USB\VID_04B0&PID_4001
%DeviceDescLS5000%=NKUSBSCN.Install,USB\VID_04B0&PID_4002

[NKUSBSCN.Install]
Include=sti.inf
Needs=STI.USBSection
SubClass=StillImage
DeviceType=1
DeviceSubType=0x4000
Capabilities=0
AddReg=NKUSBSCN.AddReg
CopyFiles=NKUSBSCN.CopyUSDFiles

[NKUSBSCN.Install.Services]
Include=sti.inf
Needs=STI.USBSection.Services

[NKUSBSCN.AddReg]
HKR,,HardwareConfig,1,4
HKR,,DevLoader,,*NTKERN
HKR,,NTMPDriver,,usbscan.sys
HKR,DeviceData,ICMProfile,1,0,0
HKR,,USDClass,,"{07C71AC0-FA90-11d3-B409-00C04F87578E}"
HKCR,CLSID\{07C71AC0-FA90-11d3-B409-00C04F87578E},,,"Nikon STI USD"
HKCR,CLSID\{07C71AC0-FA90-11d3-B409-00C04F87578E}\InProcServer32,,,%11%\NKSCNUSD.dll
HKCR,CLSID\{07C71AC0-FA90-11d3-B409-00C04F87578E}\InProcServer32,ThreadingModel,,"Both"

[SourceDisksNames]
1=%DiskName%,,

[SourceDisksFiles]
NKSCNUSD.dll=1

[DestinationDirs]
NKUSBSCN.CopyUSDFiles=11

[NKUSBSCN.CopyUSDFiles]
NKSCNUSD.dll

[Strings]
NikonStr="Nikon Corporation"
DiskName="Coolscan RE Modified Driver"
DeviceDescLS0040="Nikon COOLSCAN IV ED"
DeviceDescLS0050="Nikon COOLSCAN V ED (Coolscan-RE)"
DeviceDescLS5000="Nikon SUPER COOLSCAN 5000 ED"
'@
$inf | Out-File -Encoding ascii -FilePath "$dir\NksUSB-Win11.inf"

# 3. Get-or-create a self-signed code-signing cert and trust it.
$certName = "CN=Coolscan-RE Test CA"
$cert = Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object Subject -eq $certName | Select-Object -First 1
if (-not $cert) {
    $cert = New-SelfSignedCertificate -Subject $certName `
        -CertStoreLocation Cert:\LocalMachine\My `
        -KeyUsage DigitalSignature `
        -Type CodeSigningCert `
        -KeyAlgorithm RSA -KeyLength 2048 `
        -NotAfter (Get-Date).AddYears(5) `
        -HashAlgorithm SHA256
}
foreach ($store in "Root","TrustedPublisher") {
    $s = New-Object System.Security.Cryptography.X509Certificates.X509Store($store,"LocalMachine")
    $s.Open("ReadWrite")
    if (-not ($s.Certificates | Where-Object Thumbprint -eq $cert.Thumbprint)) { $s.Add($cert) }
    $s.Close()
}

# 4. Generate the catalog and sign it with the test cert.
#    PowerShell 5+ ships New-FileCatalog so no SDK install is required.
$catPath = "$dir\NksUSB-Win11.cat"
Remove-Item $catPath -ErrorAction SilentlyContinue
New-FileCatalog -Path $dir -CatalogFilePath $catPath -CatalogVersion 2.0 | Out-Null
$sig = Set-AuthenticodeSignature -FilePath $catPath -Certificate $cert -HashAlgorithm SHA256
if ($sig.Status -ne "Valid") { throw "catalog signing failed: $($sig.StatusMessage)" }

# 5. Install. pnputil verifies the cat hash list against the INF; with our cat,
#    that succeeds. The cert is in TrustedPublisher so kernel signing accepts it
#    once testsigning is on.
Start-Sleep -Seconds 2  # wait for any file locks from cat generation
pnputil /add-driver "$dir\NksUSB-Win11.inf" /install

# 6. Verify.
$dev = Get-PnpDevice -PresentOnly | Where-Object HardwareID -match "VID_04B0&PID_4001"
if (-not $dev -or $dev.Status -ne "OK") {
    Write-Output "WARNING: device not bound; current state:"
    $dev | Format-List FriendlyName, Status, Service, Problem
    exit 2
}
Write-Output ("DRIVER BOUND: " + $dev.FriendlyName + " (Service=" + $dev.Service + ")")
PS_SCRIPT
)

/tmp/vm-exec.sh "$PS_SCRIPT"
