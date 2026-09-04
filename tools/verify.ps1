# Verifies Orpheus: the analyzer, the test suite, and a release build of every
# target this host can build. The Windows counterpart of tools/verify.sh, with
# the same steps and the same flags in long form.
#
# The honest shape of "test it on all platforms" is two statements, not one.
# The analyzer and the suite are platform-independent and run everywhere; a
# release build is not, and no single machine can produce all three. Linux
# binaries need Linux. So this script builds what this host can build, says
# plainly which targets it skipped and why, and exits non-zero only for
# something that actually failed — never for a target that was never available.
#
# -Installer additionally compiles the Windows setup executable, which is the
# one step that can only happen here: packaging/windows/installer.iss is
# compiled by Inno Setup, and Inno Setup is a Windows program.

[CmdletBinding()]
param(
    # Build only one target: windows or android.
    [ValidateSet('windows', 'android', 'linux')]
    [string] $Only,

    # Analyzer and tests only. The fast loop.
    [switch] $NoBuild,

    # Skip the suite.
    [switch] $NoTest,

    # Skip the analyzer.
    [switch] $NoAnalyze,

    # Also compile the Windows installer from the release build.
    [switch] $Installer,

    # Treat a skipped target as a failure. What CI uses on a host that is
    # supposed to be able to build everything asked of it. A target this
    # operating system cannot build at all is not a skip and never fails: see
    # "n/a" in the summary.
    [switch] $Strict
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot

# Recorded as the run goes and reported together at the end, for the reason
# tools/verify.sh does it: a summary that only says "failed" makes the reader
# scroll back through a build log to find out what.
$Passed  = [System.Collections.Generic.List[string]]::new()
$Failed  = [System.Collections.Generic.List[string]]::new()
$Skipped = [System.Collections.Generic.List[string]]::new()
$NotApplicable = [System.Collections.Generic.List[string]]::new()

function Step($message) { Write-Host "==> $message" -ForegroundColor Cyan }
function Note($message) { Write-Host "    $message" -ForegroundColor DarkGray }
function Good($message) { Write-Host "    $message" -ForegroundColor Green }
function Warn($message) { Write-Host "    $message" -ForegroundColor Yellow }
function Bad($message)  { Write-Host "    $message" -ForegroundColor Red }

function Record-Pass($name) { $Passed.Add($name);  Good "$name — passed" }
function Record-Fail($name) { $Failed.Add($name);  Bad  "$name — FAILED" }
function Record-Skip($name, $why) { $Skipped.Add("${name}: $why"); Warn "$name — skipped ($why)" }

# A target this host could never build, however it were configured — a Linux
# binary on Windows. Reported so the run is honest about what it did not cover,
# and never a failure even under -Strict: -Strict is for a toolchain that should
# have been there and was not, and no amount of installing makes a Windows
# machine produce a Linux binary.
function Record-NA($name, $why) { $NotApplicable.Add("${name}: $why"); Note "$name — not applicable ($why)" }

# Whether this target was asked for. With no -Only, everything is.
function Wanted($target) { return (-not $Only) -or ($Only -eq $target) }

# Runs a command and answers whether it succeeded, without $ErrorActionPreference
# turning a non-zero exit into a terminating error we cannot summarize.
#
# `| Out-Host` is load-bearing and not formatting. A native command's stdout
# joins its caller's output stream, so without it this function returns every
# line the build printed *and* the boolean — and `if (Invoke-Step ...)` then
# tests a non-empty array, which is true whatever the exit code was. That is
# not hypothetical: it reported a failed Windows build as passed until CI
# caught it. Out-Host writes to the console and puts nothing on the pipeline,
# so the boolean is the only thing returned.
function Invoke-Step {
    param([string] $Command, [string[]] $Arguments)

    & $Command @Arguments | Out-Host
    return ($LASTEXITCODE -eq 0)
}

# --------------------------------------------------------------- preflight

Step 'Preflight'

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Host 'error: flutter is not on PATH' -ForegroundColor Red
    exit 2
}

# Written out rather than a ternary: Windows ships PowerShell 5.1, and `? :`
# is a 7-only operator. Nothing in this script needs 7, and requiring it would
# mean asking a Windows owner to install a shell before they can run the tests.
$version = (flutter --version 2>$null | Select-String -Pattern 'Flutter \d+\.\d+\.\d+' |
            Select-Object -First 1).Matches.Value
if ($version) { Note $version } else { Note 'flutter (version not reported)' }
Note "host: Windows $([System.Environment]::OSVersion.Version)"
Note "repo: $RepoRoot"

