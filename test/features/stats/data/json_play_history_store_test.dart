import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/library/domain/music_catalog.dart';
import 'package:orpheus/features/library/domain/music_grouping.dart';
import 'package:orpheus/features/stats/data/json_play_history_store.dart';
import 'package:orpheus/features/stats/domain/music_stats.dart';
import 'package:orpheus/features/stats/domain/play_history.dart';

import '../../../support/entries.dart';

/// A version-1 document exactly as the version-1 writer wrote it: `jsonEncode`
/// with no whitespace, times in UTC with milliseconds, UTF-8, and a Windows
/// path with letters outside ASCII. Checked byte for byte against that writer
/// before it was replaced — this is what the owner's own file looks like.
const String _v1Document =
    '{"version":1,"tracks":['
    '{"path":"/library/zzz-ok1.flac","plays":12,"lastPlayedAt":"2026-09-03T12:00:00.000Z"},'
    '{"path":"/library/zzz-blue.flac","plays":5,"lastPlayedAt":"2026-07-14T21:15:30.000Z"},'
    r'{"path":"D:\\Música\\Björk\\Jóga.flac","plays":3,"lastPlayedAt":"2025-12-31T23:59:59.999Z"}'
    ']}';

/// Keeping the play history on disk.
void main() {
  final now = DateTime.utc(2026, 10, 18, 12, 30, 5);
  const stamp = '20261018T123005';

  late Directory directory;
  late JsonPlayHistoryStore store;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('orpheus-plays');
    store = JsonPlayHistoryStore('${directory.path}/support', clock: () => now);
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

  /// Puts [bytes] where the history is kept, as if a run before wrote them.
  Future<void> seed(List<int> bytes) async {
    await Directory(store.directory).create(recursive: true);
    await File(store.path).writeAsBytes(bytes);
  }

  /// The document on disk, decoded.
  Map<String, dynamic> onDisk() =>
      jsonDecode(File(store.path).readAsStringSync()) as Map<String, dynamic>;

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
    'GivenAHistoryWithDatedPlays_WhenItIsWrittenAndReadBack_ThenTheDatesComeBackInOrderAndInUtc',
    () async {
      final first = DateTime.utc(2026, 10, 1, 8);
      final second = DateTime.utc(2026, 10, 17, 22, 5, 1, 250);
      await store.write(
        PlayHistory(
          tracks: {
            '/library/a.flac': TrackPlays(
              path: '/library/a.flac',
              plays: 40,
              lastPlayedAt: second,
              recent: [first, second],
            ),
            '/library/b.flac': TrackPlays(
              path: '/library/b.flac',
              plays: 2,
              lastPlayedAt: DateTime.utc(2025),
            ),
          },
        ),
      );

      final read = await store.read();

      expect(read.tracks['/library/a.flac']!.plays, 40);
      expect(read.tracks['/library/a.flac']!.recent, [first, second]);
      expect(read.tracks['/library/a.flac']!.recent.every((at) => at.isUtc), isTrue);
      expect(read.tracks['/library/b.flac']!.recent, isEmpty);
    },
  );

  test(
    'GivenAHistoryWithDatedPlays_WhenItIsWritten_ThenTheDocumentIsVersionTwoWithIsoUtcDates',
    () async {
      await store.write(
        PlayHistory(
          tracks: {
            '/library/a.flac': TrackPlays(
              path: '/library/a.flac',
              plays: 1,
              lastPlayedAt: DateTime.utc(2026, 10, 17, 22),
              recent: [DateTime.utc(2026, 10, 17, 22)],
            ),
          },
        ),
      );

      expect(onDisk(), {
        'version': 2,
        'tracks': [
          {
            'path': '/library/a.flac',
            'plays': 1,
            'lastPlayedAt': '2026-10-17T22:00:00.000Z',
            'recent': ['2026-10-17T22:00:00.000Z'],
          },
        ],
      });
    },
  );

  test(
    'GivenDatesOlderThanNinetyDays_WhenTheHistoryIsWritten_ThenOnlyTheDatesAreLeftOut',
    () async {
      final old = now.subtract(const Duration(days: 120));
      final recent = now.subtract(const Duration(days: 1));
      await store.write(
        PlayHistory(
          tracks: {
            '/library/a.flac': TrackPlays(
              path: '/library/a.flac',
              plays: 9,
              lastPlayedAt: recent,
              recent: [old, recent],
            ),
          },
        ),
      );

      final written = (onDisk()['tracks'] as List).single as Map<String, dynamic>;
      expect(written['plays'], 9);
      expect(written['recent'], [recent.toIso8601String()]);
    },
  );

  test(
    'GivenAStoredDocumentWithDatesOlderThanNinetyDays_WhenItIsRead_ThenThoseDatesAreDropped',
    () async {
      // Written by a run long ago: the window has moved on since.
      await seed(
        utf8.encode(
          '{"version":2,"tracks":[{"path":"/library/a.flac","plays":3,'
          '"lastPlayedAt":"2026-10-10T00:00:00.000Z",'
          '"recent":["2026-06-01T00:00:00.000Z","2026-10-10T00:00:00.000Z"]}]}',
        ),
      );

      final read = await store.read();

      expect(read.tracks['/library/a.flac']!.plays, 3);
      expect(read.tracks['/library/a.flac']!.recent, [DateTime.utc(2026, 10, 10)]);
    },
  );

  test(
    'GivenAVersionOneDocument_WhenTheHistoryIsRead_ThenEveryTrackIsKeptWithItsCountAndNoDates',
    () async {
      // The owner's own history, from before plays were dated. Nothing in it
      // is lost: the counts and the last plays are carried over as they are.
      await seed(utf8.encode(_v1Document));

      final read = await store.read();

      expect(read.distinctTracks, 3);
      expect(read.totalPlays, 20);
      expect(read.tracks['/library/zzz-ok1.flac']!.plays, 12);
      expect(
        read.tracks['/library/zzz-ok1.flac']!.lastPlayedAt,
        DateTime.utc(2026, 9, 3, 12),
      );
      expect(read.tracks['/library/zzz-blue.flac']!.plays, 5);
      expect(
        read.tracks['/library/zzz-blue.flac']!.lastPlayedAt,
        DateTime.utc(2026, 7, 14, 21, 15, 30),
      );
      expect(read.tracks[r'D:\Música\Björk\Jóga.flac']!.plays, 3);
      expect(
        read.tracks[r'D:\Música\Björk\Jóga.flac']!.lastPlayedAt,
        DateTime.utc(2025, 12, 31, 23, 59, 59, 999),
      );
      for (final track in read.tracks.values) {
        expect(track.recent, isEmpty);
      }
      expect(Directory(store.directory).listSync(), hasLength(1));
    },
  );

  test(
    'GivenAVersionOneDocument_WhenItsStatisticsAreWorkedOut_ThenTheyAreTheNumbersTheOldReaderGave',
    () async {
      // The statistics screen must not show different numbers for the same
      // history because its format changed. The old reader's history is
      // built by hand from the same document, and both are pinned.
      final catalog = MusicCatalog(
        entries: albumArtistsAcross([
          entry(id: 'ok1', title: 'Airbag', artist: 'Radiohead', album: 'OK Computer', genres: ['Rock']),
          entry(id: 'blue', title: 'So What', artist: 'Miles Davis', album: 'Kind of Blue', genres: ['Jazz']),
        ]),
      );
      final readTheOldWay = PlayHistory(
        tracks: {
          '/library/zzz-ok1.flac': TrackPlays(
            path: '/library/zzz-ok1.flac',
            plays: 12,
            lastPlayedAt: DateTime.utc(2026, 9, 3, 12),
          ),
          '/library/zzz-blue.flac': TrackPlays(
            path: '/library/zzz-blue.flac',
            plays: 5,
            lastPlayedAt: DateTime.utc(2026, 7, 14, 21, 15, 30),
          ),
          r'D:\Música\Björk\Jóga.flac': TrackPlays(
            path: r'D:\Música\Björk\Jóga.flac',
            plays: 3,
            lastPlayedAt: DateTime.utc(2025, 12, 31, 23, 59, 59, 999),
          ),
        },
      );
      await seed(utf8.encode(_v1Document));

      final migrated = musicStatsFrom(history: await store.read(), catalog: catalog);
      final before = musicStatsFrom(history: readTheOldWay, catalog: catalog);

      List<(String, int, double?)> lines(List<RankedPlays> ranking) => [
        for (final line in ranking) (line.name, line.plays, line.share),
      ];
      for (final stats in [migrated, before]) {
        expect(stats.totalPlays, 20);
        expect(stats.distinctTracks, 3);
        expect(stats.untaggedTracks, 0);
        expect(lines(stats.tracks), [
          ('Airbag', 12, 12 / 20),
          ('So What', 5, 5 / 20),
          ('Jóga.flac', 3, 3 / 20),
        ]);
        expect(lines(stats.artists), [('Radiohead', 12, 12 / 17), ('Miles Davis', 5, 5 / 17)]);
        expect(lines(stats.albums), [('OK Computer', 12, 12 / 17), ('Kind of Blue', 5, 5 / 17)]);
        expect(lines(stats.genres), [('Rock', 12, 12 / 20), ('Jazz', 5, 5 / 20)]);
      }
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
    'GivenADocumentThatWillNotParse_WhenTheHistoryIsRead_ThenItIsKeptAsideWithItsBytesAndTheHistoryIsEmpty',
    () async {
      // The owner's history is as much theirs as their playlists: what could
      // not be read is kept for recovery, never overwritten by the next play.
      final garbage = utf8.encode('{ this is not json');
      await seed(garbage);

      expect((await store.read()).isEmpty, isTrue);

      expect(File(store.path).existsSync(), isFalse);
      expect(File('${store.path}.bad-$stamp').readAsBytesSync(), garbage);
    },
  );

  test(
    'GivenADocumentFromANewerVersion_WhenTheHistoryIsRead_ThenItIsKeptAsideWithItsBytes',
    () async {
      final newer = utf8.encode('{"version":3,"tracks":[]}');
      await seed(newer);

      expect((await store.read()).isEmpty, isTrue);

      expect(File(store.path).existsSync(), isFalse);
      expect(File('${store.path}.bad-$stamp').readAsBytesSync(), newer);
    },
  );

  test(
    'GivenADocumentThatIsNotUtf8_WhenTheHistoryIsRead_ThenItIsKeptAsideRatherThanReportedAsUnopenable',
    () async {
      final bytes = [0x7b, 0xff, 0xfe, 0x7d];
      await seed(bytes);

      expect((await store.read()).isEmpty, isTrue);

      expect(File('${store.path}.bad-$stamp').readAsBytesSync(), bytes);
    },
  );

  test(
    'GivenADocumentWhoseTracksAreNotAList_WhenTheHistoryIsRead_ThenItIsKeptAside',
    () async {
      final bytes = utf8.encode('{"version":1,"tracks":{}}');
      await seed(bytes);

      expect((await store.read()).isEmpty, isTrue);

      expect(File('${store.path}.bad-$stamp').readAsBytesSync(), bytes);
    },
  );

  test(
    'GivenAnUnreadableDocumentThatCannotBeSetAside_WhenTheHistoryIsRead_ThenItThrowsAndTheDocumentStays',
    () async {
      // Carrying on with an empty history and the document still in place
      // would let the next play overwrite it.
      final garbage = utf8.encode('{ this is not json');
      await seed(garbage);
      // A folder where the copy would go, with something in it: no rename
      // onto it succeeds on any platform.
      final blocker = Directory('${store.path}.bad-$stamp');
      await blocker.create();
      await File('${blocker.path}/keep').writeAsString('x');

      await expectLater(store.read(), throwsA(isA<FileSystemException>()));

      expect(File(store.path).readAsBytesSync(), garbage);
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
    'GivenAVersionTwoRowWithAMalformedDate_WhenTheHistoryIsRead_ThenTheRowAndItsOtherDatesSurvive',
    () async {
      // A date is the least of a row: its count is kept whatever the dates say.
      await seed(
        utf8.encode(
          '{"version":2,"tracks":['
          '{"path":"/library/a.flac","plays":4,"lastPlayedAt":"2026-10-10T00:00:00.000Z",'
          '"recent":["not a date",7,"2026-10-10T00:00:00.000Z"]},'
          '{"path":"/library/b.flac","plays":2,"lastPlayedAt":"2026-10-10T00:00:00.000Z",'
          '"recent":"nope"}'
          ']}',
        ),
      );

      final read = await store.read();

      expect(read.tracks['/library/a.flac']!.plays, 4);
      expect(read.tracks['/library/a.flac']!.recent, [DateTime.utc(2026, 10, 10)]);
      expect(read.tracks['/library/b.flac']!.plays, 2);
      expect(read.tracks['/library/b.flac']!.recent, isEmpty);
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
