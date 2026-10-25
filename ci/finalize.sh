#!/usr/bin/env bash
# The checksums of a release (`release.finalize` in yggdrasil.yml), run on the release agent after the validation.
# RELEASE_FILES is the whole set the release uploads: release.build's files under build/ and the Windows workflow's
# under windows/<artifact>/. This writes one SHA256SUMS.txt over every one of them, the Linux installer, the APK and
# the two Windows files, as the old release.yml did:
#
#   <sha256>  ./<file name>
#
# in sha256sum's format, so `sha256sum -c SHA256SUMS.txt` run beside the downloaded files reads it, and the
# application's own update check (it finds the line for a package by the name after `./`) does too. Both installers
# are unsigned, so this is the only way somebody can tell that what they downloaded is what was built.
#
# It may only add to the set, so the list lands in release-sums/ (its `files` glob in yggdrasil.yml), outside
# $RELEASE_FILES. A release uploads one file per name, so two files of the set with the same name, or one that is
# already a SHA256SUMS, fail it here with the names.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

: "${RELEASE_FILES:?ci/finalize.sh: RELEASE_FILES is not set (the release agent sets it)}"
[ -d "$RELEASE_FILES" ] || { echo "ci/finalize.sh: RELEASE_FILES is not a directory: $RELEASE_FILES" >&2; exit 1; }

out=release-sums
rm -rf "$out"
mkdir "$out"

files=()
while IFS= read -r -d '' file; do
  files+=("$file")
done < <(find "$RELEASE_FILES" -type f -print0 | LC_ALL=C sort -z)
[ "${#files[@]}" -gt 0 ] || { echo "ci/finalize.sh: no release files in $RELEASE_FILES" >&2; exit 1; }

duplicates=$(for file in "${files[@]}"; do basename "$file"; done | LC_ALL=C sort | uniq -d)
if [ -n "$duplicates" ]; then
  echo "ci/finalize.sh: more than one release file is named: $(tr '\n' ' ' <<<"$duplicates")" >&2
  exit 1
fi

for file in "${files[@]}"; do
  name=$(basename "$file")
  case "$name" in
    SHA256SUMS*) echo "ci/finalize.sh: the release already has a $name; the checksums are made here" >&2; exit 1 ;;
  esac
  printf '%s  ./%s\n' "$(sha256sum -- "$file" | cut -d ' ' -f 1)" "$name"
done | LC_ALL=C sort -k 2 >"$out/SHA256SUMS.txt"

cat "$out/SHA256SUMS.txt"
