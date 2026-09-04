import 'dart:io';

import 'package:path/path.dart' as p;

import '../domain/energy_store.dart';
import '../domain/track_energy.dart';

/// [EnergyStore] as a directory of files, one per analysed track.
///
/// Plain files for the reason the cover cache is plain files: they are written
/// once and read many times, and a directory of them can be inspected, backed
/// up, and deleted by the owner without this application's help. Deleting one
/// costs nothing but the second it takes to analyse that track again.
class FileEnergyStore implements EnergyStore {
  /// Creates a store over [directory].
  const FileEnergyStore(this.directory);

  /// What an analysis file is called.
  static const String extension = '.bars';

  /// Where the analyses are kept.
  final String directory;

  /// The path the analysis with [id] is stored at.
  String pathFor(String id) => p.join(directory, '$id$extension');

  @override
  Future<MeasuredEnergy?> read(String id) async {
    final file = File(pathFor(id));
    if (!file.existsSync()) return null;

    // A cache file that cannot be read is not an error: it is one written by
    // an older version of this application, or one a disk truncated, and
    // either way the answer is to analyse the track again.
    try {
      return MeasuredEnergy.fromBytes(await file.readAsBytes());
    } on FileSystemException {
      return null;
    }
  }

  @override
  Future<void> put(String id, MeasuredEnergy energy) async {
    await Directory(directory).create(recursive: true);
    await File(pathFor(id)).writeAsBytes(energy.toBytes(), flush: true);
  }

  @override
  Future<void> clear() async {
    final store = Directory(directory);
    if (store.existsSync()) await store.delete(recursive: true);
  }
}
