import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/stats/data/json_play_history_store.dart';
import 'package:orpheus/features/stats/domain/play_history.dart';

/// Keeping the play history on disk.
void main() {
  late Directory directory;
  late JsonPlayHistoryStore store;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('orpheus-plays');
    store = JsonPlayHistoryStore('${directory.path}/support');
  });

  tearDown(() async {
    if (directory.existsSync()) await directory.delete(recursive: true);
  });

  PlayHistory historyOf(Map<String, int> plays) => PlayHistory(
    tracks: {
      for (final played in plays.entries)
        played.key: TrackPlays(
          path: played.key,
          plays: played.value,
          lastPlayedAt: DateTime.utc(2026, 9, 3, 12),
        ),
    },
  );

  test(
    'GivenNothingHasBeenWritten_WhenTheHistoryIsRead_ThenItIsEmpty',
    () async {
      expect((await store.read()).isEmpty, isTrue);
    },
  );

  test(
    'GivenAHistory_WhenItIsWrittenAndReadBack_ThenEveryPlayComesBack',
    () async {
      await store.write(historyOf({'/library/a.flac': 3, '/library/b.flac': 1}));

      final read = await store.read();

      expect(read.totalPlays, 4);
      expect(read.tracks['/library/a.flac']!.plays, 3);
      expect(
        read.tracks['/library/a.flac']!.lastPlayedAt,
        DateTime.utc(2026, 9, 3, 12),
      );
    },
  );

  test(
    'GivenAHistoryWrittenTwice_WhenItIsReadBack_ThenTheSecondOneIsWhatIsThere',
    () async {
      await store.write(historyOf({'/library/a.flac': 1}));
      await store.write(historyOf({'/library/b.flac': 9}));

      final read = await store.read();

      expect(read.tracks.keys, ['/library/b.flac']);
    },
  );

  test(
    'GivenADocumentThatWillNotParse_WhenTheHistoryIsRead_ThenCountingStartsOverRatherThanFailing',
    () async {
      // Losing this file loses statistics and nothing else; an application
      // that would not start because of a counter is the worse failure.
      await Directory(store.directory).create(recursive: true);
      await File(store.path).writeAsString('{ this is not json');

      expect((await store.read()).isEmpty, isTrue);
    },
  );

  test(
    'GivenADocumentFromAnotherVersion_WhenTheHistoryIsRead_ThenCountingStartsOver',
    () async {
      await Directory(store.directory).create(recursive: true);
      await File(store.path).writeAsString('{"version": 99, "tracks": []}');

      expect((await store.read()).isEmpty, isTrue);
    },
  );

  test(
    'GivenADocumentWithAMalformedRow_WhenTheHistoryIsRead_ThenTheGoodRowsSurvive',
    () async {
      await Directory(store.directory).create(recursive: true);
      await File(store.path).writeAsString(
        '{"version": 1, "tracks": ['
        '{"path": "/library/a.flac", "plays": 2, "lastPlayedAt": "2026-09-03T12:00:00Z"},'
        '{"path": "", "plays": 5, "lastPlayedAt": "2026-09-03T12:00:00Z"},'
        '{"path": "/library/c.flac", "plays": 0, "lastPlayedAt": "2026-09-03T12:00:00Z"},'
        '{"path": "/library/d.flac", "plays": 1, "lastPlayedAt": "not a date"}'
        ']}',
      );

      final read = await store.read();

      expect(read.tracks.keys, ['/library/a.flac']);
      expect(read.totalPlays, 2);
    },
  );

  test(
    'GivenAHistoryIsWritten_WhenTheWriteFinishes_ThenNoTemporaryFileIsLeftBehind',
    () async {
      await store.write(historyOf({'/library/a.flac': 1}));

      // Written beside the real file and renamed over it, which is what makes
      // a history that survives the machine going down mid-track.
      expect(File('${store.path}.tmp').existsSync(), isFalse);
      expect(File(store.path).existsSync(), isTrue);
    },
  );
}
