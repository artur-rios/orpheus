#!/usr/bin/env bash
# Reads the permissions a release APK ships out of the package and fails unless they are exactly the declared set.
# Run by ci/linux.sh (the `linux` check) and ci/release-build.sh, on the package each one built.
#
#   ci/permissions.sh <apk> [<file the aapt2 listing is kept in>]
#
# The enforceable form of "it asks for exactly this and nothing more". Asserted against the built APK rather than
# against the manifest, because the manifest that matters is the merged one: a dependency that quietly wants a
# permission gets it merged in, and this is where that shows up.
#
# An exact set rather than a deny list. INTERNET is here, declared and explained in AndroidManifest.xml, for the
# lyrics lookup and nothing else (NFR-02, BR-03); the point of pinning the whole set is that the next permission to
# arrive fails this check whatever it is, instead of only the ones somebody thought to forbid.
#
# The last entry is not declared in this repository's manifest and is not a capability. AndroidX Core injects it,
# namespaced to this application's own id, so that it can register a broadcast receiver that is not exported; it is
# signature-level, so nothing outside this package can hold it. It has shipped in every build this project has ever
# produced. It is pinned here rather than filtered out by prefix: a permission under our own namespace is still a
# permission, and the point of this check is that every one of them is written down somewhere.
set -euo pipefail

apk=${1:?usage: ci/permissions.sh <apk> [<listing file>]}
listing=${2:-}
[ -f "$apk" ] || { echo "ci/permissions.sh: no package at $apk" >&2; exit 1; }

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
[ -n "$listing" ] || listing=$work/permissions.txt
mkdir -p "$(dirname "$listing")"

aapt2=$(find "$ANDROID_HOME/build-tools" -name aapt2 | sort -V | tail -n 1)
"$aapt2" dump badging "$apk" | grep -E "uses-permission|sdkVersion" | tee "$listing"

cat >"$work/expected-permissions.txt" <<'PERMISSIONS'
android.permission.FOREGROUND_SERVICE
android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK
android.permission.INTERNET
android.permission.MANAGE_EXTERNAL_STORAGE
android.permission.POST_NOTIFICATIONS
android.permission.READ_EXTERNAL_STORAGE
android.permission.READ_MEDIA_AUDIO
android.permission.WAKE_LOCK
android.permission.WRITE_EXTERNAL_STORAGE
io.github.artur_rios.orpheus.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION
PERMISSIONS

sed -n "s/^uses-permission[^']*name='\([^']*\)'.*/\1/p" "$listing" | sort -u >"$work/shipped-permissions.txt"

if ! diff -u "$work/expected-permissions.txt" "$work/shipped-permissions.txt"; then
  echo "ci/permissions.sh: the package's permissions are not the declared set. Anything added here has to be explained in AndroidManifest.xml and in the specifications first." >&2
  exit 1
fi
echo "Exactly the declared permissions, as promised."