Step 'Resolving dependencies'
if (Invoke-Step 'flutter' @('pub', 'get')) {
    Record-Pass 'pub get'
} else {
    Record-Fail 'pub get'
    Write-Host "`nDependencies could not be resolved; nothing else was run." -ForegroundColor Red
    exit 1
}

# --------------------------------------------------------------- the analyzer

if (-not $NoAnalyze) {
    Step 'Analyzing'
    Note 'must be clean; there is no known-warnings list'
    if (Invoke-Step 'flutter' @('analyze')) { Record-Pass 'flutter analyze' }
    else { Record-Fail 'flutter analyze' }
}

# ------------------------------------------------------------------ the suite

if (-not $NoTest) {
    Step 'Testing'
    Note 'no test may read your preferences, write to your support folder,'
    Note 'record against your statistics, open the engine, or reach the network'
    if (Invoke-Step 'flutter' @('test')) { Record-Pass 'flutter test' }
    else { Record-Fail 'flutter test' }
}

# ----------------------------------------------------------------- the builds

function Build-Target($target, $label) {
    Step "Building $label"
    if (Invoke-Step 'flutter' @('build', $target, '--release')) { Record-Pass "build $label" }
    else { Record-Fail "build $label" }
}

# Whether an Android SDK is configured. `flutter doctor` is authoritative and
# slow; this is the cheap version of the same question.
function Android-Present {
    foreach ($root in @($env:ANDROID_HOME, $env:ANDROID_SDK_ROOT,
                        "$env:LOCALAPPDATA\Android\Sdk")) {
        if ($root -and (Test-Path (Join-Path $root 'platforms'))) { return $true }
    }
    return $false
}

$windowsBuilt = $false

if (-not $NoBuild) {
    if (Wanted 'windows') {
        Step 'Building Windows (release)'
        if (Invoke-Step 'flutter' @('build', 'windows', '--release')) {
            Record-Pass 'build Windows (release)'
            $windowsBuilt = $true
        } else {
            Record-Fail 'build Windows (release)'
        }
    }

    if (Wanted 'android') {
        if (Android-Present) { Build-Target 'apk' 'Android (release APK)' }
        else { Record-Skip 'build android' 'no Android SDK found; set ANDROID_HOME' }
    }

    if (Wanted 'linux') {
        # Never attempted here. A Linux binary links against GTK and needs a
        # Linux host; tools/verify.sh is what runs there.
        Record-NA 'build linux' 'Linux binaries need a Linux host; run tools/verify.sh there'
    }
}

# -------------------------------------------------------------- the installer

if ($Installer) {
    if (-not $windowsBuilt) {
        Record-Skip 'windows installer' 'the Windows release build did not run or did not pass'
    } else {
        Step 'Building the Windows installer'
        # A script, not a native command, so $LASTEXITCODE is only set if it
        # actually calls `exit`. Seeded first so a script that returned without
        # one cannot be read as the previous command's success.
        $global:LASTEXITCODE = 0
        & (Join-Path $PSScriptRoot 'build-windows-installer.ps1') -SkipBuild | Out-Host
        if ($LASTEXITCODE -eq 0) { Record-Pass 'windows installer' }
        else { Record-Fail 'windows installer' }
    }
}

# ---------------------------------------------------------------- the summary

Write-Host ''
Step 'Summary'

foreach ($item in $Passed)  { Write-Host "  PASS  $item" -ForegroundColor Green }
foreach ($item in $Skipped) { Write-Host "  SKIP  $item" -ForegroundColor Yellow }
foreach ($item in $NotApplicable) { Write-Host "  n/a   $item" -ForegroundColor DarkGray }
foreach ($item in $Failed)  { Write-Host "  FAIL  $item" -ForegroundColor Red }

if ($Failed.Count -gt 0) {
    Write-Host "`nSomething failed." -ForegroundColor Red
    exit 1
}

if ($Skipped.Count -gt 0 -and $Strict) {
    Write-Host "`nSomething was skipped, and -Strict was asked for." -ForegroundColor Red
    exit 1
}

if ($Skipped.Count -gt 0) {
    Write-Host "`nEverything attempted passed." -ForegroundColor Green -NoNewline
    Write-Host ' Some targets were skipped — see above.' -ForegroundColor Yellow
} elseif ($NotApplicable.Count -gt 0) {
    Write-Host "`nEverything this host can verify passed." -ForegroundColor Green -NoNewline
    Write-Host ' Other hosts cover the rest.' -ForegroundColor DarkGray
} else {
    Write-Host "`nEverything passed." -ForegroundColor Green
}
