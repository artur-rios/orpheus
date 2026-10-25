#!/usr/bin/env bash
# The release files built on Linux (`release.build` in yggdrasil.yml), run on the release agent from the checkout of
# the release's tag. It ports the version, linux and release jobs of the old release.yml; the Windows files are the
# release-windows.yml workflow. Everything lands in dist/:
#
#   dist/orpheus-installer-<version>.sh           the Linux installer
#   dist/orpheus-<version>-android.apk            the APK, signed with the release key
#   dist/SHA256SUMS-linux-android.txt             their checksums (the Windows files have their own list)
#
# The tag is the input: RELEASE_TAG and RELEASE_VERSION (the tag without its v) are set by the pipeline, which has
# already checked that the tag is on main. A run by hand sets neither ("dev"): it builds the same files from the
# working tree, and signs the APK with the debug key when it has no keystore, naming it -debug-signed.
#
# The Android signing values come from the Jenkins credentials of releaseCredentials:
#   ORPHEUS_KEYSTORE_BASE64     the keystore, base64-encoded (it was ANDROID_KEYSTORE_BASE64)
#   ORPHEUS_KEYSTORE_PASSWORD   its password (ANDROID_KEYSTORE_PASSWORD)
#   ORPHEUS_KEY_ALIAS           the key's alias (ANDROID_KEY_ALIAS)
#   ORPHEUS_KEY_PASSWORD        the key's password (ANDROID_KEY_PASSWORD)
# android/app/build.gradle.kts reads ORPHEUS_KEYSTORE (a path) and the other three. A release (RELEASE_VERSION set)
# without the keystore fails before the long builds start, as the old workflow did. The signer
# must have the fingerprint in android/signing-sha256.txt (it was the repository variable ANDROID_SIGNING_SHA256), or
# the one in ORPHEUS_SIGNING_SHA256, which overrides the file.
#
# The Linux build needs desktop packages the Flutter image does not carry; they are installed with apt when this
# runs as root, as it does on the release agent.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

release=no
[ -z "${RELEASE_VERSION:-}" ] || release=yes

# The whole version, pre-release included: v1.3.0-beta.1 is built from `version: 1.3.0-beta.1+<build>`, so the
# application reports itself as the beta it is and is offered 1.3.0 when that ships. Only the build number after `+`
# is left out: Android reads it, and it never names a different release.
version=$(sed -n 's/^version:[[:space:]]*\([^+[:space:]]*\).*/\1/p' pubspec.yaml | head -n 1)

# SemVer 2.0.0's own grammar, less build metadata. The update check parses the running version with the same rules,
# and a version it cannot read is a build that never offers an update.
semver='^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-(0|[1-9][0-9]*|[0-9]*[A-Za-z-][0-9A-Za-z-]*)(\.(0|[1-9][0-9]*|[0-9]*[A-Za-z-][0-9A-Za-z-]*))*)?$'
if ! printf '%s\n' "$version" | grep -Eq "$semver"; then
  echo "ci/release-build.sh: pubspec.yaml declares version '$version', which is not <major>.<minor>.<patch>[-<pre-release>][+<build>]" >&2
  exit 1
fi

# A tag that disagrees with pubspec.yaml produces a release whose file names, whose installer wizard and whose
# application all state different versions. Cheaper to refuse here than to explain later.
if [ "$release" = yes ]; then
  tag=${RELEASE_TAG:-v$RELEASE_VERSION}
  if [ "$tag" != "v$version" ] || [ "$RELEASE_VERSION" != "$version" ]; then
    echo "ci/release-build.sh: the tag $tag (version $RELEASE_VERSION) does not name version $version, which pubspec.yaml declares. A release is tagged v<version>, pre-release included: v$version" >&2
    exit 1
  fi
  echo "Releasing $version from $tag"
fi

# A release APK signed with the debug key cannot be installed over the last one: Android refuses an update whose
# signer changed, and the owner meets it as "App not installed" with no way forward but uninstalling and losing their
# library and statistics. Failing here is the point: an unupgradable package is worse than no package, and nothing
# is built before this says so. A partial set fails the same way: Gradle would refuse it too, but late.
if [ "$release" = yes ]; then
  for name in ORPHEUS_KEYSTORE_BASE64 ORPHEUS_KEYSTORE_PASSWORD ORPHEUS_KEY_ALIAS ORPHEUS_KEY_PASSWORD; do
    if [ -z "${!name:-}" ]; then
      echo "ci/release-build.sh: release $version needs $name (a Jenkins credential of releaseCredentials, orpheus-android-*); it is empty, so the APK would be signed with the debug key and must not be published. See 'The Android signing key' in CONTRIBUTING.md" >&2
      exit 1
    fi
  done
fi

