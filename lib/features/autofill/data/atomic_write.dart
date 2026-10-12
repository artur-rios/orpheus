import 'dart:io';
import 'dart:typed_data';

/// Replaces the file at [path] with [bytes]: whole, or not at all.
///
/// The bytes are written to `<path>.orpheus-tmp` beside it and flushed to
/// the disk, and only then renamed over [path] — so a crash, a full disk or
/// a power cut partway leaves the old file or the new one, and never half a
/// music file. The temporary file is in the same directory because a rename
/// is only atomic within one volume.
///
/// A file this process may not write is refused before anything is written.
/// A rename does not ask the file, only its directory: on Linux and macOS it
/// would replace a file its owner made read-only, which a write must not.
///
/// Throws the [FileSystemException] of whatever failed, having deleted the
/// temporary file; [path] is then as it was.
void replaceFileAtomically(String path, Uint8List bytes) {
  final target = File(path);
  // Opening to append, and nothing more — and never a file that is not
  // there, which opening to append would create.
  if (target.existsSync()) target.openSync(mode: FileMode.append).closeSync();

  final temporary = File('$path.orpheus-tmp');
  try {
    temporary.writeAsBytesSync(bytes, flush: true);
    temporary.renameSync(path);
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
