<#
.SYNOPSIS
    Restores my TF2 and CS2 setup on a fresh Windows PC.

.DESCRIPTION
    1. Downloads the third-party mods (mastercomfig, budhud, two GameBanana VPKs).
       By default it takes the NEWEST version of each. If a lookup fails it falls back to the
       exact version that was installed when this backup was made (see $Sources below).
    2. Copies my own files from this repo on top (cfgs, HUD edits, CS2 settings).
    3. Imports TF2's video settings into the registry.
    4. Prints the Steam launch options and copies the TF2 ones to the clipboard.

    Everything it overwrites is first copied to %LOCALAPPDATA%\game-configs-backup\<timestamp>.

    Install TF2 and CS2 through Steam first, launch each once, then close Steam and run:
        powershell -ExecutionPolicy Bypass -File .\restore.ps1

.PARAMETER Game
    All (default), TF2 or CS2.
.PARAMETER Pinned
    Install the exact mod versions from this backup instead of the newest ones.
.PARAMETER SteamId3
    Folder name under Steam\userdata to restore into. Default: the most recently used account.
.PARAMETER Force
    Run even while Steam is open (Steam Cloud may then overwrite the restored files).
.PARAMETER TF2Dir / CS2Dir / SteamUserDir
    Override the detected folders (mainly for testing into a scratch folder).
