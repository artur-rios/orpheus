import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../../core/di/providers.dart';
import '../domain/energy_store.dart';
import '../domain/track_energy.dart';

/// One track's measured spectrum, analysed once and kept.
///
/// Asynchronous because the first look at a track is a decode of all of it —
/// a second or so — and the screen cannot wait for that. It answers `null`
/// until the analysis lands and for anything that could not be analysed, and
/// the provider that composes it draws the stand-in in the meantime, so the
/// bars are never empty and never blocked on this.
///
/// Keyed by the track's path, and auto-disposed with it: a queue moves, and an
/// analysis per track ever played would be held in memory for the life of the
/// container. What is kept is on disk, where the next play of the same track
/// finds it.
class TrackEnergyController extends AsyncNotifier<MeasuredEnergy?> {
  /// Creates the controller for the track at [path].
  TrackEnergyController(this.path);

  static final Logger _log = Logger('playback');

  /// The track being analysed.
  final String path;

  @override
  Future<MeasuredEnergy?> build() async {
    // Both read before the first await, and deliberately: a decode takes a
    // second or two, and an owner who closes the player screen in the middle
    // of one disposes this. Reaching for a dependency after that throws, and
    // holding them from the start is what makes the analysis finish into the
    // cache instead of into an error nobody sees.
    final store = ref.read(energyStoreProvider);
    final analysis = ref.read(trackAnalysisProvider);

    final stat = await _stat();
    if (stat == null) return null;

    final id = energyIdOf(
      path: path,
      length: stat.size,
      modified: stat.modified,
    );

    final stored = await store.read(id);
    if (stored != null) return stored;

    final measured = await analysis.of(path);
    if (measured == null) return null;

    // Stored on a best effort: a full disk or a read-only cache directory
    // costs the analysis of this track again next time and nothing else, and
    // is not a reason to show no bars now.
    try {
      await store.put(id, measured);
    } on FileSystemException catch (error) {
      _log.fine('could not cache the analysis of $path', error);
    }

    return measured;
  }

  /// What the file system says about the track, or `null` where it is gone.
  Future<FileStat?> _stat() async {
    final stat = await File(path).stat();

    return stat.type == FileSystemEntityType.notFound ? null : stat;
  }
}
