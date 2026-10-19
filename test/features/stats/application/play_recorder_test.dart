import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/stats/application/play_recorder.dart';
import 'package:orpheus/features/stats/data/json_play_history_store.dart';
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
    'GivenAPlayIsRecorded_WhenItIsWritten_ThenItCarriesItsDate',
    () async {
      final store = InMemoryPlayHistoryStore();
      final recorder = recorderOver(store);

      await recorder.record('/library/a.flac');

      expect(store.history.tracks['/library/a.flac']!.recent, [now]);
    },
  );

  test(
    'GivenDatesOlderThanNinetyDaysAreHeld_WhenAPlayIsRecorded_ThenTheyAreDroppedFromWhatIsHeldAndWritten',
    () async {
      final old = now.subtract(const Duration(days: 100));
      final store = InMemoryPlayHistoryStore(
        PlayHistory(
          tracks: {
            '/library/b.flac': TrackPlays(
              path: '/library/b.flac',
              plays: 6,
              lastPlayedAt: old,
              recent: [old],
            ),
          },
        ),
      );
      final recorder = recorderOver(store);

      await recorder.record('/library/a.flac');

      expect(store.history.tracks['/library/b.flac']!.recent, isEmpty);
      expect(store.history.tracks['/library/b.flac']!.plays, 6);
      expect((await recorder.current()).tracks['/library/b.flac']!.recent, isEmpty);
    },
  );

  test(
    'GivenAListener_WhenAPlayIsRecorded_ThenItHearsTheHistoryWithThePlayInIt',
    () async {
      final recorder = recorderOver(InMemoryPlayHistoryStore());
      final heard = <PlayHistory>[];
      final subscription = recorder.changes.listen(heard.add);
      addTearDown(subscription.cancel);

      await recorder.record('/library/a.flac');
      await pumpEventQueue();

      expect(heard, hasLength(1));
      expect(heard.single.tracks['/library/a.flac']!.plays, 1);
    },
  );

  test(
    'GivenAStoreThatCannotBeRead_WhenTheHistoryIsAskedFor_ThenItIsEmptyRatherThanAnError',
    () async {
      final recorder = PlayRecorder(store: _UnreadableStore(), clock: () => now);

      expect((await recorder.current()).isEmpty, isTrue);
    },
  );

  test(
    'GivenAStoreThatCannotBeRead_WhenPlaysAreRecorded_ThenNothingIsWrittenAndNothingIsThrownAtThePlayer',
    () async {
      // A history that could not be read must not be replaced by one that
      // knows only this run's plays.
      final store = _UnreadableStore();
      final recorder = PlayRecorder(store: store, clock: () => now);

      await expectLater(recorder.record('/library/a.flac'), completes);
      await expectLater(recorder.record('/library/b.flac'), completes);

      expect(store.writes, 0);
      expect((await recorder.current()).isEmpty, isTrue);
    },
  );

  test(
    'GivenAStoreThatCannotBeRead_WhenTheHistoryIsAskedFor_ThenTheReadFailedFlagIsSet',
    () async {
      final recorder = PlayRecorder(store: _UnreadableStore(), clock: () => now);

      await recorder.current();

      expect(recorder.readFailed, isTrue);
    },
  );

  test(
    'GivenAStoreThatCanBeRead_WhenTheHistoryIsAskedFor_ThenTheReadFailedFlagIsNotSet',
    () async {
      final recorder = recorderOver(InMemoryPlayHistoryStore());

      await recorder.current();

      expect(recorder.readFailed, isFalse);
    },
  );

  group('replaceHistory', () {
    final restored = PlayHistory(
      tracks: {
        '/library/r.flac': TrackPlays(
          path: '/library/r.flac',
          plays: 9,
          lastPlayedAt: DateTime.utc(2026, 9, 1),
        ),
      },
    );

    test(
      'GivenAHistory_WhenItIsReplaced_ThenItIsWrittenOnceHeldAndHeard',
      () async {
        final store = InMemoryPlayHistoryStore();
        final recorder = recorderOver(store);
        final heard = <PlayHistory>[];
        final subscription = recorder.changes.listen(heard.add);
        addTearDown(subscription.cancel);
        await recorder.record('/library/a.flac');
        final writesBefore = store.writes;

        await recorder.replaceHistory((_) => restored);
        await pumpEventQueue();

        expect(store.writes, writesBefore + 1);
        expect(store.history, same(restored));
        expect(await recorder.current(), same(restored));
        expect(heard.last, same(restored));
      },
    );

    test(
      'GivenAPlayStartedFirst_WhenTheHistoryIsReplaced_ThenTheReplacementIsWrittenAfterIt',
      () async {
        final store = InMemoryPlayHistoryStore();
        final recorder = recorderOver(store);

        await Future.wait([
          recorder.record('/library/a.flac'),
          recorder.replaceHistory((_) => restored),
        ]);

        expect(store.history, same(restored));
      },
    );

    test(
      'GivenAPlayQueuedBehindAWrite_WhenTheHistoryIsReplaced_ThenThePlanStartsFromItAndItIsKept',
      () async {
        // A restore works its history out from the one there is when its turn
        // comes, not when it asked: a play still waiting to be written would
        // otherwise be written over.
        final store = InMemoryPlayHistoryStore();
        final recorder = recorderOver(store);
        final gate = store.writeGate = Completer<void>();
        final first = recorder.record('/library/a.flac');
        final second = recorder.record('/library/b.flac');
        final seen = <PlayHistory>[];

        final replaced = recorder.replaceHistory((current) {
          seen.add(current);

          return PlayHistory(tracks: {...current.tracks, ...restored.tracks});
        });
        gate.complete();
        await Future.wait([first, second, replaced]);

        expect(seen.single.tracks.keys, ['/library/a.flac', '/library/b.flac']);
        expect(store.history.tracks.keys, [
          '/library/a.flac',
          '/library/b.flac',
          '/library/r.flac',
        ]);
      },
    );

    test(
      'GivenAPlanThatAnswersTheHistoryItWasGiven_WhenTheHistoryIsReplaced_ThenNothingIsWritten',
      () async {
        final store = InMemoryPlayHistoryStore();
        final recorder = recorderOver(store);
        await recorder.record('/library/a.flac');
        final writesBefore = store.writes;

        await recorder.replaceHistory((current) => current);

        expect(store.writes, writesBefore);
      },
    );

    test(
      'GivenAStoreThatCannotBeRead_WhenTheHistoryIsReplaced_ThenItThrowsAndWritesNothing',
      () async {
        final store = _UnreadableStore();
        final recorder = PlayRecorder(store: store, clock: () => now);
        final heard = <PlayHistory>[];
        final subscription = recorder.changes.listen(heard.add);
        addTearDown(subscription.cancel);

        await expectLater(recorder.replaceHistory((_) => restored), throwsStateError);
        await pumpEventQueue();

        expect(store.writes, 0);
        expect(heard, isEmpty);
        expect((await recorder.current()).isEmpty, isTrue);
      },
    );

    test(
      'GivenAStoreThatWillNotWrite_WhenTheHistoryIsReplaced_ThenItThrowsAndTheHeldHistoryStays',
      () async {
        final recorder = PlayRecorder(
          store: _RefusingStore(),
          clock: () => now,
        );
        final heard = <PlayHistory>[];
        final subscription = recorder.changes.listen(heard.add);
        addTearDown(subscription.cancel);

        await expectLater(recorder.replaceHistory((_) => restored), throwsStateError);
        await pumpEventQueue();

        expect(heard, isEmpty);
        expect((await recorder.current()).isEmpty, isTrue);
      },
    );

    test(
      'GivenAReplacementThatFailed_WhenAPlayIsRecordedAfter_ThenItIsStillRecorded',
      () async {
        final store = _FailingOnceStore();
        final recorder = PlayRecorder(store: store, clock: () => now);
        store.failNextWrite = true;

        await expectLater(recorder.replaceHistory((_) => restored), throwsStateError);
        await recorder.record('/library/a.flac');

        expect(store.history.tracks['/library/a.flac']!.plays, 1);
      },
    );
  });

  group('over the history on disk', () {
    late Directory directory;
    late JsonPlayHistoryStore store;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('orpheus-recorder');
      store = JsonPlayHistoryStore('${directory.path}/support', clock: () => now);
      await Directory(store.directory).create(recursive: true);
    });

    tearDown(() async {
      if (directory.existsSync()) await directory.delete(recursive: true);
    });

    test(
      'GivenAVersionOneHistory_WhenAPlayIsRecorded_ThenVersionTwoIsWrittenWithEveryCountKept',
      () async {
        await File(store.path).writeAsBytes(
          utf8.encode(
            '{"version":1,"tracks":['
            '{"path":"/library/a.flac","plays":12,"lastPlayedAt":"2026-09-03T12:00:00.000Z"},'
            '{"path":"/library/b.flac","plays":5,"lastPlayedAt":"2026-07-14T21:15:30.000Z"},'
            '{"path":"/library/c.flac","plays":3,"lastPlayedAt":"2025-12-31T23:59:59.999Z"}'
            ']}',
          ),
        );
        final recorder = PlayRecorder(store: store, clock: () => now);

        await recorder.record('/library/b.flac');

        final written = jsonDecode(File(store.path).readAsStringSync()) as Map<String, dynamic>;
        expect(written['version'], 2);
        expect(written['tracks'], [
          {
            'path': '/library/a.flac',
            'plays': 12,
            'lastPlayedAt': '2026-09-03T12:00:00.000Z',
            'recent': <String>[],
          },
          {
            'path': '/library/b.flac',
            'plays': 6,
            'lastPlayedAt': now.toIso8601String(),
            'recent': [now.toIso8601String()],
          },
          {
            'path': '/library/c.flac',
            'plays': 3,
            'lastPlayedAt': '2025-12-31T23:59:59.999Z',
            'recent': <String>[],
          },
        ]);
      },
    );

    test(
      'GivenAnUnreadableHistoryThatCannotBeSetAside_WhenPlaysAreRecorded_ThenTheFileIsNeverWrittenAndRecordStillCompletes',
      () async {
        final garbage = utf8.encode('{ not json, but the owner may want it back');
        await File(store.path).writeAsBytes(garbage);
        final blocker = Directory('${store.path}.bad-20260903T120000');
        await blocker.create();
        await File('${blocker.path}/keep').writeAsString('x');
        final recorder = PlayRecorder(store: store, clock: () => now);

        await expectLater(recorder.record('/library/a.flac'), completes);
        await expectLater(recorder.record('/library/a.flac'), completes);

        expect(File(store.path).readAsBytesSync(), garbage);
        expect(File('${store.path}.tmp').existsSync(), isFalse);
        expect((await recorder.current()).isEmpty, isTrue);
      },
    );

    test(
      'GivenAMalformedRowThatCannotBeCopiedAside_WhenPlaysAreRecorded_ThenTheFileIsNeverWritten',
      () async {
        // Writing the good rows alone would lose the bad row's count with no
        // copy of it anywhere.
        final bytes = utf8.encode(
          '{"version":2,"tracks":['
          '{"path":"/library/a.flac","plays":2,"lastPlayedAt":"2026-09-01T00:00:00.000Z","recent":[]},'
          '{"path":"/library/b.flac","plays":7,"lastPlayedAt":"not a date","recent":[]}'
          ']}',
        );
        await File(store.path).writeAsBytes(bytes);
        final blocker = Directory('${store.path}.bad-20260903T120000');
        await blocker.create();
        await File('${blocker.path}/keep').writeAsString('x');
        final recorder = PlayRecorder(store: store, clock: () => now);

        await expectLater(recorder.record('/library/a.flac'), completes);

        expect(File(store.path).readAsBytesSync(), bytes);
      },
    );
  });

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

/// A store whose file could not be read: locked, or unreadable and impossible
/// to set aside.
class _UnreadableStore implements PlayHistoryStore {
  int writes = 0;

  @override
  Future<PlayHistory> read() async =>
      throw const FileSystemException('the history could not be read');

  @override
  Future<void> write(PlayHistory history) async {
    writes++;
  }
}

/// A store in memory whose next write can be made to fail, once.
class _FailingOnceStore implements PlayHistoryStore {
  PlayHistory history = PlayHistory.empty;

  bool failNextWrite = false;

  @override
  Future<PlayHistory> read() async => history;

  @override
  Future<void> write(PlayHistory history) async {
    if (failNextWrite) {
      failNextWrite = false;
      throw StateError('the history could not be written');
    }

    this.history = history;
  }
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
