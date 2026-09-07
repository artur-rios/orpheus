#!/bin/sh
# Verifies Orpheus: the analyzer, the test suite, and a release build of every
# target this host can build. The POSIX counterpart of tools/verify.ps1, with
# the same steps and the same flags.
#
# The honest shape of "test it on all platforms" is two statements, not one.
# The analyzer and the suite are platform-independent and run everywhere; a
# release build is not, and no single machine can produce all three. Windows
# binaries need Windows, and the Linux build needs the GTK development
# libraries. So this script builds what this host can build, says plainly which
# targets it skipped and why, and exits non-zero only for something that
# actually failed — never for a target that was never available.
#
# Running it on all three hosts, or letting CI do that, is what makes the claim
# complete. .github/workflows/verify.yml runs this same script on Linux and on
# Windows for exactly that reason.

set -eu

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$REPO_ROOT"

WANT_ANALYZE="yes"
WANT_TEST="yes"
WANT_BUILD="yes"
ONLY_TARGET=""
FAIL_ON_SKIP="no"

# Recorded as the run goes, and reported together at the end. A summary that
# only says "failed" makes the reader scroll back through a build log to find
# out what; naming every step's outcome in one place is the whole point of
# having a script rather than four commands in a README.
PASSED=""
FAILED=""
SKIPPED=""
NOTAPPLICABLE=""

step() { printf '\033[36m==> %s\033[0m\n' "$*"; }
note() { printf '\033[90m    %s\033[0m\n' "$*"; }
good() { printf '\033[32m    %s\033[0m\n' "$*"; }
warn() { printf '\033[33m    %s\033[0m\n' "$*"; }
bad()  { printf '\033[31m    %s\033[0m\n' "$*" >&2; }
fail() { printf '\033[31merror: %s\033[0m\n' "$*" >&2; exit 2; }

usage() {
  cat <<USAGE
Usage: tools/verify.sh [options]

  --only TARGET   Build only one target: linux, android or windows. This host
                  builds linux and android; windows is reported as not
                  applicable, because a Windows binary needs a Windows host.
  --no-build      Analyzer and tests only. The fast loop.
  --no-test       Skip the suite. For checking that the builds still link.
  --no-analyze    Skip the analyzer.
  --strict        Treat a skipped target as a failure. What CI uses on a host
                  that is supposed to be able to build everything asked of it.
                  A target this operating system cannot build at all is not a
                  skip and never fails: see "n/a" in the summary.
  --help          Show this message.

Exit codes:
  0  everything attempted passed
  1  something failed
  2  the script was used wrongly, or the toolchain is missing
USAGE
}

while [ $# -gt 0 ]; do
  case $1 in
    --only) [ $# -ge 2 ] || fail "--only needs a target"; ONLY_TARGET=$2; shift 2 ;;
    --only=*) ONLY_TARGET=${1#--only=}; shift ;;
    --no-build) WANT_BUILD="no"; shift ;;
    --no-test) WANT_TEST="no"; shift ;;
    --no-analyze) WANT_ANALYZE="no"; shift ;;
    --strict) FAIL_ON_SKIP="yes"; shift ;;
    --help|-h) usage; exit 0 ;;
    *) usage >&2; fail "unknown option: $1" ;;
  esac
done

case ${ONLY_TARGET:-none} in
  none|linux|android|windows) ;;
  *) fail "--only takes linux, android or windows" ;;
esac