#>
[CmdletBinding()]
param(
    [ValidateSet('All', 'TF2', 'CS2')][string]$Game = 'All',
    [switch]$Pinned,
    [string]$SteamId3,
    [switch]$SkipRegistry,
    [switch]$Force,
    [string]$TF2Dir,
    [string]$CS2Dir,
    [string]$SteamUserDir
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$Repo = $PSScriptRoot
$Headers = @{ 'User-Agent' = 'game-configs-restore' }
$Stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$BackupRoot = Join-Path $env:LOCALAPPDATA "game-configs-backup\$Stamp"
$Work = Join-Path $env:TEMP "game-configs-$Stamp"

# ---------------------------------------------------------------------------------------------
# External sources. "pinned" = what was installed when this backup was taken (2026-11-20),
# used with -Pinned or when the newest-version lookup fails. sha256 is checked for pinned files.
# ---------------------------------------------------------------------------------------------
$Sources = @{
    Mastercomfig = @{
        Repo    = 'mastercomfig/mastercomfig'           # https://github.com/mastercomfig/mastercomfig
        Version = '9.100.1'
        Assets  = [ordered]@{
            'mastercomfig-base.vpk'                          = 'cdabc8251864a1ab2ef7f7ffed1b44f52810956e476d62183b8d7e3e960d8650'
            'mastercomfig-addon-flat-mouse.vpk'              = '990929c47367d99fab8b2b3bb34a5b0558891e442751c9e4d2bdafa3c4151bad'
            'mastercomfig-addon-no-tutorial.vpk'             = '42c315475260071bebcfa2f8cdbfbfacc555d708f249473cbdb8fdf543cceac3'
            'mastercomfig-addon-null-canceling-movement.vpk' = '077a479fcd25311378ab9845fc94807730cb4e7ca1ecc35b63331446b6265f15'
        }
    }
    Budhud       = @{
        Repo      = 'rbjaxter/budhud'                   # https://github.com/rbjaxter/budhud
        PinnedRef = '16f7be2bb4f0dcbe46ec5f444486ab6a6ea4c7e6'   # release 2511_01 + one README commit
    }
    GameBanana   = @(
        @{ Name = "Tiago's No explosion smoke script"; ModId = 678380; PinnedDl = 1705517
           Vpk  = 'tiago_no_explosion_smoke.vpk'; Sha256 = 'ff7be95ef9580b38331c9fa7e247ba429ee57ef322197ea7a6cac3d5fe595417' }
        @{ Name = 'Rocket + Sticky Jumper remove explosion smoke'; ModId = 646386; PinnedDl = 1603165
           Vpk  = 'noJumperSmoke.vpk'; Sha256 = '78c6d20df6d54058e4a453fb3d1723580f17af569d954c4961dfbc1117e8a2da' }
    )
}

$LaunchOptions = @{
    TF2 = '-novid -nojoy -nosteamcontroller -nohltv -particles 1'
    CS2 = ''
}

# --------------------------------------------------------------------------------- helpers ---
function Write-Step($msg) { Write-Host "`n== $msg" -ForegroundColor Cyan }
function Write-Note($msg) { Write-Host "   $msg" }
function Write-Warn($msg) { Write-Host "   ! $msg" -ForegroundColor Yellow }

function Get-SteamPath {
    $p = (Get-ItemProperty 'HKCU:\Software\Valve\Steam' -Name SteamPath -ErrorAction SilentlyContinue).SteamPath
    if (-not $p) { throw 'Steam is not installed (HKCU\Software\Valve\Steam\SteamPath missing).' }
    return [IO.Path]::GetFullPath($p)
}

# Finds an installed game through Steam's library list and the game's appmanifest.
function Get-GameDir([string]$steam, [int]$appId) {
    $vdf = Join-Path $steam 'steamapps\libraryfolders.vdf'
    $libs = @($steam)
    if (Test-Path $vdf) {
        $libs += [regex]::Matches((Get-Content $vdf -Raw), '"path"\s+"([^"]+)"') |
            ForEach-Object { $_.Groups[1].Value -replace '\\\\', '\' }
    }
    foreach ($lib in ($libs | Select-Object -Unique)) {
        $acf = Join-Path $lib "steamapps\appmanifest_$appId.acf"
        if (Test-Path $acf) {
            $m = [regex]::Match((Get-Content $acf -Raw), '"installdir"\s+"([^"]+)"')
            if ($m.Success) {
                $dir = Join-Path $lib "steamapps\common\$($m.Groups[1].Value)"
                if (Test-Path $dir) { return $dir }
            }
        }
    }
    return $null
}

function Get-SteamUserDir([string]$steam) {
    $root = Join-Path $steam 'userdata'
    if ($SteamId3) {
        $d = Join-Path $root $SteamId3
        if (-not (Test-Path $d)) { throw "No Steam userdata folder for account $SteamId3." }
        return $d
    }
    $latest = Get-ChildItem $root -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '^\d+$' -and $_.Name -ne '0' } |
        ForEach-Object { $cfg = Join-Path $_.FullName 'config\localconfig.vdf'
                         if (Test-Path $cfg) { [pscustomobject]@{ Dir = $_.FullName; Time = (Get-Item $cfg).LastWriteTime } } } |
        Sort-Object Time -Descending | Select-Object -First 1
    if (-not $latest) { throw 'No Steam account found under userdata. Log in to Steam once first.' }
    return $latest.Dir
}

# Copies (or moves) whatever is at $path into the backup folder, keeping its full path.
function Backup-Item([string]$path, [switch]$Move) {
    if (-not (Test-Path -LiteralPath $path)) { return }
    $rel = ($path -replace '^([A-Za-z]):', '$1')
    $dest = Join-Path $BackupRoot $rel
    New-Item -ItemType Directory -Force (Split-Path $dest) | Out-Null
    if ($Move) { Move-Item -LiteralPath $path $dest } else { Copy-Item -LiteralPath $path $dest -Recurse -Force }
}

# Copies every file under $src to the same relative path under $dst, backing up what it replaces.
function Copy-Overlay([string]$src, [string]$dst) {
    $base = (Resolve-Path -LiteralPath $src).Path.TrimEnd('\')
    Get-ChildItem -LiteralPath $src -Recurse -File | ForEach-Object {
        $rel = $_.FullName.Substring($base.Length + 1)
        $target = Join-Path $dst $rel
        Backup-Item $target
        New-Item -ItemType Directory -Force (Split-Path $target) | Out-Null
        Copy-Item -LiteralPath $_.FullName $target -Force
        Write-Note $rel
    }
}

function Get-File([string]$url, [string]$out) {
    New-Item -ItemType Directory -Force (Split-Path $out) | Out-Null
    Invoke-WebRequest -Uri $url -OutFile $out -Headers $Headers -UseBasicParsing
}

function Get-Sha256([string]$path) { (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLower() }

function Install-File([string]$file, [string]$target) {
    Backup-Item $target
    Copy-Item -LiteralPath $file $target -Force
}

# ------------------------------------------------------------------------- mod installers ---
function Install-Mastercomfig([string]$custom) {
    $mc = $Sources.Mastercomfig
    $version = $mc.Version; $urls = @{}
    if (-not $Pinned) {
        try {
            $rel = Invoke-RestMethod "https://api.github.com/repos/$($mc.Repo)/releases/latest" -Headers $Headers
            $version = $rel.tag_name
            foreach ($a in $rel.assets) { $urls[$a.name] = $a.browser_download_url }
        } catch { Write-Warn "Latest mastercomfig lookup failed ($($_.Exception.Message)), using pinned $($mc.Version)."; $version = $mc.Version }
    }
    Write-Note "mastercomfig $version (pinned backup was $($mc.Version))"
    foreach ($name in $mc.Assets.Keys) {
        $url = $urls[$name]
        if (-not $url) {
            if ($version -ne $mc.Version) { Write-Warn "$name not in release $version, using pinned $($mc.Version)." }
            $url = "https://github.com/$($mc.Repo)/releases/download/$($mc.Version)/$name"
        }
        $tmp = Join-Path $Work "mastercomfig\$name"
        Get-File $url $tmp
        if ($url -like "*/download/$($mc.Version)/*" -and (Get-Sha256 $tmp) -ne $mc.Assets[$name]) {
            throw "$name hash does not match the pinned $($mc.Version) release."
        }
        Install-File $tmp (Join-Path $custom $name)
        Write-Note "  $name"
    }
}

function Install-Budhud([string]$custom) {
    $bh = $Sources.Budhud
    $url = "https://codeload.github.com/$($bh.Repo)/zip/$($bh.PinnedRef)"; $label = "commit $($bh.PinnedRef.Substring(0,7)) (pinned)"
    if (-not $Pinned) {
        try {
            $rel = Invoke-RestMethod "https://api.github.com/repos/$($bh.Repo)/releases/latest" -Headers $Headers
            $url = "https://codeload.github.com/$($bh.Repo)/zip/refs/tags/$($rel.tag_name)"; $label = "release $($rel.tag_name)"
        } catch { Write-Warn "Latest budhud lookup failed ($($_.Exception.Message)), using pinned commit." }
    }
    Write-Note "budhud $label"
    $zip = Join-Path $Work 'budhud.zip'; $ex = Join-Path $Work 'budhud'
    Get-File $url $zip
    Expand-Archive -LiteralPath $zip -DestinationPath $ex -Force
    $top = Get-ChildItem $ex -Directory | Select-Object -First 1
    if (-not $top -or -not (Test-Path (Join-Path $top.FullName 'info.vdf'))) { throw 'budhud download does not look like a HUD (no info.vdf).' }
    $dest = Join-Path $custom 'budhud'
    Backup-Item $dest -Move
    Move-Item -LiteralPath $top.FullName $dest
}

function Install-GameBananaVpk($mod, [string]$custom) {
    $dl = "https://gamebanana.com/dl/$($mod.PinnedDl)"; $isPinned = $true
    if (-not $Pinned) {
        try {
            $info = Invoke-RestMethod "https://gamebanana.com/apiv11/Mod/$($mod.ModId)?_csvProperties=_aFiles" -Headers $Headers
            $newest = $info._aFiles | Sort-Object { [long]$_._tsDateAdded } -Descending | Select-Object -First 1
            if ($newest) { $dl = $newest._sDownloadUrl; $isPinned = ($newest._idRow -eq $mod.PinnedDl) }
        } catch { Write-Warn "GameBanana lookup failed for $($mod.Name) ($($_.Exception.Message)), using pinned file." }
    }
    Write-Note "$($mod.Name) - https://gamebanana.com/mods/$($mod.ModId) ($(if ($isPinned) { 'same file as backup' } else { 'NEWER file' }))"
    $zip = Join-Path $Work "gb_$($mod.ModId).zip"; $ex = Join-Path $Work "gb_$($mod.ModId)"
    Get-File $dl $zip
    Expand-Archive -LiteralPath $zip -DestinationPath $ex -Force
    $vpks = @(Get-ChildItem $ex -Recurse -Filter *.vpk)
    if ($vpks.Count -ne 1) { throw "Expected one .vpk in $($mod.Name) download, found $($vpks.Count). Install it by hand from https://gamebanana.com/mods/$($mod.ModId)" }
    $vpk = $vpks[0]
    if ($isPinned -and (Get-Sha256 $vpk.FullName) -ne $mod.Sha256) { throw "$($vpk.Name) hash does not match the backed-up version." }
    if ($vpk.Name -ne $mod.Vpk) {
        Write-Warn "VPK renamed upstream: $($mod.Vpk) -> $($vpk.Name). Removing the old name."
        Backup-Item (Join-Path $custom $mod.Vpk) -Move
    }
    Install-File $vpk.FullName (Join-Path $custom $vpk.Name)
}

# ----------------------------------------------------------------------------------- main ---
$running = Get-Process -Name hl2, tf, tf_win64, cs2 -ErrorAction SilentlyContinue
if ($running) { throw "Close the game first ($(($running.Name | Select-Object -Unique) -join ', '))." }
if ((Get-Process -Name steam -ErrorAction SilentlyContinue) -and -not $Force) {
    throw 'Close Steam first (Steam Cloud can overwrite restored files while it runs). Use -Force to ignore.'
}

$steam = $null
if (-not ($TF2Dir -and $CS2Dir -and $SteamUserDir)) { $steam = Get-SteamPath }
if (-not $SteamUserDir) { $SteamUserDir = Get-SteamUserDir $steam }
Write-Step "Steam account folder: $SteamUserDir"
New-Item -ItemType Directory -Force $Work | Out-Null

try {
    if ($Game -in 'All', 'TF2') {
        if (-not $TF2Dir) { $TF2Dir = Get-GameDir $steam 440 }
        if (-not $TF2Dir) {
            Write-Warn 'TF2 is not installed - skipping. Install it in Steam and run this again.'
        } else {
            $tf = Join-Path $TF2Dir 'tf'; $custom = Join-Path $tf 'custom'
            New-Item -ItemType Directory -Force $custom | Out-Null
            Write-Step "TF2 mods -> $custom"
            Install-Mastercomfig $custom
            Install-Budhud $custom
            foreach ($m in $Sources.GameBanana) { Install-GameBananaVpk $m $custom }

            Write-Step 'TF2 personal files'
            Copy-Overlay (Join-Path $Repo 'tf2\game') $TF2Dir

            # TF2 also loads the Steam Cloud copy of config.cfg, so keep it identical.
            $cloud = Join-Path $SteamUserDir '440\remote\cfg\config.cfg'
            New-Item -ItemType Directory -Force (Split-Path $cloud) | Out-Null
            Install-File (Join-Path $Repo 'tf2\game\tf\cfg\config.cfg') $cloud
            Write-Note "Steam Cloud copy: $cloud"

            if (-not $SkipRegistry) {
                Write-Step 'TF2 video settings (registry)'
                $regBackup = Join-Path $BackupRoot 'tf-settings-before.reg'
                New-Item -ItemType Directory -Force $BackupRoot | Out-Null
                & reg.exe export 'HKCU\Software\Valve\Source\tf\Settings' $regBackup /y 2>$null | Out-Null
                & reg.exe import (Join-Path $Repo 'tf2\registry\tf-settings.reg')
                if ($LASTEXITCODE -ne 0) { throw 'reg import failed.' }
                Write-Note 'HKCU\Software\Valve\Source\tf\Settings imported'
            }
        }
    }

    if ($Game -in 'All', 'CS2') {
        if (-not $CS2Dir) { $CS2Dir = Get-GameDir $steam 730 }
        if (-not $CS2Dir) {
            Write-Warn 'CS2 is not installed - skipping. Install it in Steam and run this again.'
        } else {
            Write-Step "CS2 game cfg -> $CS2Dir"
            Copy-Overlay (Join-Path $Repo 'cs2\game') (Join-Path $CS2Dir 'game')
            Write-Step "CS2 account settings -> $SteamUserDir\730"
            Copy-Overlay (Join-Path $Repo 'cs2\userdata\730') (Join-Path $SteamUserDir '730')
        }
    }
} finally {
    Remove-Item -LiteralPath $Work -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Step 'Steam launch options (Library > right-click game > Properties > Launch options)'
Write-Note "TF2: $($LaunchOptions.TF2)"
Write-Note "CS2: $(if ($LaunchOptions.CS2) { $LaunchOptions.CS2 } else { '(none)' })"
try { Set-Clipboard -Value $LaunchOptions.TF2; Write-Note '(TF2 options copied to the clipboard)' } catch { }

if (Test-Path $BackupRoot) { Write-Step "Replaced files were backed up to $BackupRoot" }
Write-Step 'Next: driver/Windows settings - see pc\README.md and run pc\apply-pc-settings.ps1 (elevated, -WhatIf first)'
Write-Host "`nDone." -ForegroundColor Green
