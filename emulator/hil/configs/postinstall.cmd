@echo off
:: Post-install script — runs on first login as `coolscan` (admin) via
:: FirstLogonCommands in Autounattend.xml. Installs everything the M15 HIL
:: needs, then shuts down so the host can snapshot.
::
:: Logged to C:\postinstall.log so failures can be triaged from the host
:: (mount the qcow2 read-only, libguestfs `virt-cat`, etc.).
::
:: Drives:
::   - C:\ ............ system
::   - virtio-win.iso . any CD-ROM letter (probed)
::   - postinstall.iso  any CD-ROM letter (probed; has COOLSCAN_POSTINSTALL.MARKER)

setlocal enabledelayedexpansion
set LOG=C:\postinstall.log
echo [%DATE% %TIME%] Starting post-install >> %LOG%

:: -------------------------------------------------------------------
:: Locate CD-ROM drives
:: -------------------------------------------------------------------
set PI=
set VIRTIO=
for %%d in (D E F G H I J K L M) do (
    if exist %%d:\COOLSCAN_POSTINSTALL.MARKER (
        set PI=%%d:
        echo [%DATE% %TIME%] post-install ISO at %%d: >> %LOG%
    )
    if exist %%d:\virtio-win-gt-x64.msi (
        set VIRTIO=%%d:
        echo [%DATE% %TIME%] virtio-win at %%d: >> %LOG%
    )
)
if "%PI%"=="" (
    echo [%DATE% %TIME%] FATAL: post-install ISO not found >> %LOG%
    goto :end
)
if "%VIRTIO%"=="" (
    echo [%DATE% %TIME%] FATAL: virtio-win.iso not found >> %LOG%
    goto :end
)

:: -------------------------------------------------------------------
:: Install drivers + agents
:: -------------------------------------------------------------------
echo [%DATE% %TIME%] Installing VirtIO drivers (silent) >> %LOG%
msiexec /i %VIRTIO%\virtio-win-gt-x64.msi /qn /norestart /l*v C:\virtio-install.log
echo [%DATE% %TIME%]   virtio-win-gt-x64 exit=%ERRORLEVEL% >> %LOG%

echo [%DATE% %TIME%] Installing qemu-guest-agent (silent) >> %LOG%
msiexec /i %VIRTIO%\guest-agent\qemu-ga-x86_64.msi /qn /norestart /l*v C:\qemu-ga-install.log
echo [%DATE% %TIME%]   qemu-ga exit=%ERRORLEVEL% >> %LOG%

echo [%DATE% %TIME%] Installing usbip-win2 (Inno Setup, silent) >> %LOG%
%PI%\USBip-x64.exe /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /LOG=C:\usbip-install.log
echo [%DATE% %TIME%]   usbip-win2 exit=%ERRORLEVEL% >> %LOG%

:: -------------------------------------------------------------------
:: System policy tweaks
:: -------------------------------------------------------------------
echo [%DATE% %TIME%] Disabling Windows Update >> %LOG%
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoUpdate /t REG_DWORD /d 1 /f >> %LOG% 2>&1

echo [%DATE% %TIME%] Disabling power saving (recipes need a constant display) >> %LOG%
powercfg /change monitor-timeout-ac 0 >> %LOG% 2>&1
powercfg /change monitor-timeout-dc 0 >> %LOG% 2>&1
powercfg /change standby-timeout-ac 0 >> %LOG% 2>&1
powercfg /change standby-timeout-dc 0 >> %LOG% 2>&1
powercfg /change hibernate-timeout-ac 0 >> %LOG% 2>&1
powercfg /change hibernate-timeout-dc 0 >> %LOG% 2>&1

echo [%DATE% %TIME%] Disabling Defender real-time scan >> %LOG%
powershell -ExecutionPolicy Bypass -Command "Set-MpPreference -DisableRealtimeMonitoring $true" >> %LOG% 2>&1

echo [%DATE% %TIME%] Configuring w32time NTP >> %LOG%
w32tm /config /manualpeerlist:"time.windows.com,0x9" /syncfromflags:manual /reliable:YES /update >> %LOG% 2>&1
net stop w32time >> %LOG% 2>&1
net start w32time >> %LOG% 2>&1
w32tm /resync >> %LOG% 2>&1

echo [%DATE% %TIME%] Creating C:\scans (NikonScan output dir) >> %LOG%
mkdir C:\scans 2>nul

:: -------------------------------------------------------------------
:: NikonScan 4.0.3 — try silent install. InstallShield 2003 honors /S
:: (and frequently /v"/qn" for the inner MSI). The Nikon Scan ISO ships
:: separate base / 4.0.2 / 4.0.3 installers; the 4.0.3 one is typically
:: a full installer, so we try that directly. Failure here is non-fatal:
:: operator can finish manually before the second snapshot.
:: -------------------------------------------------------------------
set "NIKON_SETUP=%PI%\NikonScan403\Nikon Scan 4.0.3\EN\Disk1\setup.exe"
echo [%DATE% %TIME%] Attempting NikonScan silent install >> %LOG%
echo [%DATE% %TIME%]   path: %NIKON_SETUP% >> %LOG%
if exist "%NIKON_SETUP%" (
    "%NIKON_SETUP%" /S /v"/qn /norestart"
    set NIKON_RC=!ERRORLEVEL!
    echo [%DATE% %TIME%]   NikonScan exit=!NIKON_RC! >> %LOG%
    if !NIKON_RC! EQU 0 (
        echo [%DATE% %TIME%]   NikonScan silent install reported success >> %LOG%
    ) else (
        echo [%DATE% %TIME%]   NikonScan silent install failed; manual install required >> %LOG%
    )
) else (
    echo [%DATE% %TIME%]   NikonScan setup.exe not found at "%NIKON_SETUP%" >> %LOG%
)

:: -------------------------------------------------------------------
:: Disable AutoLogon — only needed for FirstLogonCommands to fire
:: -------------------------------------------------------------------
echo [%DATE% %TIME%] Disabling AutoLogon >> %LOG%
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v AutoAdminLogon /t REG_SZ /d 0 /f >> %LOG% 2>&1

:: -------------------------------------------------------------------
:: Done — shut down so the host can snapshot
:: -------------------------------------------------------------------
echo [%DATE% %TIME%] Post-install complete; shutting down for snapshot >> %LOG%
shutdown /s /t 10 /c "Post-install complete; shutting down for snapshot"

:end
endlocal