record_pass() { PASSED="$PASSED$1
"; good "$1 — passed"; }
record_fail() { FAILED="$FAILED$1
"; bad "$1 — FAILED"; }
record_skip() { SKIPPED="$SKIPPED$1: $2
"; warn "$1 — skipped ($2)"; }

# A target this host could never build, however it were configured — a Windows
# binary on Linux. Reported so the run is honest about what it did not cover,
# and never a failure even under --strict: --strict is for a toolchain that
# should have been there and was not, and no amount of installing makes a Linux
# machine produce a Windows binary.
record_na() { NOTAPPLICABLE="$NOTAPPLICABLE$1: $2
"; note "$1 — not applicable ($2)"; }

# Whether this target was asked for. With no --only, everything is.
wanted() { [ -z "$ONLY_TARGET" ] || [ "$ONLY_TARGET" = "$1" ]; }

# ------------------------------------------------------------------- preflight

step "Preflight"

command -v flutter >/dev/null 2>&1 || fail "flutter is not on PATH"

FLUTTER_VERSION=$(flutter --version 2>/dev/null | grep -oE 'Flutter [0-9]+\.[0-9]+\.[0-9]+' | head -1)
note "${FLUTTER_VERSION:-flutter (version not reported)}"
note "host: $(uname -s) $(uname -m)"
note "repo: $REPO_ROOT"

# Dependencies first. Every step below assumes .dart_tool is current, and a
# stale one fails in ways that look like source errors.
step "Resolving dependencies"
if flutter pub get >/dev/null 2>&1; then
  record_pass "pub get"
else
  record_fail "pub get"
  # Nothing after this can mean anything, so this one is fatal rather than
  # recorded and carried past.
  printf '\n\033[31mDependencies could not be resolved; nothing else was run.\033[0m\n' >&2
  exit 1
fi

# --------------------------------------------------------------- the analyzer

if [ "$WANT_ANALYZE" = "yes" ]; then
  step "Analyzing"
  note "must be clean; there is no known-warnings list"
  if flutter analyze; then
    record_pass "flutter analyze"
  else
    record_fail "flutter analyze"
  fi
fi

# -------------------------------------------------------------------- the suite

if [ "$WANT_TEST" = "yes" ]; then
  step "Testing"
  note "no test may read your preferences, write to your support folder,"
  note "record against your statistics, open the engine, or reach the network"
  if flutter test; then
    record_pass "flutter test"
  else
    record_fail "flutter test"
  fi
fi

# ------------------------------------------------------------------ the builds

# Whether the GTK development libraries a Linux build links against are here.
# Checked before building rather than after failing, so a machine without them
# reports a missing toolchain instead of two hundred lines of compiler output.
linux_toolchain_present() {
  command -v pkg-config >/dev/null 2>&1 || return 1
  pkg-config --exists gtk+-3.0 2>/dev/null || return 1
  command -v cmake >/dev/null 2>&1 || return 1
  command -v ninja >/dev/null 2>&1 || return 1
  return 0
}

# Whether an Android SDK is configured. `flutter doctor` is authoritative and
# slow; this is the cheap version of the same question.
android_toolchain_present() {
  [ -n "${ANDROID_HOME:-}" ] && [ -d "${ANDROID_HOME}/platforms" ] && return 0
  [ -n "${ANDROID_SDK_ROOT:-}" ] && [ -d "${ANDROID_SDK_ROOT}/platforms" ] && return 0
  [ -d "$HOME/Android/Sdk/platforms" ] && return 0
  return 1
}

build_target() {
  target=$1
  label=$2
  step "Building $label"
  if flutter build "$target" --release; then
    record_pass "build $label"
  else
    record_fail "build $label"
  fi
}

if [ "$WANT_BUILD" = "yes" ]; then
  if wanted linux; then
    if [ "$(uname -s)" != "Linux" ]; then
      record_na "build linux" "this host is not Linux"
    elif linux_toolchain_present; then
      build_target linux "Linux (release)"
    else
      record_skip "build linux" "cmake, ninja, pkg-config or libgtk-3-dev is missing"
    fi
  fi

  if wanted android; then
    if android_toolchain_present; then
      build_target apk "Android (release APK)"
    else
      record_skip "build android" "no Android SDK found; set ANDROID_HOME"
    fi
  fi

  if wanted windows; then
    # Never attempted here. `flutter build windows` needs MSVC, and a Linux or
    # macOS host has no way to produce a Windows binary — which is what
    # tools/verify.ps1 and the CI workflow exist for.
    record_na "build windows" "Windows binaries need a Windows host; run tools/verify.ps1 there"
  fi
fi

# ----------------------------------------------------------------- the summary

printf '\n\033[36m==> Summary\033[0m\n'

printf '%s' "$PASSED" | while IFS= read -r line; do
  [ -n "$line" ] && printf '\033[32m  PASS  %s\033[0m\n' "$line"
done
printf '%s' "$SKIPPED" | while IFS= read -r line; do
  [ -n "$line" ] && printf '\033[33m  SKIP  %s\033[0m\n' "$line"
done
printf '%s' "$NOTAPPLICABLE" | while IFS= read -r line; do
  [ -n "$line" ] && printf '\033[90m  n/a   %s\033[0m\n' "$line"
done
printf '%s' "$FAILED" | while IFS= read -r line; do
  [ -n "$line" ] && printf '\033[31m  FAIL  %s\033[0m\n' "$line"
done

if [ -n "$FAILED" ]; then
  printf '\n\033[31mSomething failed.\033[0m\n' >&2
  exit 1
fi

if [ -n "$SKIPPED" ] && [ "$FAIL_ON_SKIP" = "yes" ]; then
  printf '\n\033[31mSomething was skipped, and --strict was asked for.\033[0m\n' >&2
  exit 1
fi

if [ -n "$SKIPPED" ]; then
  printf '\n\033[32mEverything attempted passed.\033[0m'
  printf ' \033[33mSome targets were skipped — see above.\033[0m\n'
elif [ -n "$NOTAPPLICABLE" ]; then
  printf '\n\033[32mEverything this host can verify passed.\033[0m'
  printf ' \033[90mOther hosts cover the rest.\033[0m\n'
else
  printf '\n\033[32mEverything passed.\033[0m\n'
fi
