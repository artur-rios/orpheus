import 'dart:async';

import 'package:logging/logging.dart';

import '../domain/play_history.dart';

/// Records that a track was played, and answers what has been recorded.
///
/// One owner of the history, deliberately. The player writes to it several
/// times an hour and the statistics screen reads it whenever it opens, and two
/// components each holding their own copy would be two answers to the same
/// question — the screen showing a total the last play is missing from.
///
/// **Recording never interrupts anything.** Everything this class cannot write
/// is swallowed and logged. Nothing the owner is doing depends on the number
/// going up, and stopping the music to report that a statistic went unrecorded
/// would be a worse failure than the missing statistic.
///
/// **Writes are serialized.** The player calls this without waiting — a track
/// crossing its threshold must not stall on a file write — so two records can
/// be in flight at once. Chained rather than concurrent, because two
/// read-modify-writes racing over one document lose whichever play landed
/// second.
class PlayRecorder {
  /// Creates a recorder over [store], stamping plays from [clock].
  PlayRecorder({required this.store, required this.clock});

  static final Logger _log = Logger('stats');

  /// Where the history is kept.
  final PlayHistoryStore store;

  /// What "now" is, so a test can pin it.
  final DateTime Function() clock;

  Future<PlayHistory>? _loaded;
  Future<void> _writes = Future<void>.value();

  /// Everything recorded so far.
  ///
  /// Read from the store once and held: the document is small, this object
  /// outlives every screen, and re-reading it per play would be a file read
  /// per track.
  Future<PlayHistory> current() => _loaded ??= store.read();

  /// Records one play of [path].
  ///
  /// Returns when the play has been written, which is what a test waits on;
  /// the player does not wait, and is not meant to.
  Future<void> record(String path) {
    _writes = _writes.then((_) => _record(path));

    return _writes;
  }

  Future<void> _record(String path) async {
    try {
      final history = (await current()).recording(path, clock());
      // Held before the write, not after: the in-memory history is what the
      // statistics screen reads, and a play the owner just earned should be
      // there whether or not the disk cooperated.
      _loaded = Future<PlayHistory>.value(history);

      await store.write(history);
    } on Object catch (error) {
      _log.warning('a play of $path could not be recorded', error);
    }
  }
}
