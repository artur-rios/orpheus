import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// What this process can actually see of a folder that would not open.
///
/// A diagnostic, not a feature. "This folder was not there" is the truth an
/// ordinary read can tell and no help at all in deciding *why* — a path that
/// names nothing, a path denied, and a volume missing from this process's
/// mount namespace all arrive as the same false from `existsSync`. This walks
/// the same path with every question asked separately and reports the errno,
/// which is what tells those three apart.
///
/// Reads only. It stats and lists; it opens nothing and writes nothing.
Future<String> probeStorage(String folder) async {
  final out = StringBuffer()
    ..writeln('folder: $folder')
    ..writeln('platform: ${Platform.operatingSystem} '
        '${Platform.operatingSystemVersion}');

  // The permission as this process sees it, rather than as the settings screen
  // last reported it. They can differ: the grant is recorded against the uid,
  // and what a running process may reach was settled when it started.
  if (Platform.isAndroid) {
    final manage = await Permission.manageExternalStorage.status;
    final audio = await Permission.audio.status;
    out.writeln('manageExternalStorage: $manage');
    out.writeln('audio: $audio');
  }

  // Every ancestor, because the level that fails is the answer. A denial at
  // /storage/<volume> is a permission; nothing there at all, while the drive
  // is plainly mounted, is a mount this process was never handed.
  out.writeln('--- path, one level at a time ---');
  for (final step in _ancestors(folder)) {
    out.writeln('$step  ${_describe(step)}');
  }

  // Where the volumes would show up if this process could see them at all.
  out.writeln('--- volumes ---');
  for (final root in const ['/storage', '/mnt/media_rw', '/mnt/user/0']) {
    out.writeln('$root  ${_describe(root)}');
  }

  // The app-specific directory on each volume the system knows about for this
  // application. A volume that appears here is one this process can reach; a
  // drive that is mounted and absent from this list is the whole of the bug.
  if (Platform.isAndroid) {
    out.writeln('--- external storage directories ---');
    try {
      final dirs = await getExternalStorageDirectories();
      if (dirs == null || dirs.isEmpty) {
        out.writeln('(none)');
      } else {
        for (final dir in dirs) {
          out.writeln(dir.path);
        }
      }
    } on Object catch (error) {
      out.writeln('failed: $error');
    }
  }

  return out.toString();
}

/// [folder] and every directory above it, root first.
List<String> _ancestors(String folder) {
  final steps = <String>[];
  var current = p.normalize(folder);
  while (true) {
    steps.add(current);
    final parent = p.dirname(current);
    if (parent == current) break;
    current = parent;
  }

  return steps.reversed.toList();
}

/// What one path answers to each question asked on its own.
String _describe(String path) {
  final parts = <String>[];

  try {
    parts.add('type=${FileSystemEntity.typeSync(path, followLinks: false)}');
  } on Object catch (error) {
    parts.add('type threw ${_brief(error)}');
  }

  try {
    parts.add('exists=${Directory(path).existsSync()}');
  } on Object catch (error) {
    parts.add('exists threw ${_brief(error)}');
  }

  try {
    final children = Directory(path).listSync(followLinks: false);
    parts.add('list=${children.length}');
    // Named, because the volume id this run can see is exactly what a
    // registered path that names nothing has to be compared against.
    if (path == '/storage' || path == '/mnt/media_rw' || path == '/mnt/user/0') {
      parts.add('[${children.map((e) => p.basename(e.path)).join(', ')}]');
    }
  } on Object catch (error) {
    parts.add('list threw ${_brief(error)}');
  }

  return parts.join('  ');
}

/// The errno and message, without the path repeated back on every line.
String _brief(Object error) {
  if (error is FileSystemException) {
    final os = error.osError;

    return os == null
        ? error.message
        : '${error.message}: ${os.message} (errno ${os.errorCode})';
  }

  return error.toString();
}
