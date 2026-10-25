#!/usr/bin/env bash
# The linux check (GitHub: verify.yml's "Linux and Android" job): the analyzer, the test suite and the release
# builds of Linux and Android (tools/verify.sh --strict), then the permissions the APK ships.
#
# The job apt-installed ninja-build and libgtk-3-dev on a runner that already had a C++ toolchain; the Flutter image
# has none of it, so the whole Linux desktop list is installed here when it is missing. That needs root, as checks
# have on yggdrasil's agents. So does the Android platform the build compiles against (API 37), which the image's SDK
# lacks (ci/android-sdk.sh); Gradle installs the NDK and the build tools itself.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

# shellcheck source=ci/apt-packages.sh
source ci/apt-packages.sh
ensure_packages clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libstdc++-12-dev
# shellcheck source=ci/android-sdk.sh
source ci/android-sdk.sh
# Keep in step with compileSdk in android/app/build.gradle.kts.
ensure_android_package "platforms;android-37.0" platforms/android-37.0
# shellcheck source=ci/flutter-env.sh
source ci/flutter-env.sh

# A container's root has no USER in its environment, and atomic_write_test.dart takes that for "not root" (it
# skips its read-only-file test only when USER is root) and then expects a superuser's write to a read-only file
# to be refused. A login sets USER; this does the same.
export USER=${USER:-$(id -un)}

# No --only: this builds both the targets it can. --strict turns a missing toolchain into a failing check; the
# Windows target is reported as not applicable rather than skipped, so it does not trip it.
./tools/verify.sh --strict

ci/permissions.sh build/app/outputs/flutter-apk/app-release.apk build/permissions.txt
