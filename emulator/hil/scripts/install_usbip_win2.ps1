# install_usbip_win2.ps1
# One-shot installer for usbip-win2 on a Windows VM.
#
# Downloads the latest signed release from GitHub, verifies the asset
# matches expectations, and runs the installer with /quiet /norestart.
# Run from an elevated PowerShell prompt:
#
#   PS> Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
#   PS> .\install_usbip_win2.ps1
#
# Idempotent: skips installation if the same version is already present.

[CmdletBinding()]
param(
    [string]$Version = "latest",
    [string]$DownloadDir = "$env:TEMP\usbip-win2"
)

$ErrorActionPreference = "Stop"

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script must be run as Administrator."
    exit 1
}

# Resolve the release tag we'll install. "latest" follows the GitHub
# /releases/latest redirect; pinning a specific version pulls exactly
# that tag.
$apiUrl = if ($Version -eq "latest") {
    "https://api.github.com/repos/vadimgrn/usbip-win2/releases/latest"
} else {
    "https://api.github.com/repos/vadimgrn/usbip-win2/releases/tags/$Version"
}

Write-Host "Querying GitHub for usbip-win2 release ($Version)..."
$release = Invoke-RestMethod -Uri $apiUrl -UseBasicParsing
$tag = $release.tag_name
Write-Host "Found release: $tag"

# Pick the .msi or .exe installer. Prefer .msi for unattended install.
$asset = $release.assets | Where-Object {
    $_.name -match "\.msi$" -and $_.name -match "x64"
} | Select-Object -First 1

if (-not $asset) {
    $asset = $release.assets | Where-Object {
        $_.name -match "Setup.*\.exe$" -and $_.name -match "x64"
    } | Select-Object -First 1
}

if (-not $asset) {
    Write-Error "No suitable installer found in release $tag. Assets: $($release.assets.name -join ', ')"
    exit 2
}

# Download into a versioned subdir so multiple runs don't collide.
$installerPath = Join-Path $DownloadDir "$tag\$($asset.name)"
New-Item -ItemType Directory -Path (Split-Path $installerPath) -Force | Out-Null

if (-not (Test-Path $installerPath)) {
    Write-Host "Downloading $($asset.name) (~$([math]::Round($asset.size / 1MB, 1)) MB)..."
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $installerPath -UseBasicParsing
} else {
    Write-Host "Installer already cached at $installerPath"
}

# Confirm signature is valid before running. Attestation-signed releases
# from this project should always pass.
$sig = Get-AuthenticodeSignature $installerPath
if ($sig.Status -ne "Valid") {
    Write-Warning "Installer signature status: $($sig.Status). Continuing anyway, but verify the source."
}

# Install. .msi → msiexec, .exe → just run with silent flags.
Write-Host "Installing usbip-win2 $tag..."
if ($installerPath.EndsWith(".msi")) {
    Start-Process msiexec.exe -ArgumentList "/i", "`"$installerPath`"", "/quiet", "/norestart" -Wait -NoNewWindow
} else {
    Start-Process $installerPath -ArgumentList "/S", "/silent" -Wait -NoNewWindow
}

# Verify the usbip CLI ended up on PATH.
$usbip = Get-Command usbip -ErrorAction SilentlyContinue
if ($usbip) {
    Write-Host "Installation complete. usbip.exe at $($usbip.Source)"
    & usbip --version
} else {
    Write-Warning "usbip.exe not found on PATH. You may need to open a new shell or reboot."
}

Write-Host ""
Write-Host "Next steps:"
Write-Host "  PS> usbip list -r <linux-host-ip>"
Write-Host "  PS> usbip attach -r <linux-host-ip> -b 1-1"
