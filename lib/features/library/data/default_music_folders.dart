import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/platform/host_platform.dart';

/// The folders a first launch offers to add.
///
/// Offered, never added silently: an application that indexed a folder nobody
/// pointed it at is an application that read files nobody asked it to. What
/// this list buys is that the owner's answer is usually one button rather than
/// a walk through a folder chooser.
///
/// Only folders that exist are returned, so the offer is never for somewhere
/// that is not there — and each of them once, by where it leads rather than how
/// it is spelled.
List<String> defaultMusicFolders({HostPlatform platform = const HostPlatform()}) {
  final candidates = <String>[];

  if (platform.isAndroid) {
    // The conventional shared-storage locations. `/sdcard` is the symlink
    // every Android release has kept pointing at the primary volume, and
    // `/storage/emulated/0` is what it points to; both are listed because a
    // device that has renamed one has usually kept the other. On a device
    // that has kept both they are one folder, and only the first is offered
    // — see below.
    candidates.addAll([
      '/storage/emulated/0/Music',
      '/sdcard/Music',
      '/storage/emulated/0/Download',
    ]);
  } else {
    final home = platform.homeDirectory;
    if (home != null) {
      candidates.add(p.join(home, 'Music'));
      // The XDG name, for a Linux desktop set to a language that localises it.
      final xdg = Platform.environment['XDG_MUSIC_DIR'];
      if (xdg != null && xdg.isNotEmpty) candidates.add(xdg);
    }
  }

  final existing = <String>[];
  // Where each offered folder actually leads. Comparing the paths as written
  // offered `/sdcard/Music` and `/storage/emulated/0/Music` side by side on
  // every ordinary phone, and registered the same music twice when both were
  // accepted.
  final targets = <String>{};
  for (final candidate in candidates) {
    try {
      final directory = Directory(candidate);
      if (!directory.existsSync()) continue;
      if (targets.add(p.normalize(directory.resolveSymbolicLinksSync()))) {
        existing.add(p.normalize(candidate));
      }
    } on Object {
      // A path the process may not even stat is a path there is no point
      // offering.
      continue;
    }
  }

  return existing;
}
