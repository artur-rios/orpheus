#!/bin/sh
# Fails unless the Linux executable loads the system's unwinder ahead of Flutter's engine.
#
#   ./tools/check-linux-unwinder.sh [build/linux/x64/release/bundle/orpheus]
#
# libflutter_linux_gtk.so carries LLVM's unwinder and exports it under libgcc's own names and symbol version
# (`_Unwind_RaiseException@GCC_3.0` and the rest). The dynamic linker binds a symbol to the first library in load
# order that defines it, so whatever loads after the engine and expects the system's unwinder gets the engine's
# instead. LuaJIT does: it raises every Lua error, including the ones a script catches itself, through
# `_Unwind_RaiseException`. The libmpv Arch builds (and so Omarchy's) runs its built-in scripts on LuaJIT, and with
# the engine's unwinder bound in their place a script's error kills the whole application with a segmentation
# fault, in the `lua/stats` thread, at the first song played. In a reproduction on mpv 0.42.0 it crashed between a
# third and a half of the plays with the engine loaded, and in none with libgcc_s.so.1 loaded first.
#
# linux/runner/CMakeLists.txt makes libgcc_s.so.1 the executable's first needed library, which puts it ahead of the
# engine and of every plugin in the lookup order. This is what holds it there: a regenerated runner, a CMake upgrade
# or a linker default that drops an unused library would undo it without a word, and the result builds, passes
# every test and crashes only on the machines whose libmpv uses LuaJIT.
#
# Run by ci/linux.sh (the `linux` check) and by tools/build-linux-installer.sh, on the bundle each one packages.
set -eu

binary=${1:-build/linux/x64/release/bundle/orpheus}
[ -f "$binary" ] || { echo "tools/check-linux-unwinder.sh: no executable at $binary" >&2; exit 1; }
command -v readelf >/dev/null 2>&1 || { echo "tools/check-linux-unwinder.sh: readelf (binutils) is needed" >&2; exit 1; }

first=$(readelf -dW "$binary" | sed -n 's/.*(NEEDED).*\[\(.*\)\]$/\1/p' | head -1)

if [ "$first" != "libgcc_s.so.1" ]; then
  echo "tools/check-linux-unwinder.sh: $binary loads ${first:-nothing} first, not libgcc_s.so.1." >&2
  echo "Flutter's engine would then stand in for the system's unwinder, and on a libmpv built with LuaJIT the" >&2
  echo "application crashes when it plays. linux/runner/CMakeLists.txt links libgcc_s.so.1 first; see there." >&2
  exit 1
fi

echo "$binary loads libgcc_s.so.1 first: the system's unwinder is the one bound."
