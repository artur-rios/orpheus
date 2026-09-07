#!/bin/sh
# Builds the Linux release and compiles it into a self-extracting installer.
#
# The counterpart of tools/build-windows-installer.ps1, and it works the same
# way: read the version from pubspec.yaml, build the release, and wrap the
# result in something a person can run. What differs is the wrapper. Windows has
# Inno Setup; Linux has no installer format every distribution agrees on, so the
# installer is a shell script with the bundle stuck to the end of it — see
# packaging/linux/installer.sh.in for why that rather than a .deb, a Flatpak or
# an AppImage.
#
# The output lands in dist/orpheus-installer-<version>.sh.
#
#   ./tools/build-linux-installer.sh
#   ./tools/build-linux-installer.sh --skip-build   # reuse the release build
#
# Needs the GTK development libraries, like any Linux build of this project.

set -eu

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$REPO_ROOT"

SKIP_BUILD="no"

step() { printf '\033[36m==> %s\033[0m\n' "$*"; }
note() { printf '\033[90m    %s\033[0m\n' "$*"; }
good() { printf '\033[32m%s\033[0m\n' "$*"; }
fail() { printf '\033[31merror: %s\033[0m\n' "$*" >&2; exit 2; }

while [ $# -gt 0 ]; do
  case "$1" in
    --skip-build) SKIP_BUILD="yes"; shift ;;
    -h|--help)
      sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) fail "unknown option: $1" ;;
  esac
done

# --------------------------------------------------------------- the version

# From pubspec.yaml rather than written here, so the installer's file name, the
# version it announces and the version the application reports cannot drift
# apart. The build metadata after `+` is dropped: it is shown to a person, and
# `1.0.0+1` reads as a typo.
step 'Reading the version'
VERSION=$(sed -n 's/^version:[[:space:]]*\([0-9]\+\.[0-9]\+\.[0-9]\+\).*/\1/p' pubspec.yaml | head -1)
[ -n "$VERSION" ] || fail 'pubspec.yaml does not declare a version of the form x.y.z'
note "version $VERSION"

# ----------------------------------------------------------------- the build

BUNDLE="$REPO_ROOT/build/linux/x64/release/bundle"

if [ "$SKIP_BUILD" = "yes" ]; then
  step 'Reusing the existing release build'
  [ -x "$BUNDLE/orpheus" ] || fail "no release build in $BUNDLE — run without --skip-build"
else
  step 'Building Linux (release)'
  flutter build linux --release || fail 'the Linux release build failed'
fi

# Checked rather than assumed, for the reason the Windows script checks it: an
# installer built from an incomplete bundle installs cleanly and then fails to
# start, which is the worst moment to find out.
[ -x "$BUNDLE/orpheus" ] || fail "the bundle holds no orpheus binary: $BUNDLE"
[ -d "$BUNDLE/data/flutter_assets" ] || fail 'the bundle holds no data/flutter_assets; the build is incomplete'
[ -d "$BUNDLE/lib" ] || fail 'the bundle holds no lib directory; the engine libraries are missing'
note "payload: $BUNDLE"

# ------------------------------------------------------------------ staging

# Staged rather than tarred in place, because one file that has to be in the
# payload is not in the bundle: the icon. `flutter build linux` does not emit
# one, and the desktop entry the installer writes needs it.
step 'Staging the payload'

STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT INT TERM

cp -a "$BUNDLE/." "$STAGE/"

ICON="$REPO_ROOT/linux/runner/resources/app_icon.png"
if [ -f "$ICON" ]; then
  cp "$ICON" "$STAGE/icon.png"
  note "icon from linux/runner/resources/app_icon.png"
else
  note 'no icon found; the launcher entry will fall back to a generic one'
fi

step 'Compressing'
PAYLOAD="$STAGE.tar.gz"
# Sorted and with a fixed owner so that two builds of the same tree produce the
# same archive rather than one that differs by whoever ran it.
tar czf "$PAYLOAD" --owner=0 --group=0 --numeric-owner --sort=name -C "$STAGE" .
trap 'rm -rf "$STAGE" "$PAYLOAD"' EXIT INT TERM
note "$(du -h "$PAYLOAD" | cut -f1) compressed"

# ------------------------------------------------------------------ assemble

step 'Assembling the installer'

TEMPLATE="$REPO_ROOT/packaging/linux/installer.sh.in"
[ -f "$TEMPLATE" ] || fail "no installer template at $TEMPLATE"

DIST="$REPO_ROOT/dist"
mkdir -p "$DIST"
INSTALLER="$DIST/orpheus-installer-$VERSION.sh"

HEADER="$STAGE.head"
sed "s/@APP_VERSION@/$VERSION/g" "$TEMPLATE" > "$HEADER"

# The payload begins on the line after the header's last. Substituted after the
# header is otherwise final, because the count has to describe the file that is
# actually written — and replacing a placeholder never changes a line count.
PAYLOAD_LINE=$(( $(wc -l < "$HEADER") + 1 ))
sed -i "s/@PAYLOAD_LINE@/$PAYLOAD_LINE/" "$HEADER"

# Parsed before the archive is stuck to it. The finished file cannot be checked
# this way: `sh -n` reads the whole of it and the payload is not shell, where a
# real shell stops at the `exit 0` above the marker and never sees those bytes.
sh -n "$HEADER" || fail 'the installer script does not parse'

cat "$HEADER" "$PAYLOAD" > "$INSTALLER"
rm -f "$HEADER"
chmod +x "$INSTALLER"

# Proved rather than trusted: read the payload back out of the finished file the
# same way the installer will, and confirm it is an archive holding the binary.
step 'Verifying the finished installer'
tail -n +$PAYLOAD_LINE "$INSTALLER" | tar tz >/dev/null 2>&1 ||
  fail 'the payload cannot be read back out of the installer'
tail -n +$PAYLOAD_LINE "$INSTALLER" | tar tz 2>/dev/null | grep -qx './orpheus' ||
  fail 'the payload does not contain the orpheus binary'
note 'payload readable at the stated line, and it holds the binary'

SIZE=$(du -h "$INSTALLER" | cut -f1)
echo ''
good "Built $INSTALLER ($SIZE)"
note 'Unsigned, like the Windows installer. Nothing here asks for root unless you choose --system.'
