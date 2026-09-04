# Runs Orpheus for the develop loop: start it, change the code, see the change.
# The Windows counterpart of tools/dev.sh, with the same steps and the same
# flags in long form.
#
# This is not tools/verify.ps1. That one proves the project is sound and exits;
# this one puts the application in front of you and stays there. The loop it is
# built around is Flutter's own: `flutter run` watches the source, and while it
# is running
#
#     r   hot reload   — the change is in, state is kept
#     R   hot restart  — the change is in, state is thrown away
#     q   quit
#
# so "modify the code and run again" is usually one keystroke rather than a
# second invocation of this script. Restarting the script is for the changes
# hot reload cannot carry: a new dependency, a change to a native or platform
# file, or anything under the l10n catalogs (use -Generate).

[CmdletBinding()]
param(
    # Which device to run on — windows, an Android device id, or anything else
    # `flutter devices` lists. Defaults to this host's desktop, or to the only
    # device attached.
    [Alias('d')]
    [string] $Device,

    # The attached Android device or emulator, whatever its id.
    [switch] $Android,

    # Release-like performance with the timeline still available. No hot reload.
    [switch] $Profile,

    # What an owner would actually get, and the only mode worth judging
    # performance or startup in. No hot reload.
    [switch] $Release,

    # Delete the data this application has written — the catalog, the cover
    # cache, the play history and the preferences — so the next start is a first
    # launch. Never touches your music. Asks first unless -Yes.
    [switch] $Clean,

    # Regenerate the localizations before running. Needed after changing either
    # .arb catalog; hot reload will not pick that up on its own.
    [switch] $Generate,

    # Run the suite before starting, and stop if it is red.
    [switch] $Test,

    # Do everything asked except start the application.
    [switch] $NoRun,

    # Do not ask about -Clean.
    [Alias('y')]
    [switch] $Yes
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot

function Step($message) { Write-Host "==> $message" -ForegroundColor Cyan }
function Note($message) { Write-Host "    $message" -ForegroundColor DarkGray }
function Warn($message) { Write-Host "    $message" -ForegroundColor Yellow }
function Fail($message) { Write-Host "error: $message" -ForegroundColor Red; exit 2 }

$Mode = 'debug'
if ($Profile) { $Mode = 'profile' }
if ($Release) { $Mode = 'release' }
if ($Profile -and $Release) { Fail 'pick one of -Profile and -Release' }

# --------------------------------------------------------------- preflight

Step 'Preflight'
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Fail 'flutter is not on PATH'
}
# The real OS rather than the word "Windows": this script is for
# Windows, and one run anywhere else should say so rather than agree
# with the assumption in its own header.
Note "host: $([System.Environment]::OSVersion.VersionString)"

# Nothing to check for the engine here, unlike on Linux: media_kit_libs_audio
# bundles the playback engine's DLLs into the build, so there is no runtime
# dependency for this script to find missing.

# ----------------------------------------------------------------- the device

function Get-Devices {
    $raw = flutter devices --machine 2>$null
    if (-not $raw) { return @() }
    try { $parsed = $raw | ConvertFrom-Json } catch { return @() }
    # A single device deserializes to one object rather than an array.
    return @($parsed)
}

$devices = Get-Devices
if ($devices.Count -eq 0) { Fail 'flutter sees no devices at all; try `flutter doctor`' }

function Show-Devices {
    foreach ($d in $devices) { Write-Host ("  {0,-24} {1}" -f $d.id, $d.targetPlatform) }
}

if ($Android) {
    $match = $devices | Where-Object { $_.targetPlatform -like 'android*' } | Select-Object -First 1
    if (-not $match) { Fail 'no Android device or emulator is attached' }
    $Device = $match.id
}

if (-not $Device) {
    if ($devices | Where-Object { $_.id -eq 'windows' }) {
        # This host's own desktop, which is what someone typing .\tools\dev.ps1
        # with no arguments almost always means.
        $Device = 'windows'
    } elseif ($devices.Count -eq 1) {
        $Device = $devices[0].id
    } else {
        # Refused rather than guessed. Picking one is how you end up watching a
        # phone while wondering why the desktop did not change.
        Write-Host 'error: several devices are attached; name one with -Device' -ForegroundColor Red
        Show-Devices
        exit 2
    }
}