# shellcheck source=ci/apt-packages.sh
source ci/apt-packages.sh
ensure_packages clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libstdc++-12-dev
# shellcheck source=ci/android-sdk.sh
source ci/android-sdk.sh
# Keep in step with compileSdk in android/app/build.gradle.kts.
ensure_android_package "platforms;android-37.0" platforms/android-37.0
# shellcheck source=ci/flutter-env.sh
source ci/flutter-env.sh

rm -rf dist
mkdir dist

# The decoded keystore and the signer listing live here, and go however this ends.
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# A container's root has no USER in its environment, and atomic_write_test.dart takes that for "not root" (it
# skips its read-only-file test only when USER is root) and then expects a superuser's write to a read-only file
# to be refused. A login sets USER; this does the same.
export USER=${USER:-$(id -un)}

# A release is not the place to find out the suite is red. The full cross-platform verification runs as the `linux`
# check and the Windows job on every push; what runs here is the part that is true on any host, as a gate on
# shipping.
flutter pub get
flutter analyze
flutter test

# ---- Linux ----
./tools/build-linux-installer.sh
[ -f "dist/orpheus-installer-$version.sh" ] || { echo "ci/release-build.sh: tools/build-linux-installer.sh made no dist/orpheus-installer-$version.sh" >&2; exit 1; }

# ---- Android ----
suffix=''
if [ -n "${ORPHEUS_KEYSTORE_BASE64:-}" ]; then
  # Whitespace stripped before decoding: the value is produced on whatever machine holds the keystore, and one
  # encoded on Windows arrives wrapped, carriage-returned, or both. A keystore that fails to decode is a cryptic way
  # to learn that.
  printf '%s' "$ORPHEUS_KEYSTORE_BASE64" | tr -d ' \t\r\n' | base64 -d >"$work/release.jks"
  test -s "$work/release.jks"
  export ORPHEUS_KEYSTORE=$work/release.jks
else
  echo "WARNING: no release keystore is set, so the Android APK is signed with the debug key. Do not distribute it." >&2
  suffix='-debug-signed'
fi
unset ORPHEUS_KEYSTORE_BASE64

flutter build apk --release
apk=build/app/outputs/flutter-apk/app-release.apk

# The signer, read back out of the package that actually ships: what the build was configured to do and what it did
# are two different claims.
apksigner=$(find "$ANDROID_HOME/build-tools" -name apksigner | sort -V | tail -n 1)
"$apksigner" verify --print-certs "$apk" | tee "$work/signer.txt"

if [ -z "$suffix" ] && grep -q 'CN=Android Debug' "$work/signer.txt"; then
  echo "ci/release-build.sh: the package is signed with the debug key. It could not be installed over the previous release." >&2
  exit 1
fi

fingerprint=$(sed -n 's/.*SHA-256 digest: *\([0-9a-f]\{64\}\).*/\1/p' "$work/signer.txt" | head -n 1)
if [ -z "$fingerprint" ]; then
  echo "ci/release-build.sh: could not read a signer fingerprint out of the package" >&2
  exit 1
fi
echo "Signed with SHA-256 $fingerprint"

# The release key must be the one this project has always published under: it is what catches a key rotated by
# accident, which every owner meets as an update they cannot install. The expected fingerprint is android/signing-sha256.txt
# (a public value, committed), and ORPHEUS_SIGNING_SHA256 in the environment overrides it. Only a debug-signed local
# run (no keystore) skips the comparison.
expected=${ORPHEUS_SIGNING_SHA256:-}
if [ -z "$expected" ] && [ -f android/signing-sha256.txt ]; then
  expected=$(grep -v '^[[:space:]]*#' android/signing-sha256.txt | tr -d ' \t\r\n:' || true)
fi
expected=$(printf '%s' "$expected" | tr 'A-F' 'a-f')
if [ -n "$expected" ] && ! printf '%s\n' "$expected" | grep -Eq '^[0-9a-f]{64}$'; then
  echo "ci/release-build.sh: the expected signing fingerprint '$expected' (android/signing-sha256.txt or ORPHEUS_SIGNING_SHA256) is not 64 hex characters" >&2
  exit 1
fi
if [ -z "$suffix" ] && [ -n "$expected" ]; then
  if [ "$expected" != "$fingerprint" ]; then
    echo "ci/release-build.sh: signed with $fingerprint, but this project publishes under $expected. An update signed by a different key cannot be installed over the last one." >&2
    exit 1
  fi
  echo "The signer is the one this project publishes under."
fi

# The same gate the linux check applies, against the package that actually ships rather than one built from the
# same source earlier.
ci/permissions.sh "$apk" "$work/permissions.txt"

cp "$apk" "dist/orpheus-$version-android$suffix.apk"

# Both installers are unsigned, so a checksum is the only way somebody can tell that what they downloaded is what
# was built. The Windows files have their own list, made by release-windows.yml.
(cd dist && sha256sum -- orpheus-* >SHA256SUMS-linux-android.txt)
ls -l dist
cat dist/SHA256SUMS-linux-android.txt
