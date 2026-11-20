<#
.SYNOPSIS
    Re-applies the Windows and NVIDIA driver settings recorded in pc\README.md (captured 2026-11-20).

.DESCRIPTION
    Applies only settings that can be set safely from a script:
      - Power plan: High performance
      - Mouse: Enhance pointer precision off, pointer speed 10/20 (Windows default)
      - Game Mode on
      - Hardware-accelerated GPU scheduling on (needs admin + a reboot)
      - NVIDIA global driver settings, imported with NVIDIA Profile Inspector (only if you pass -ProfileInspector)
    It does not change display layout, refresh rates, scaling, monitor menus or Steam settings.
    pc\README.md lists those as a manual checklist, and the script prints it at the end.

    Preview first:   powershell -ExecutionPolicy Bypass -File .\pc\apply-pc-settings.ps1 -WhatIf
    Apply:           powershell -ExecutionPolicy Bypass -File .\pc\apply-pc-settings.ps1
    Run it from an elevated (Run as administrator) PowerShell so the HAGS step can run.

.PARAMETER ProfileInspector
    Path to nvidiaProfileInspector.exe. Download it from
    https://github.com/Orbmu2k/nvidiaProfileInspector/releases . The import REPLACES the driver's global
    (Base) profile with the 11 values in pc\nvidia\global-base-profile.nip.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$ProfileInspector
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2
$Here = $PSScriptRoot
$IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)

function Write-Step($msg) { Write-Host "`n== $msg" -ForegroundColor Cyan }
function Write-Note($msg) { Write-Host "   $msg" }
function Write-Warn($msg) { Write-Host "   ! $msg" -ForegroundColor Yellow }

function Set-RegValue([string]$path, [string]$name, $value, [string]$type = 'DWord') {
    $current = (Get-ItemProperty -Path $path -Name $name -ErrorAction SilentlyContinue)
    $now = if ($current) { $current.$name } else { '<unset>' }
    if ("$now" -eq "$value") { Write-Note "$name already $value"; return }
    if ($PSCmdlet.ShouldProcess("$path\$name", "set $now -> $value")) {
        if (-not (Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
        New-ItemProperty -Path $path -Name $name -Value $value -PropertyType $type -Force | Out-Null
        Write-Note "$name $now -> $value"
    }
}

# ------------------------------------------------------------------------------------------- power
Write-Step 'Power plan: High performance'
$HighPerf = '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'
$active = (powercfg /getactivescheme) -join ''
if ($active -match $HighPerf) {
    Write-Note 'already active'
} elseif ($PSCmdlet.ShouldProcess('power plan', 'activate High performance')) {
    # Fresh Windows 11 installs often hide High performance; recreate it from the built-in template.
    if (-not ((powercfg /list) -join '' -match $HighPerf)) { powercfg -duplicatescheme $HighPerf $HighPerf | Out-Null }
    powercfg /setactive $HighPerf
    Write-Note 'activated'
}

# ------------------------------------------------------------------------------------------- mouse
Write-Step 'Mouse: no acceleration, default pointer speed'
$m = 'HKCU:\Control Panel\Mouse'
Set-RegValue $m MouseSpeed '0' String
Set-RegValue $m MouseThreshold1 '0' String
Set-RegValue $m MouseThreshold2 '0' String
Set-RegValue $m MouseSensitivity '10' String
Write-Note '(takes effect after sign-out, or toggle it once in Settings > Bluetooth & devices > Mouse)'

# --------------------------------------------------------------------------------------- game mode
Write-Step 'Game Mode on'
Set-RegValue 'HKCU:\Software\Microsoft\GameBar' AutoGameModeEnabled 1

# ---------------------------------------------------------------------------------------------- HAGS
Write-Step 'Hardware-accelerated GPU scheduling on'
if ($IsAdmin) {
    Set-RegValue 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' HwSchMode 2
    Write-Note '(needs a reboot if it changed)'
} else {
    Write-Warn 'Skipped: not running as administrator. Or set it in Settings > System > Display > Graphics > Advanced graphics settings.'
}

# -------------------------------------------------------------------------------------------- NVIDIA
Write-Step 'NVIDIA global driver settings'
$nip = Join-Path $Here 'nvidia\global-base-profile.nip'
if ($ProfileInspector) {
    if (-not (Test-Path $ProfileInspector)) { throw "Not found: $ProfileInspector" }
    if ($PSCmdlet.ShouldProcess('NVIDIA Base (global) profile', "import $nip")) {
        $p = Start-Process -FilePath $ProfileInspector -ArgumentList @('-silentImport', "`"$nip`"") -Wait -PassThru
        Write-Note "NVIDIA Profile Inspector exit code $($p.ExitCode). Open it and check the Base Profile shows the values in pc\README.md."
    }
} else {
    Write-Warn 'Not imported (no -ProfileInspector given). Either:'
    Write-Note '  1. Download NVIDIA Profile Inspector: https://github.com/Orbmu2k/nvidiaProfileInspector/releases'
    Write-Note "  2. Run: nvidiaProfileInspector.exe -silentImport `"$nip`""
    Write-Note '  or set the values by hand in NVIDIA Control Panel (table in pc\README.md).'
}

# ------------------------------------------------------------------------------------ manual steps
Write-Step 'Manual steps (see pc\README.md for details)'
@(
    'Display: VG259QM at 1920x1080 279.857 Hz, Dell S3220DGF at 2560x1440 164 Hz (both are set by hand, Windows defaults to 60 Hz).',
    'NVIDIA Control Panel > Adjust desktop size and position > VG259QM: Full-screen scaling + override games (for 4:3 stretched).',
    'NVIDIA Control Panel > Set up G-SYNC: enable for full screen and windowed mode on the VG259QM.',
    'Monitor menu (VG259QM): Adaptive-Sync on, ELMB Sync on.',
    'Steam > Settings > Game Recording: Record in background. In-game overlay on.'
) | ForEach-Object { Write-Note "- $_" }
Write-Host "`nDone." -ForegroundColor Green