$chosen = $devices | Where-Object { $_.id -eq $Device } | Select-Object -First 1
if (-not $chosen) {
    Write-Host "error: no device called $Device. Attached:" -ForegroundColor Red
    Show-Devices
    exit 2
}

$devicePlatform = $chosen.targetPlatform
Note "device: $Device ($devicePlatform)"
Note "mode: $Mode"

# ------------------------------------------------------------------- the data

# Where this application keeps the catalog, the cover cache, the play history
# and the preferences — derived from the same rule path_provider_windows uses
# rather than guessed: %APPDATA% plus CompanyName\ProductName, which come from
# the executable's own version info.
function Get-AppDataDirectories {
    $found = @()
    if ($devicePlatform -like 'windows*' -and $env:APPDATA) {
        $found += (Join-Path $env:APPDATA 'io.github.artur_rios\orpheus')
    }
    return $found
}

function Clear-AppData {
    Step "Clearing this application's own data"

    if ($devicePlatform -like 'android*') {
        Note 'on the device, via: adb shell pm clear io.github.artur_rios.orpheus'
        if (-not $Yes) {
            $answer = Read-Host '    Clear Orpheus''s data on the device? [y/N]'
            if ($answer -notmatch '^(y|yes)$') { Note 'left alone'; return }
        }
        if (-not (Get-Command adb -ErrorAction SilentlyContinue)) { Fail 'adb is not on PATH' }
        adb shell pm clear io.github.artur_rios.orpheus 2>&1 | Out-Null
        return
    }

    $present = @(Get-AppDataDirectories | Where-Object { Test-Path $_ })
    if ($present.Count -eq 0) {
        Note 'nothing to clear; this application has written nothing yet'
        return
    }

    foreach ($directory in $present) { Note $directory }
    # Said explicitly, because this is the sentence someone needs to read before
    # answering: the folders you registered are forgotten, the music in them is
    # not touched.
    Note 'your music is not touched — only the catalog, covers, statistics and settings'

    if (-not $Yes) {
        $answer = Read-Host '    Delete the above? [y/N]'
        if ($answer -notmatch '^(y|yes)$') { Note 'left alone'; return }
    }

    foreach ($directory in $present) { Remove-Item -Recurse -Force $directory }
    Note 'cleared; the next start is a first launch'
}

if ($Clean) { Clear-AppData }

# --------------------------------------------------------------- before the run

Step 'Resolving dependencies'
flutter pub get | Out-Host
if ($LASTEXITCODE -ne 0) { Fail 'dependencies could not be resolved' }

if ($Generate) {
    Step 'Regenerating the localizations'
    # Hot reload does not pick up a changed .arb: the catalogs become Dart in a
    # build step, and the running application is holding the previous generation.
    flutter gen-l10n | Out-Host
    if ($LASTEXITCODE -ne 0) { Fail 'gen-l10n failed' }
    Note 'run again, or press R, to see new strings'
}

if ($Test) {
    Step 'Testing before starting'
    flutter test | Out-Host
    if ($LASTEXITCODE -ne 0) { Fail 'the suite is red; fix it before running' }
}

if ($NoRun) {
    Step 'Not running, as asked'
    exit 0
}

# ----------------------------------------------------------------------- run it

Step 'Starting Orpheus'

if ($Mode -eq 'debug') {
    Note 'r = hot reload    R = hot restart    q = quit'
    Note 'a change to a dependency, a native file or an .arb needs this script again'
} else {
    # Worth saying rather than letting someone press r into silence: Flutter
    # only offers hot reload in debug mode, and this is exactly the moment the
    # habit of pressing it does not work.
    Note "no hot reload in $Mode mode — that is debug only"
}

# Not piped to Out-Host: this one is interactive, and its keystrokes are the
# whole point. The exit code is this script's.
flutter run -d $Device --$Mode
exit $LASTEXITCODE
