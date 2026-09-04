import 'track_energy.dart';

/// Where computed spectra are kept between runs.
///
/// Analysing a track means decoding all of it, which takes a second or two the
/// first time and would take the same second or two every time it was played.
/// This is what makes it once: the grid is small — about a hundred kilobytes
/// for a four-minute track — and it does not change unless the file does.
abstract interface class EnergyStore {
  /// The analysis stored under [id], or `null` where none is.
  Future<MeasuredEnergy?> read(String id);

  /// Stores [energy] under [id], replacing whatever was there.
  Future<void> put(String id, MeasuredEnergy energy);

  /// Removes every stored analysis.
  Future<void> clear();
}

/// The id the analysis of a track is stored under.
///
/// The path, the file's [length] and when it was last [modified], hashed
/// together with FNV-1a — the same hash and for the same reason as `coverIdOf`:
/// it is a cache key, it has to be the same on all three platforms and across
/// releases, and it is nine lines.
///
/// Length and modification time are in it so that a file replaced by a
/// different rip of the same track, at the same path, is analysed again rather
/// than drawn with the old one's spectrum.
String energyIdOf({
  required String path,
  required int length,
  required DateTime modified,
}) {
  var hash = 0xcbf29ce484222325;

  void mix(String text) {
    for (final unit in text.codeUnits) {
      hash ^= unit & 0xFF;
      hash = (hash * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
    }
  }

  mix(path);
  mix(' $length ${modified.millisecondsSinceEpoch}');

  // Two unsigned halves rather than `toRadixString` over the whole thing:
  // Dart's integers are signed, and half of all hashes would otherwise render
  // with a leading minus.
  final high = (hash >>> 32) & 0xFFFFFFFF;
  final low = hash & 0xFFFFFFFF;

  return '${high.toRadixString(16).padLeft(8, '0')}'
      '${low.toRadixString(16).padLeft(8, '0')}';
}
