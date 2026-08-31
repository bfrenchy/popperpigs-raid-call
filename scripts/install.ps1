#Requires -Version 5.1
<#
.SYNOPSIS
    Install Popperpig Raid Call into a WoW AddOns folder, on Windows.

.DESCRIPTION
    The PowerShell twin of scripts/install.sh, for people who do not have Git
    Bash or WSL. Same rules: the repository directory is popperpigs-raid-call
    but the in-game folder has to be PopperpigRaidCall, matching the .toc.
    Getting that wrong is the most common reason an addon silently fails to
    appear, which is the whole reason this script exists.

    Unlike the bash version this enumerates every fixed drive rather than
    guessing at C:, so a WoW install on D: or E: is found without being told.

.PARAMETER Target
    An explicit AddOns folder. Overrides auto-detection and $env:WOW_ADDONS_DIR.

.PARAMETER Link
    Make a directory junction instead of copying, so edits in the repo are
    live in game after a /reload. Junctions do not need administrator rights.

.EXAMPLE
    .\scripts\install.ps1

.EXAMPLE
    .\scripts\install.ps1 -Target "D:\World of Warcraft\_anniversary_\Interface\AddOns"
#>
[CmdletBinding()]
param(
    [string] $Target,
    [switch] $Link
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$AddonName = 'PopperpigRaidCall'

# Exactly what the game loads. Tests, scripts and CI stay out, matching .pkgmeta.
$Shipped  = @('PopperpigRaidCall.toc', 'Core', 'Data', 'UI')
$RepoRoot = Split-Path -Parent $PSScriptRoot

# ---------------------------------------------------------------------------
# Find the AddOns folder
#
# The Anniversary client installs to the _anniversary_ flavour directory, which
# is what this addon targets and so what we look for first. Some installs put a
# TBC-era client under _classic_ instead, so that is the fallback.
#
# _classic_era_ is deliberately NOT probed: that is Classic Era, a different
# client. Installing there means the addon never shows up and nothing explains
# why, which is a worse outcome than failing to auto-detect.
# ---------------------------------------------------------------------------

if (-not $Target -and $env:WOW_ADDONS_DIR) {
    $Target = $env:WOW_ADDONS_DIR
}

if (-not $Target) {
    $flavours = @('_anniversary_', '_classic_')

    $roots = New-Object System.Collections.Generic.List[string]
    foreach ($drive in [System.IO.DriveInfo]::GetDrives()) {
        if ($drive.DriveType -ne 'Fixed' -or -not $drive.IsReady) { continue }
        $r = $drive.RootDirectory.FullName
        $roots.Add((Join-Path $r 'World of Warcraft'))
        $roots.Add((Join-Path $r 'Program Files (x86)\World of Warcraft'))
        $roots.Add((Join-Path $r 'Program Files\World of Warcraft'))
        $roots.Add((Join-Path $r 'Games\World of Warcraft'))
    }

    foreach ($flavour in $flavours) {
        foreach ($root in $roots) {
            $candidate = Join-Path $root (Join-Path $flavour 'Interface\AddOns')
            if (Test-Path -LiteralPath $candidate -PathType Container) {
                $Target = $candidate
                Write-Host "Found AddOns folder ($flavour): $Target"
                break
            }
        }
        if ($Target) { break }
    }
}

if (-not $Target) {
    Write-Error @'
Could not find your AddOns folder.

Pass it explicitly:
    .\scripts\install.ps1 -Target "C:\Program Files (x86)\World of Warcraft\_anniversary_\Interface\AddOns"

or set $env:WOW_ADDONS_DIR.

The Anniversary client lives under the _anniversary_ flavour directory; some
installs use _classic_ instead. Use whichever one your launcher actually
launches -- _classic_era_ is Classic Era and is the wrong client.
'@
    exit 1
}

if (-not (Test-Path -LiteralPath $Target -PathType Container)) {
    Write-Error "Not a directory: $Target"
    exit 1
}

$dest = Join-Path $Target $AddonName

# ---------------------------------------------------------------------------
# Install
# ---------------------------------------------------------------------------

if ($Link) {
    # Refuse to delete a real directory on the way to making a junction. Someone
    # with a copied install and local edits should not lose them to a flag they
    # passed once.
    if (Test-Path -LiteralPath $dest) {
        $existing = Get-Item -LiteralPath $dest -Force
        if (-not $existing.LinkType) {
            Write-Error "Refusing to replace the existing directory at:`n  $dest`nRemove it yourself first if you are sure."
            exit 1
        }
        Remove-Item -LiteralPath $dest -Force -Recurse
    }
    New-Item -ItemType Junction -Path $dest -Target $RepoRoot | Out-Null
    Write-Host "Linked $dest -> $RepoRoot"
    Write-Host "Edit files in the repo and /reload in game to pick them up."
}
else {
    if (Test-Path -LiteralPath $dest) {
        Remove-Item -LiteralPath $dest -Force -Recurse
    }
    New-Item -ItemType Directory -Path $dest -Force | Out-Null
    foreach ($item in $Shipped) {
        Copy-Item -LiteralPath (Join-Path $RepoRoot $item) -Destination $dest -Recurse -Force
    }
    Write-Host "Installed to $dest"
}

Write-Host @'

Next:
  1. Restart the client, or /reload if it is already running.
  2. Enable "Popperpig Raid Call" at character select. Tick "Load out of date
     AddOns" if the client flags the interface version.
  3. /pprc debug   -> prints the capability table. Zero Lua errors here is the
     bar. It also names which detection tier went active.
  4. /pprc test hyjal_winterchill   -> walks all 8 waves solo, no raid needed.
  5. /pprc echo    -> run your first live night this way. Calls print to your
     own chat frame and go nowhere near the raid.
'@
