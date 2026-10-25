# shellcheck shell=bash
# Puts the pinned Flutter SDK on PATH. Sourced by the other scripts under ci/, not run.
#
# The workflows pinned Flutter 3.47.2 (subosito/flutter-action, `channel: stable`). The newest
# ghcr.io/cirruslabs/flutter image is 3.44.0, whose Dart (3.12) is older than pubspec.yaml's `sdk: ^3.13.2`, so
# the image only supplies the Android SDK, the JDK, git and curl, and the SDK itself is fetched here from
# Flutter's release archive and checked against its checksum. FLUTTER_SHA256 comes from
# https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json; change it together with
# FLUTTER_VERSION and the same version in .github/workflows/verify.yml and release-windows.yml.
#
# Renovate proposes new FLUTTER_VERSION values (the comment above it; stable releases only, no pre-releases);
# the pull request must carry the new checksum too, or the check stops at the checksum.
#
# FLUTTER_SDK_DIR reuses an unpacked SDK between runs (default: a directory under $TMPDIR).

# renovate: datasource=github-tags depName=flutter/flutter versioning=regex:^(?<major>\d+)\.(?<minor>\d+)\.(?<patch>\d+)$
FLUTTER_VERSION=3.47.2
FLUTTER_SHA256=447878859d01ca9bfdb99a85f245af07ed8a15fedcd9d189c4749e8e92d1f185

FLUTTER_SDK_DIR=${FLUTTER_SDK_DIR:-${TMPDIR:-/tmp}/flutter-$FLUTTER_VERSION}

if [ ! -x "$FLUTTER_SDK_DIR/bin/flutter" ]; then
  _flutter_work=$(mktemp -d)
  echo "ci/flutter-env.sh: fetching Flutter $FLUTTER_VERSION"
  curl --fail --silent --show-error --location --retry 3 -o "$_flutter_work/flutter.tar.xz" \
    "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
  echo "$FLUTTER_SHA256  $_flutter_work/flutter.tar.xz" | sha256sum -c -
  tar -xJf "$_flutter_work/flutter.tar.xz" --no-same-owner -C "$_flutter_work"
  mkdir -p "$(dirname "$FLUTTER_SDK_DIR")"
  rm -rf "$FLUTTER_SDK_DIR"
  mv "$_flutter_work/flutter" "$FLUTTER_SDK_DIR"
  rm -rf "$_flutter_work"
  unset _flutter_work
fi

export FLUTTER_ROOT=$FLUTTER_SDK_DIR
export FLUTTER_HOME=$FLUTTER_SDK_DIR
export PATH="$FLUTTER_SDK_DIR/bin:$FLUTTER_SDK_DIR/bin/cache/dart-sdk/bin:$PATH"
export CI=true

flutter config --no-analytics --no-cli-animations >/dev/null
dart --disable-analytics >/dev/null
flutter --version
