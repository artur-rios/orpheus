import 'dart:io';
import 'dart:typed_data';

/// Replaces the file at [path] with [bytes]: whole, or not at all.
///
/// The bytes are written to a temporary file beside it and flushed to the
/// disk, and only then renamed over [path] — so a crash, a full disk or a
/// power cut partway leaves the old file or the new one, and never half a
/// music file. The temporary file is in the same directory because a rename
/// is only atomic within one volume, and its name is this write's own
/// (`<path>.orpheus-<pid>-<microseconds>.tmp`): another write of the same
/// file — another copy of Orpheus, say — never writes into it, nor has its
/// own replaced or deleted by this one.
///
/// A [path] that is a symbolic link is written through: the file it points
/// at is the one replaced (see [resolvedTarget]), and the link stays a link.
///
/// A file this process may not write is refused before anything is written.
/// A rename does not ask the file, only its directory: on Linux and macOS it
/// would replace a file its owner made read-only, which a write must not.
///
/// What the rename costs, and is chosen over writing in place for anyway —
/// in place, a failure partway leaves half a file:
/// - a hard-linked file is split: this name gets the new bytes, and its other
///   names, which nothing here can find, keep the old ones;
/// - the new file is a new file: on Linux and macOS it takes the default
///   permissions rather than the old file's, and on Windows it does not carry
///   over the old one's attributes or creation time.
///
/// Throws the [FileSystemException] of whatever failed, having deleted the
/// temporary file; the file is then as it was.
void replaceFileAtomically(String path, Uint8List bytes) {
  final resolved = resolvedTarget(path);
  final target = File(resolved);
  // Opening to append, and nothing more — and never a file that is not
  // there, which opening to append would create.
  if (target.existsSync()) target.openSync(mode: FileMode.append).closeSync();

  final temporary = File(
    '$resolved.orpheus-$pid-${DateTime.now().microsecondsSinceEpoch}.tmp',
  );
  try {
    temporary.writeAsBytesSync(bytes, flush: true);
    temporary.renameSync(resolved);
  } on Object {
    try {
      if (temporary.existsSync()) temporary.deleteSync();
    } on FileSystemException {
      // Nothing more to do about it here: the failure worth reporting is the
      // one that got here.
    }
    rethrow;
  }
}

/// The file a write to [path] has to replace: the one a symbolic link at
/// [path] points at, and otherwise [path] itself.
///
/// A rename over the link would replace the link — leaving the library a
/// detached copy with the new tags, and the real file without them.
///
/// Throws a [FileSystemException] for a link that points at nothing.
String resolvedTarget(String path) => FileSystemEntity.isLinkSync(path)
    ? File(path).resolveSymbolicLinksSync()
    : path;
