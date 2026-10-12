import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../domain/cover_store.dart';

/// [CoverStore] as a directory of files, one per distinct picture.
///
/// Plain files rather than a database: the pictures are the only large thing
/// this application caches, they are written once and read many times, and a
/// directory of them can be inspected, backed up, and deleted by the owner
/// without this application's help.
///
/// Usable from an isolate, which is where the scan actually writes them: it
/// holds a path and nothing else.
class FileCoverStore implements CoverStore {
  /// Creates a store over [directory].
  FileCoverStore(this.directory);

  /// Where the pictures are kept.
  final String directory;

  /// The path a picture with [id] is stored at.
  String pathFor(String id) => p.join(directory, id);

  @override
  Future<String> put(Uint8List bytes) async {
    final id = coverIdOf(bytes);
    final file = File(pathFor(id));

    // Same bytes, same id, same file: a picture already stored is not written
    // again, which is what makes an album of twelve tracks one picture on disk
    // rather than twelve. "Stored" means whole — see [_holdsWhole] — so a
    // picture a killed scan left half-written is written again rather than
    // kept for good.
    if (!_holdsWhole(file, id)) {
      await Directory(directory).create(recursive: true);
      final partial = File(_partialPathFor(id));
      await partial.writeAsBytes(bytes, flush: true);
      try {
        await partial.rename(file.path);
      } on FileSystemException {
        _settleFailedMove(partial, file, id);
      }
    }

    return id;
  }

  /// [put], synchronously.
  ///
  /// The scan runs on an isolate of its own and is entirely IO-bound; awaiting
  /// each of several thousand small writes there buys nothing and costs a
  /// microtask apiece.
  String putSync(Uint8List bytes) {
    final id = coverIdOf(bytes);
    final file = File(pathFor(id));

    if (!_holdsWhole(file, id)) {
      Directory(directory).createSync(recursive: true);
      final partial = File(_partialPathFor(id));
      partial.writeAsBytesSync(bytes, flush: true);
      try {
        partial.renameSync(file.path);
      } on FileSystemException {
        _settleFailedMove(partial, file, id);
      }
    }

    return id;
  }

  /// Whether [file] holds the whole of the picture [id] names.
  ///
  /// The id ends in the picture's length — see `coverIdOf` — so a file of any
  /// other length is not that picture, whatever its name says. Before the
  /// writes went through [_partialPathFor] a scan killed mid-write left a
  /// truncated file at the final path, and with existence the only test it was
  /// never written again: a sleeve cut off halfway down, for good. The
  /// renamed write means no new file can be caught half-written; this is what
  /// repairs the ones an earlier version already left behind.
  ///
  /// An id with no length on the end is taken at its word, where the file
  /// exists — this store did not name it, and has nothing to check it against.
  bool _holdsWhole(File file, String id) {
    try {
      if (!file.existsSync()) return false;

      final length = int.tryParse(id.substring(id.lastIndexOf('-') + 1));

      return length == null || file.lengthSync() == length;
    } on FileSystemException {
      // Gone between the two questions, or unreadable: not stored, either way.
      return false;
    }
  }

  /// Where a picture with [id] is written before it is moved into place.
  ///
  /// Beside the final path, in the same directory, because a rename within
  /// one directory is what every platform this runs on does all at once: a
  /// reader of [pathFor] finds the old file or the new one, never a file
  /// still being written. Named after this process and the moment as well as
  /// the id, so two writers storing the same picture at once — the scan's
  /// isolate and the application — never write into each other's file.
  ///
  /// One that a killed write leaves behind is never read: nothing looks a
  /// picture up by any name but its id, and [clear] takes it with the rest.
  String _partialPathFor(String id) =>
      '${pathFor(id)}.$pid-${DateTime.now().microsecondsSinceEpoch}.partial';

  /// Tidies up after [partial] could not be moved onto [file].
  ///
  /// Which is not necessarily a failure: on Windows a rename onto a file
  /// another reader holds open is refused, and a concurrent writer may have
  /// put the same picture in place first. Either way, a whole picture at
  /// [file] is the answer that was wanted, so only its absence is an error.
  void _settleFailedMove(File partial, File file, String id) {
    try {
      partial.deleteSync();
    } on FileSystemException {
      // Left for [clear]; it is never read in the meantime.
    }

    if (!_holdsWhole(file, id)) {
      throw FileSystemException('Could not store the picture', file.path);
    }
  }

  @override
  Future<Uint8List?> read(String id) async {
    final file = File(pathFor(id));
    if (!_holdsWhole(file, id)) return null;

    return file.readAsBytes();
  }

  @override
  Future<bool> contains(String id) async => _holdsWhole(File(pathFor(id)), id);

  @override
  Future<String?> locationOf(String id) async {
    final file = File(pathFor(id));

    // Checked rather than handed over unread: a path to a picture that is not
    // there would be a notification that shows a blank square where the sleeve
    // should be, and answering `null` is what makes it show the application's
    // own icon instead.
    return _holdsWhole(file, id) ? file.path : null;
  }

  @override
  Future<void> clear() async {
    final store = Directory(directory);
    if (store.existsSync()) await store.delete(recursive: true);
  }
}
