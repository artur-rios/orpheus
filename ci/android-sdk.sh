# shellcheck shell=bash
# Sourced by the scripts under ci/ that build the APK (not run on its own).
#
#     ensure_android_platform
#
# android/app/build.gradle.kts compiles against API 37 (`compileSdk = 37`), which the Flutter image's SDK (platform
# 36) does not have. Gradle can download it, but in the same build it then fails to find it ("Failed to find target
# with hash string 'android-37'": the package lands in platforms/android-37.0), so it is installed with sdkmanager
# first, as the SDK of the GitHub runner had it. The package is derived from compileSdk, so it cannot drift from the
# build file: platforms;android-<N>.0 for `compileSdk = <N>`. A compileSdk written any other way (a property, a
# release(...) block) is not guessed at: this stops and says so. The image has accepted the SDK licenses. Installing
# needs a writable SDK, which is root's in the image, as checks and release builds are on yggdrasil's agents.
ensure_android_platform() {
  local level package directory
  level=$(sed -n 's/^[[:space:]]*compileSdk[[:space:]]*=[[:space:]]*\([0-9][0-9]*\)[[:space:]]*$/\1/p' android/app/build.gradle.kts | head -n 1)
  if [ -z "$level" ]; then
    echo "ci/android-sdk.sh: android/app/build.gradle.kts has no 'compileSdk = <number>' line; teach this script the new form" >&2
    return 1
  fi
  package="platforms;android-$level.0"
  directory="platforms/android-$level.0"
  if [ -d "$ANDROID_HOME/$directory" ] || [ -d "$ANDROID_HOME/platforms/android-$level" ]; then
    return 0
  fi
  if [ ! -w "$ANDROID_HOME" ]; then
    echo "ci/android-sdk.sh: $package must be installed (compileSdk is $level), and $ANDROID_HOME is not writable by this user" >&2
    return 1
  fi
  sdkmanager --sdk_root="$ANDROID_HOME" "$package"
}
