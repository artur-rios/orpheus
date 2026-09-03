import 'dart:typed_data';

/// Where cover pictures are kept.
///
/// Content-addressed: the id of a picture is a hash of its bytes, so the
/// twelve tracks of one record that each carry the same embedded JPEG store it
/// once. That is what keeps the cache proportional to the number of *records*
/// in a library rather than to the number of files.
///
/// Extracted at scan time rather than read on demand, for one reason: pulling
/// a picture out of a tag means parsing the file again, and a grid of a hundred
/// sleeves scrolling past would be a hundred parses a second.
abstract interface class CoverStore {
  /// Stores [bytes] and answers the id they are addressed by.
  ///
  /// Storing the same bytes twice is not an error and does not write twice.
  Future<String> put(Uint8List bytes);

  /// The bytes stored under [id], or `null` where none are.
  Future<Uint8List?> read(String id);

  /// Whether [id] is already stored.
  Future<bool> contains(String id);

  /// Removes every stored picture.
  Future<void> clear();
}

/// The id [bytes] are addressed by.
///
/// FNV-1a over the bytes, rendered as hex, with the length appended. A
/// non-cryptographic hash is the right tool — this is a cache key, not a
/// signature — and the length is what makes an accidental collision between
/// two different pictures need them to be the same size as well as to collide,
/// which in a personal library will not happen.
///
/// Written out here rather than taken from `crypto` for the same reason the
/// tag reader is pure Dart: it has to give the same answer in an isolate, in a
/// test, and on all three platforms, and a hash function is nine lines.
String coverIdOf(Uint8List bytes) {
  // The 64-bit FNV-1a parameters. Dart's `int` is 64-bit on every platform
  // this application targets, and the multiplication is allowed to overflow —
  // wrapping is what the algorithm specifies.
  var hash = 0xcbf29ce484222325;
  for (final byte in bytes) {
    hash ^= byte;
    hash = (hash * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
  }

  // Rendered as two unsigned halves rather than with `toRadixString` on the
  // whole thing: Dart's integers are signed, so half of all hashes would
  // otherwise render with a leading minus — a legal file name, and an ugly one
  // to find in a cache directory.
  final high = (hash >>> 32) & 0xFFFFFFFF;
  final low = hash & 0xFFFFFFFF;

  return '${high.toRadixString(16).padLeft(8, '0')}'
      '${low.toRadixString(16).padLeft(8, '0')}'
      '-${bytes.length}';
}
