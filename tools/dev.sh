#!/bin/sh
# Runs Orpheus for the develop loop: start it, change the code, see the change.
# The POSIX counterpart of tools/dev.ps1, with the same steps and the same flags.
#
# This is not tools/verify.sh. That one proves the project is sound and exits;
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
# file, or anything under the l10n catalogs (use --generate).

set -eu

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$REPO_ROOT"

DEVICE=""
MODE="debug"
CLEAN="no"
GENERATE="no"
TEST_FIRST="no"
ASSUME_YES="no"
NO_RUN="no"

step() { printf '\033[36m==> %s\033[0m\n' "$*"; }
note() { printf '\033[90m    %s\033[0m\n' "$*"; }
warn() { printf '\033[33m    %s\033[0m\n' "$*"; }
fail() { printf '\033[31merror: %s\033[0m\n' "$*" >&2; exit 2; }

usage() {
  cat <<USAGE
Usage: tools/dev.sh [options]

  -d, --device ID   Which device to run on — linux, windows, an Android device
                    id, or anything else \`flutter devices\` lists. Defaults to
                    this host's desktop, or to the only device attached.
  --android         The attached Android device or emulator, whatever its id.
  --profile         Run in profile mode. Release-like performance, with the
                    timeline still available. Hot reload is not.
  --release         Run in release mode. What an owner would actually get, and
                    the only mode worth judging performance or startup in.
                    Hot reload is not available.
  --clean           Delete the data this application has written — the catalog,
                    the cover cache, the play history and the preferences — so
                    the next start is a first launch. Never touches your music.
                    Asks first unless --yes.
  --generate        Regenerate the localizations before running. Needed after
                    changing either .arb catalog; hot reload will not pick that
                    up on its own.
  --test            Run the suite before starting, and stop if it is red.
  --no-run          Do everything asked except start the application.
  -y, --yes         Do not ask about --clean.
  -h, --help        Show this message.
USAGE
}

while [ $# -gt 0 ]; do
  case $1 in
    -d|--device) [ $# -ge 2 ] || fail "--device needs an id"; DEVICE=$2; shift 2 ;;
    --device=*) DEVICE=${1#--device=}; shift ;;
    --android) DEVICE="__android__"; shift ;;
    --profile) MODE="profile"; shift ;;
    --release) MODE="release"; shift ;;
    --clean) CLEAN="yes"; shift ;;
    --generate) GENERATE="yes"; shift ;;
    --test) TEST_FIRST="yes"; shift ;;
    --no-run) NO_RUN="yes"; shift ;;
    -y|--yes) ASSUME_YES="yes"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; fail "unknown option: $1" ;;
  esac
done

# ------------------------------------------------------------------- preflight

step "Preflight"
command -v flutter >/dev/null 2>&1 || fail "flutter is not on PATH"

HOST=$(uname -s)
note "host: $HOST $(uname -m)"

# libmpv is the one runtime dependency this application cannot bundle on Linux,
# and without it the engine throws the moment a player is constructed — which
# happens on the first press of play, not at startup. Checked here so that
# turns into a sentence now rather than a crash later.
if [ "$HOST" = "Linux" ]; then
  if command -v ldconfig >/dev/null 2>&1 && ! ldconfig -p 2>/dev/null | grep -q 'libmpv\.so'; then
    warn "libmpv was not found. Playback will fail the moment you press play."
    warn "  sudo apt install libmpv-dev mpv     # Debian and Ubuntu"
  fi
fi

# ----------------------------------------------------------------- the device

# Everything `flutter devices` can see, as "id<TAB>platform".
available_devices() {
  flutter devices --machine 2>/dev/null | python3 -c '
import json, sys
try:
    devices = json.load(sys.stdin)
except Exception:
    raise SystemExit(0)
for device in devices:
    print(device.get("id", ""), device.get("targetPlatform", ""), sep="\t")
' 2>/dev/null || true
}

DEVICES=$(available_devices)
[ -n "$DEVICES" ] || fail "flutter sees no devices at all; try \`flutter doctor\`"

if [ "$DEVICE" = "__android__" ]; then
  DEVICE=$(printf '%s\n' "$DEVICES" | awk -F'\t' '$2 ~ /^android/ {print $1; exit}')
  [ -n "$DEVICE" ] || fail "no Android device or emulator is attached"
fi

if [ -z "$DEVICE" ]; then
  # This host's own desktop, which is what someone typing `tools/dev.sh` with
  # no arguments almost always means.
  case $HOST in
    Linux) WANT="linux" ;;
    Darwin) WANT="macos" ;;
    *) WANT="" ;;
  esac

  if [ -n "$WANT" ] && printf '%s\n' "$DEVICES" | cut -f1 | grep -qx "$WANT"; then
    DEVICE=$WANT
  else
    # No desktop target: fall back to the only device attached, and refuse to
    # guess between several. Picking one for the owner is how you end up
    # watching a phone while wondering why the desktop did not change.
    COUNT=$(printf '%s\n' "$DEVICES" | grep -c . || true)
    if [ "$COUNT" = "1" ]; then
      DEVICE=$(printf '%s\n' "$DEVICES" | cut -f1)
    else
      printf '\033[31merror: several devices are attached; name one with --device\033[0m\n' >&2
      printf '%s\n' "$DEVICES" | while IFS="$(printf '\t')" read -r id platform; do
        printf '  %-24s %s\n' "$id" "$platform" >&2
      done
      exit 2
    fi
  fi
fi

printf '%s\n' "$DEVICES" | cut -f1 | grep -qx "$DEVICE" || {
  printf '\033[31merror: no device called %s. Attached:\033[0m\n' "$DEVICE" >&2
  printf '%s\n' "$DEVICES" | while IFS="$(printf '\t')" read -r id platform; do
    printf '  %-24s %s\n' "$id" "$platform" >&2
  done
  exit 2
}

DEVICE_PLATFORM=$(printf '%s\n' "$DEVICES" | awk -F'\t' -v d="$DEVICE" '$1 == d {print $2; exit}')
note "device: $DEVICE ($DEVICE_PLATFORM)"
note "mode: $MODE"

# ------------------------------------------------------------------- the data

# Where this application keeps the catalog, the cover cache, the play history
# and the preferences — per platform, and derived from the same rules
# path_provider uses rather than guessed.
app_data_directories() {
  case $DEVICE_PLATFORM in
    linux*)
      # path_provider_linux: $XDG_DATA_HOME (or ~/.local/share) plus the GTK
      # application id, with the executable name as a legacy fallback. Both are
      # named so a directory left by an older build is cleaned too.
      printf '%s/io.github.artur_rios.orpheus\n' "${XDG_DATA_HOME:-$HOME/.local/share}"
      printf '%s/orpheus\n' "${XDG_DATA_HOME:-$HOME/.local/share}"
      ;;
    windows*)
      # path_provider_windows: %APPDATA% plus CompanyName\ProductName, read
      # from the executable's own version info.
      [ -n "${APPDATA:-}" ] && printf '%s/io.github.artur_rios/orpheus\n' "$APPDATA"
      ;;
    *) ;;
  esac
}

clean_data() {
  step "Clearing this application's own data"

  case $DEVICE_PLATFORM in
    android*)
      note "on the device, via: adb shell pm clear io.github.artur_rios.orpheus"
      if [ "$ASSUME_YES" != "yes" ]; then
        printf '    Clear Orpheus'\''s data on the device? [y/N] '
        read -r answer
        case $answer in y|Y|yes|YES) ;; *) note "left alone"; return 0 ;; esac
      fi
      command -v adb >/dev/null 2>&1 || fail "adb is not on PATH"
      adb shell pm clear io.github.artur_rios.orpheus >/dev/null 2>&1 ||
        warn "nothing to clear; the application may not be installed yet"
      return 0
      ;;
  esac

  FOUND=""
  for directory in $(app_data_directories); do
    [ -d "$directory" ] && FOUND="$FOUND$directory
"
  done

  if [ -z "$FOUND" ]; then
    note "nothing to clear; this application has written nothing yet"
    return 0
  fi

  printf '%s' "$FOUND" | while IFS= read -r line; do
    [ -n "$line" ] && note "$line"
  done
  # Said explicitly, because this is the sentence someone needs to read before
  # answering: the folders you registered are forgotten, the music in them is
  # not touched.
  note "your music is not touched — only the catalog, covers, statistics and settings"

  if [ "$ASSUME_YES" != "yes" ]; then
    printf '    Delete the above? [y/N] '
    read -r answer
    case $answer in y|Y|yes|YES) ;; *) note "left alone"; return 0 ;; esac
  fi

  for directory in $(app_data_directories); do
    [ -d "$directory" ] && rm -rf "$directory"
  done
  note "cleared; the next start is a first launch"
}

[ "$CLEAN" = "yes" ] && clean_data

# --------------------------------------------------------------- code the run

step "Resolving dependencies"
flutter pub get >/dev/null || fail "dependencies could not be resolved"

if [ "$GENERATE" = "yes" ]; then
  step "Regenerating the localizations"
  # Hot reload does not pick up a changed .arb: the catalogs become Dart in a
  # build step, and the running application is holding the previous generation.
  flutter gen-l10n >/dev/null || fail "gen-l10n failed"
  note "run again, or press R, to see new strings"
fi

if [ "$TEST_FIRST" = "yes" ]; then
  step "Testing before starting"
  flutter test || fail "the suite is red; fix it before running"
fi

if [ "$NO_RUN" = "yes" ]; then
  step "Not running, as asked"
  exit 0
fi

# ----------------------------------------------------------------------- run it

step "Starting Orpheus"

if [ "$MODE" = "debug" ]; then
  note "r = hot reload    R = hot restart    q = quit"
  note "a change to a dependency, a native file or an .arb needs this script again"
else
  # Worth saying rather than letting someone press r into silence: Flutter only
  # offers hot reload in debug mode, and this is exactly the moment the habit
  # of pressing it does not work.
  note "no hot reload in $MODE mode — that is debug only"
fi

# The last line of this script on purpose: `flutter run` holds the terminal,
# and its exit code is this script's.
exec flutter run -d "$DEVICE" --"$MODE"
