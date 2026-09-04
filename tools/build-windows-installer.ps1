# Builds the Windows release and compiles it into a setup executable.
#
# Two steps, and the second one is why this script is PowerShell and Windows-
# only: packaging/windows/installer.iss is compiled by Inno Setup's ISCC.exe,
# and Inno Setup is a Windows program. There is no cross-compilation path for
# either half — `flutter build windows` needs MSVC, and ISCC needs Windows — so
# this is the one part of the pipeline that cannot be verified from any other
# host.
#
# The output lands in dist\orpheus-setup-<version>.exe.
#
#   .\tools\build-windows-installer.ps1
#   .\tools\build-windows-installer.ps1 -SkipBuild     # reuse the release build
#
# Inno Setup: https://jrsoftware.org/isdl.php — or `winget install JRSoftware.InnoSetup`.

[CmdletBinding()]
param(
    # Reuse whatever is already in build\windows\x64\runner\Release instead of
    # building again. What tools/verify.ps1 -Installer passes, because it has
    # just built it.
    [switch] $SkipBuild,

    # Where ISCC.exe is, if it is not on PATH and not in either standard place.
    [string] $InnoSetupPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot

function Step($message) { Write-Host "==> $message" -ForegroundColor Cyan }
function Note($message) { Write-Host "    $message" -ForegroundColor DarkGray }
function Fail($message) { Write-Host "error: $message" -ForegroundColor Red; exit 2 }

# --------------------------------------------------------------- the version

# Read from pubspec.yaml rather than written here, so that the installer's file
# name, the version the wizard shows, and the version the application reports
# cannot drift apart. The build metadata after `+` is dropped: Inno's AppVersion
# is shown to a person, and `1.0.0+1` reads as a typo.
Step 'Reading the version'

$pubspec = Get-Content (Join-Path $RepoRoot 'pubspec.yaml') -Raw
if ($pubspec -notmatch '(?m)^version:\s*([0-9]+\.[0-9]+\.[0-9]+)') {
    Fail 'pubspec.yaml does not declare a version of the form x.y.z'
}
$Version = $Matches[1]
Note "version $Version"

# ----------------------------------------------------------------- the build

$ReleaseDir = Join-Path $RepoRoot 'build\windows\x64\runner\Release'

if ($SkipBuild) {
    Step 'Reusing the existing release build'
    if (-not (Test-Path (Join-Path $ReleaseDir 'orpheus.exe'))) {
        Fail "no release build in $ReleaseDir — run without -SkipBuild"
    }
} else {
    Step 'Building Windows (release)'
    flutter build windows --release
    if ($LASTEXITCODE -ne 0) { Fail 'the Windows release build failed' }
}

# Checked rather than assumed: an installer compiled from a directory missing
# the engine's DLLs installs cleanly and then fails to play anything, which is
# the worst possible moment to find out.
$payload = Get-ChildItem $ReleaseDir -File -ErrorAction SilentlyContinue
if (-not $payload -or -not (Test-Path (Join-Path $ReleaseDir 'orpheus.exe'))) {
    Fail "the release directory holds no orpheus.exe: $ReleaseDir"
}
if (-not (Test-Path (Join-Path $ReleaseDir 'data\flutter_assets'))) {
    Fail 'the release directory holds no data\flutter_assets; the build is incomplete'
}
Note "payload: $ReleaseDir"

# ------------------------------------------------------------------- Inno Setup

Step 'Locating Inno Setup'

function Find-Iscc {
    if ($InnoSetupPath) {
        if (Test-Path $InnoSetupPath) { return $InnoSetupPath }
        Fail "no ISCC.exe at $InnoSetupPath"
    }

    $onPath = Get-Command 'ISCC.exe' -ErrorAction SilentlyContinue
    if ($onPath) { return $onPath.Source }

    foreach ($candidate in @(
        "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
        "$env:ProgramFiles\Inno Setup 6\ISCC.exe",
        "${env:ProgramFiles(x86)}\Inno Setup 5\ISCC.exe")) {
        if ($candidate -and (Test-Path $candidate)) { return $candidate }
    }

    return $null
}

$iscc = Find-Iscc
if (-not $iscc) {
    Fail @'
Inno Setup was not found.

  winget install JRSoftware.InnoSetup

or download it from https://jrsoftware.org/isdl.php, then re-run this script —
or pass -InnoSetupPath with the full path to ISCC.exe.
'@
}
Note $iscc

# --------------------------------------------------------------- compile it

Step 'Compiling the installer'

$dist = Join-Path $RepoRoot 'dist'
New-Item -ItemType Directory -Force -Path $dist | Out-Null

# The version goes in on the command line rather than through the environment,
# so that compiling this script by hand from the Inno Setup IDE and compiling it
# here produce the same thing. The .iss falls back to ORPHEUS_VERSION for the
# by-hand case.
& $iscc "/DAppVersion=$Version" (Join-Path $RepoRoot 'packaging\windows\installer.iss')
if ($LASTEXITCODE -ne 0) { Fail 'Inno Setup could not compile the installer' }

$installer = Join-Path $dist "orpheus-setup-$Version.exe"
if (-not (Test-Path $installer)) {
    Fail "Inno Setup reported success but $installer is not there"
}

$size = [math]::Round((Get-Item $installer).Length / 1MB, 1)

Write-Host ''
Write-Host "Built $installer ($size MB)" -ForegroundColor Green
Write-Host 'Unsigned: SmartScreen will warn on first run until the project holds a certificate.' -ForegroundColor DarkGray
