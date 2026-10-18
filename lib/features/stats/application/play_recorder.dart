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
/// **A history that could not be read is never written over.** When the
/// store cannot read it — the file could not be opened, or could not be
/// understood and then could not be set aside — this run holds an empty
/// history and records nothing: writing one that knew only this run's plays
/// would replace years of them. The next start tries again.
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
  final StreamController<PlayHistory> _changes =
      StreamController<PlayHistory>.broadcast();

  /// Whether the store could not be read this run, which stops every write.
  bool _readFailed = false;

  /// Everything recorded so far.
  ///
  /// Read from the store once and held: the document is small, this object
  /// outlives every screen, and re-reading it per play would be a file read
  /// per track. Never an error: a history that could not be read is an empty
  /// one, for this run.
  Future<PlayHistory> current() => _loaded ??= _read();

  /// The history after each play is recorded, the whole of it each time.
  ///
  /// Only the changes: what was there before the first is [current]. Not
  /// heard when a play could not be recorded, because then nothing changed.
  Stream<PlayHistory> get changes => _changes.stream;

  /// Stops telling anyone about changes.
  void dispose() => unawaited(_changes.close());

  Future<PlayHistory> _read() async {
    try {
      return await store.read();
    } on Object catch (error) {
      _readFailed = true;
      _log.severe(
        'the play history could not be read; no plays will be recorded '
        'until the next start',
        error,
      );

      return PlayHistory.empty;
    }
  }

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
      final held = await current();
      if (_readFailed) return;

      final now = clock();
      // Trimmed as the store will write it, so what is held is what is on
      // disk and a run that never restarts holds no more than the window.
      final history = held.recording(path, now).trimmedTo(now);
      // Held before the write, not after: the in-memory history is what the
      // statistics screen reads, and a play the owner just earned should be
      // there whether or not the disk cooperated.
      _loaded = Future<PlayHistory>.value(history);
      if (!_changes.isClosed) _changes.add(history);

      await store.write(history);
    } on Object catch (error) {
      _log.warning('a play of $path could not be recorded', error);
    }
  }
}
