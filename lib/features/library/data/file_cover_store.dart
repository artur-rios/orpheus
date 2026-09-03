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
    // rather than twelve.
    if (!file.existsSync()) {
      await Directory(directory).create(recursive: true);
      await file.writeAsBytes(bytes, flush: true);
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

    if (!file.existsSync()) {
      Directory(directory).createSync(recursive: true);
      file.writeAsBytesSync(bytes, flush: true);
    }

    return id;
  }

  @override
  Future<Uint8List?> read(String id) async {
    final file = File(pathFor(id));
    if (!file.existsSync()) return null;

    return file.readAsBytes();
  }

  @override
  Future<bool> contains(String id) async => File(pathFor(id)).existsSync();

  @override
  Future<void> clear() async {
    final store = Directory(directory);
    if (store.existsSync()) await store.delete(recursive: true);
  }
}
