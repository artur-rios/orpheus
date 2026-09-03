import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/stats/application/play_recorder.dart';
import 'package:orpheus/features/stats/domain/play_history.dart';

import '../../../support/fakes.dart';

/// Recording that a track was played.
void main() {
  final now = DateTime.utc(2026, 9, 3, 12);

  PlayRecorder recorderOver(InMemoryPlayHistoryStore store) =>
      PlayRecorder(store: store, clock: () => now);

  test(
    'GivenATrackNeverPlayed_WhenAPlayIsRecorded_ThenItIsWrittenWithOnePlay',
    () async {
      final store = InMemoryPlayHistoryStore();
      final recorder = recorderOver(store);

      await recorder.record('/library/a.flac');

      expect(store.history.tracks['/library/a.flac']!.plays, 1);
      expect(store.history.tracks['/library/a.flac']!.lastPlayedAt, now);
    },
  );

  test(
    'GivenATrackAlreadyPlayed_WhenItIsPlayedAgain_ThenTheCountGoesUp',
    () async {
      final store = InMemoryPlayHistoryStore();
      final recorder = recorderOver(store);

      await recorder.record('/library/a.flac');
      await recorder.record('/library/a.flac');

      expect(store.history.tracks['/library/a.flac']!.plays, 2);
      expect(store.history.totalPlays, 2);
    },
  );

  test(
    'GivenSeveralPlaysStartedAtOnce_WhenNoneOfThemIsAwaited_ThenEveryOneIsCounted',
    () async {
      // The player records without waiting, so two records can be in flight at
      // once. Two read-modify-writes racing over one document would lose
      // whichever landed second.
      final store = InMemoryPlayHistoryStore();
      final recorder = recorderOver(store);

      await Future.wait([
        recorder.record('/library/a.flac'),
        recorder.record('/library/a.flac'),
        recorder.record('/library/b.flac'),
      ]);

      expect(store.history.totalPlays, 3);
      expect(store.history.tracks['/library/a.flac']!.plays, 2);
      expect(store.history.tracks['/library/b.flac']!.plays, 1);
    },
  );

  test(
    'GivenAStoreThatWillNotWrite_WhenAPlayIsRecorded_ThenNothingIsThrownAtThePlayer',
    () async {
      // Stopping the music to report that a statistic went unrecorded would be
      // a worse failure than the missing statistic.
      final recorder = PlayRecorder(
        store: _RefusingStore(),
        clock: () => now,
      );

      await expectLater(recorder.record('/library/a.flac'), completes);
    },
  );

  test(
    'GivenAStoreThatWillNotWrite_WhenAPlayIsRecorded_ThenTheHeldHistoryStillCountsIt',
    () async {
      // The play the owner just earned is on screen whether or not the disk
      // cooperated.
      final recorder = PlayRecorder(store: _RefusingStore(), clock: () => now);

      await recorder.record('/library/a.flac');

      expect((await recorder.current()).totalPlays, 1);
    },
  );

  test(
    'GivenAStoredHistory_WhenTheRecorderIsAskedTwice_ThenTheStoreIsReadOnce',
    () async {
      final store = _CountingStore();
      final recorder = PlayRecorder(store: store, clock: () => now);

      await recorder.current();
      await recorder.current();

      expect(store.reads, 1);
    },
  );
}

/// A store whose writes always fail.
class _RefusingStore implements PlayHistoryStore {
  @override
  Future<PlayHistory> read() async => PlayHistory.empty;

  @override
  Future<void> write(PlayHistory history) async =>
      throw StateError('the history could not be written');
}

/// A store that counts how often it was read.
class _CountingStore implements PlayHistoryStore {
  int reads = 0;

  @override
  Future<PlayHistory> read() async {
    reads++;

    return PlayHistory.empty;
  }

  @override
  Future<void> write(PlayHistory history) async {}
}
