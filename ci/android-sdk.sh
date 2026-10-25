# shellcheck shell=bash
# Sourced by the scripts under ci/ that build the APK (not run on its own).
#
#     ensure_android_package <sdkmanager package> <directory it installs to under $ANDROID_HOME>
#
# android/app/build.gradle.kts compiles against API 37 (`compileSdk = 37`), which the Flutter image's SDK (platform
# 36) does not have. Gradle can download it, but in the same build it then fails to find it ("Failed to find target
# with hash string 'android-37'": the package lands in platforms/android-37.0), so it is installed with sdkmanager
# first, as the SDK of the GitHub runner had it. The image has accepted the SDK licenses. Installing needs a
# writable SDK, which is root's in the image, as checks and release builds are on yggdrasil's agents.
ensure_android_package() {
  local package=$1 directory=$2
  if [ -d "$ANDROID_HOME/$directory" ]; then
    return 0
  fi
  if [ ! -w "$ANDROID_HOME" ]; then
    echo "ci/android-sdk.sh: $package must be installed, and $ANDROID_HOME is not writable by this user" >&2
    return 1
  fi
  sdkmanager --sdk_root="$ANDROID_HOME" "$package"
}
