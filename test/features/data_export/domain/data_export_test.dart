import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/data_export/domain/data_export.dart';
import 'package:orpheus/features/library/domain/audio_file.dart';
import 'package:orpheus/features/library/domain/music_catalog.dart';
import 'package:orpheus/features/library/domain/music_entry.dart';
import 'package:orpheus/features/library/domain/track_metadata.dart';
import 'package:orpheus/features/playlists/domain/playlist.dart';
import 'package:orpheus/features/stats/domain/music_stats.dart';
import 'package:orpheus/features/stats/domain/play_history.dart';

import '../../../support/entries.dart';

/// Turning what the owner has into the document they are handed.
void main() {
  final now = DateTime.utc(2026, 10, 18, 22, 30);

  // A Windows path and a title no ASCII-only writer could keep.
  final windowsEntry = MusicEntry(
    file: AudioFile(
      path: r'C:\Music\Zoë\夜.mp3',
      sizeInBytes: 1,
      modifiedAt: DateTime.utc(2026),
    ),
    metadata: const TrackMetadata(
      title: 'Café del Mar 夜',
      artist: 'Zoë',
      album: 'Second',
      track: 3,
      trackTotal: 9,
      disc: 2,
      year: 1999,
      duration: Duration(seconds: 200, milliseconds: 500),
    ),
  );

  /// Four songs in the library's song order: two tagged, one with a path and
  /// title that are not ASCII, and one with no tags at all.
  final songs = [
    entry(
      id: 'a',
      title: 'Alpha',
      artist: 'Ann',
      album: 'First',
      track: 1,
      year: 2001,
      genres: ['Rock'],
      duration: const Duration(minutes: 3, seconds: 5),
    ),
    entry(
      id: 'b',
      title: 'Beta',
      artist: 'Ann',
      album: 'First',
      track: 2,
      year: 2001,
      genres: ['Rock', 'Pop'],
      duration: const Duration(minutes: 4),
    ),
    windowsEntry,
    entry(id: 'd'),
  ];

  final playlists = [
    Playlist(
      id: 'p1',
      name: 'Road trip',
      createdAt: DateTime.utc(2026, 1, 2, 3, 4, 5),
      modifiedAt: DateTime.utc(2026, 2, 3, 4, 5, 6, 7),
      entries: const [
        PlaylistEntry(
          id: 'e1',
          path: '/library/zzz-b.flac',
          title: 'Beta',
          artist: 'Ann',
          album: 'First',
          duration: Duration(minutes: 4),
        ),
        // A song the library no longer holds.
        PlaylistEntry(
          id: 'e2',
          path: '/old/gone.mp3',
          title: 'Gone',
          artist: 'Nobody',
        ),
      ],
    ),
    Playlist(
      id: 'p2',
      name: 'Café 夜',
      coverId: 'cover-1',
      createdAt: DateTime.utc(2026, 3),
      modifiedAt: DateTime.utc(2026, 3),
      entries: const [
        PlaylistEntry(
          id: 'e3',
          path: r'C:\Music\Zoë\夜.mp3',
          title: 'Café del Mar 夜',
          artist: 'Zoë',
          album: 'Second',
          duration: Duration(seconds: 200, milliseconds: 500),
        ),
      ],
    ),
  ];

  // One row for a file the library does not hold, and recent plays.
  final history = PlayHistory(
    tracks: {
      '/library/zzz-a.flac': TrackPlays(
        path: '/library/zzz-a.flac',
        plays: 4,
        lastPlayedAt: DateTime.utc(2026, 10, 10, 12),
        recent: [DateTime.utc(2026, 10, 1, 10), DateTime.utc(2026, 10, 10, 12)],
      ),
      '/library/zzz-b.flac': TrackPlays(
        path: '/library/zzz-b.flac',
        plays: 3,
        lastPlayedAt: DateTime.utc(2026, 10, 17, 8),
        recent: [DateTime.utc(2026, 10, 17, 8)],
      ),
      r'C:\Music\Zoë\夜.mp3': TrackPlays(
        path: r'C:\Music\Zoë\夜.mp3',
        plays: 1,
        lastPlayedAt: DateTime.utc(2025),
      ),
      '/old/gone.mp3': TrackPlays(
        path: '/old/gone.mp3',
        plays: 6,
        lastPlayedAt: DateTime.utc(2026, 9, 30, 9),
        recent: [DateTime.utc(2026, 9, 30, 9)],
      ),
      '/library/zzz-d.flac': TrackPlays(
        path: '/library/zzz-d.flac',
        plays: 2,
        lastPlayedAt: DateTime.utc(2026, 10, 18, 10),
        recent: [DateTime.utc(2026, 10, 18, 10)],
      ),
    },
  );

  ExportSources sources({
    List<MusicEntry>? songs_,
    List<Playlist>? playlists_,
    PlayHistory? history_,
    List<ExportProblem> problems = const [],
  }) => ExportSources(
    songs: songs_ ?? songs,
    playlists: playlists_ ?? playlists,
    history: history_ ?? history,
    now: now,
    orpheusVersion: '1.5.0',
    problems: problems,
  );

  Map<String, Object?> built({
    List<MusicEntry>? songs_,
    List<Playlist>? playlists_,
    PlayHistory? history_,
    List<ExportProblem> problems = const [],
  }) => buildDataExport(
    sources(
      songs_: songs_,
      playlists_: playlists_,
      history_: history_,
      problems: problems,
    ),
  );

  List<Map<String, Object?>> section(Map<String, Object?> doc, String key) => [
    for (final item in doc[key]! as List<Object?>)
      item! as Map<String, Object?>,
  ];

  test('GivenAFixtureLibrary_WhenTheDocumentIsEncoded_ThenItIsExactlyTheGoldenFile', () {
    final bytes = encodeDataExport(buildDataExport(sources()));

    expect(utf8.decode(bytes), _golden);
  });

  test(
    'GivenTheDocument_WhenItsKeysAreRead_ThenTheyAreInTheDocumentedOrder',
    () {
      final document = built();

      expect(document.keys.toList(), [
        'format',
        'formatVersion',
        'exportedAt',
        'orpheusVersion',
        'songs',
        'artists',
        'albums',
        'playlists',
        'autoPlaylists',
        'playHistory',
        'statistics',
        'problems',
      ]);
      expect(document['format'], 'orpheus-data');
      expect(document['formatVersion'], 1);
      expect(document['exportedAt'], '2026-10-18T22:30:00.000Z');
    },
  );

  test('GivenNoVersion_WhenTheDocumentIsBuilt_ThenItIsNull', () {
    final document = buildDataExport(
      ExportSources(
        songs: songs,
        playlists: const [],
        history: PlayHistory.empty,
        now: now,
      ),
    );

    expect(document.containsKey('orpheusVersion'), isTrue);
    expect(document['orpheusVersion'], isNull);
  });

  test(
    'GivenASongWithNoTags_WhenItIsExported_ThenEveryAbsentTagIsPresentAsNull',
    () {
      final untagged = section(built(), 'songs').last;

      expect(untagged.keys.toList(), [
        'id',
        'path',
        'title',
        'artist',
        'albumArtist',
        'album',
        'trackNumber',
        'trackTotal',
        'discNumber',
        'year',
        'genres',
        'durationMs',
      ]);
      expect(untagged['id'], 's4');
      expect(untagged['title'], isNull);
      expect(untagged['artist'], isNull);
      expect(untagged['albumArtist'], isNull);
      expect(untagged['album'], isNull);
      expect(untagged['trackNumber'], isNull);
      expect(untagged['trackTotal'], isNull);
      expect(untagged['discNumber'], isNull);
      expect(untagged['year'], isNull);
      expect(untagged['durationMs'], isNull);
      expect(untagged['genres'], isEmpty);
    },
  );

  test('GivenSongsInAnOrder_WhenTheyAreExported_ThenTheIdsFollowThatOrder', () {
    final ids = [for (final song in section(built(), 'songs')) song['id']];

    expect(ids, ['s1', 's2', 's3', 's4']);
  });

  test('GivenAlbumSongsWhoseYearsDisagree_WhenTheAlbumIsExported_ThenItsYearIsNull', () {
    final document = built(
      songs_: [
        entry(id: 'a', title: 'One', artist: 'Ann', album: 'Mixed', year: 1999),
        entry(id: 'b', title: 'Two', artist: 'Ann', album: 'Mixed', year: 2004),
      ],
      playlists_: const [],
      history_: PlayHistory.empty,
    );

    final albums = section(document, 'albums');

    expect(albums, hasLength(1));
    expect(albums.single['year'], isNull);
  });

  test(
    'GivenAlbumSongsThatAgreeOnTheYear_WhenTheAlbumIsExported_ThenItCarriesIt',
    () {
      final albums = section(built(), 'albums');

      expect(albums.first['title'], 'First');
      expect(albums.first['year'], 2001);
    },
  );

  test('GivenAnArtistOnTwoAlbums_WhenTheyAreExported_ThenTheSongsRunAlbumByAlbum', () {
    // Track 1 of each album would sort ahead of track 2 of the first if the
    // songs were in track order across records.
    final document = built(
      songs_: [
        entry(id: 'a2', title: 'A2', artist: 'Ann', album: 'Alpha', track: 2),
        entry(id: 'b1', title: 'B1', artist: 'Ann', album: 'Beta', track: 1),
        entry(id: 'a1', title: 'A1', artist: 'Ann', album: 'Alpha', track: 1),
        entry(id: 'b2', title: 'B2', artist: 'Ann', album: 'Beta', track: 2),
      ],
      playlists_: const [],
      history_: PlayHistory.empty,
    );

    final songs = section(document, 'songs');
    String idOf(String title) =>
        songs.firstWhere((song) => song['title'] == title)['id']! as String;

    expect(section(document, 'artists').single['songs'], [
      idOf('A1'),
      idOf('A2'),
      idOf('B1'),
      idOf('B2'),
    ]);
  });

  test(
    'GivenTheUntaggedSong_WhenGroupsAreExported_ThenItsGroupsHaveNullNames',
    () {
      final document = built();

      expect(section(document, 'artists').last['name'], isNull);
      expect(section(document, 'artists').last['songs'], ['s4']);
      expect(section(document, 'albums').last['title'], isNull);
      expect(section(document, 'albums').last['albumArtist'], isNull);
    },
  );

  test('GivenAPlaylistEntryMissingFromTheLibrary_WhenItIsExported_ThenItsSongIdIsNullAndItsSavedDetailsStay', () {
    final entries =
        section(built(), 'playlists').first['entries']! as List<Object?>;
    final missing = entries.last! as Map<String, Object?>;

    expect(missing['path'], '/old/gone.mp3');
    expect(missing['songId'], isNull);
    expect(missing['title'], 'Gone');
    expect(missing['artist'], 'Nobody');
    expect(missing['album'], isNull);
    expect(missing['durationMs'], isNull);
  });

  test('GivenAPlaylistWithACoverId_WhenItIsExported_ThenOnlyTheFlagIsKept', () {
    final exported = section(built(), 'playlists');

    expect(exported[0]['hasCustomCover'], isFalse);
    expect(exported[1]['hasCustomCover'], isTrue);
    expect(exported[1].containsKey('coverId'), isFalse);
  });

  test('GivenALibraryAndHistory_WhenAutoPlaylistsAreExported_ThenBothAreThereWithTheFallbackFlag', () {
    final autos = section(built(), 'autoPlaylists');

    expect(autos, hasLength(2));
    expect(autos[0], {
      'kind': 'lately',
      'name': 'Favourites lately',
      'fallback': true,
      'songs': ['s1', 's2', 's4'],
    });
    expect(autos[1], {
      'kind': 'allTime',
      'name': 'All-time favourites',
      'songs': ['s1', 's2', 's4', 's3'],
    });
  });

  test('GivenEnoughSongsPlayedLately_WhenAutoPlaylistsAreExported_ThenLatelyIsNotAFallback', () {
    final many = [
      for (var i = 0; i < 10; i++)
        entry(id: 'song$i', title: 'Song $i', artist: 'Ann', album: 'Many'),
    ];
    final played = PlayHistory(
      tracks: {
        for (final song in many)
          song.file.path: TrackPlays(
            path: song.file.path,
            plays: 1,
            lastPlayedAt: DateTime.utc(2026, 10, 17),
            recent: [DateTime.utc(2026, 10, 17)],
          ),
      },
    );

    final lately = section(
      built(songs_: many, history_: played),
      'autoPlaylists',
    ).first;

    expect(lately['fallback'], isFalse);
    expect(lately['songs'], hasLength(10));
  });

  test('GivenNothingPlayed_WhenAutoPlaylistsAreExported_ThenBothAreEmpty', () {
    final autos = section(built(history_: PlayHistory.empty), 'autoPlaylists');

    expect(autos[0]['songs'], isEmpty);
    expect(autos[0]['fallback'], isFalse);
    expect(autos[1]['songs'], isEmpty);
  });

  test('GivenATrackNotInTheLibrary_WhenHistoryIsExported_ThenItIsKeptWithANullSongId', () {
    final row = section(built(), 'playHistory')[3];

    expect(row, {
      'path': '/old/gone.mp3',
      'songId': null,
      'plays': 6,
      'lastPlayedAt': '2026-09-30T09:00:00.000Z',
      'recentPlays': ['2026-09-30T09:00:00.000Z'],
    });
  });

  test('GivenAHistoryAndTheCatalog_WhenStatisticsAreExported_ThenTheyAreWhatMusicStatsFromSays', () {
    final stats = musicStatsFrom(
      history: history,
      catalog: MusicCatalog(entries: songs),
    );
    final exported = built()['statistics']! as Map<String, Object?>;

    List<Map<String, Object?>> ranked(List<RankedPlays> lines) => [
      for (final line in lines)
        {'name': line.name, 'plays': line.plays, 'share': line.share},
    ];

    expect(exported.keys.toList(), [
      'totalPlays',
      'distinctTracks',
      'untaggedTracks',
      'topTracks',
      'topArtists',
      'topAlbums',
      'topGenres',
    ]);
    expect(exported['totalPlays'], stats.totalPlays);
    expect(exported['distinctTracks'], stats.distinctTracks);
    expect(exported['untaggedTracks'], stats.untaggedTracks);
    expect(exported['topTracks'], ranked(stats.tracks));
    expect(exported['topArtists'], ranked(stats.artists));
    expect(exported['topAlbums'], ranked(stats.albums));
    expect(exported['topGenres'], ranked(stats.genres));
  });

  test('GivenNoHistory_WhenStatisticsAreExported_ThenTheyAreZeroAndEmpty', () {
    final exported =
        built(history_: PlayHistory.empty)['statistics']!
            as Map<String, Object?>;

    expect(exported['totalPlays'], 0);
    expect(exported['topTracks'], isEmpty);
  });

  test('GivenProblems_WhenTheDocumentIsBuilt_ThenTheyAreCarriedThrough', () {
    final document = built(
      problems: const [
        ExportProblem('playlists', 'could not be read'),
        ExportProblem('playHistory', 'unreadable'),
      ],
    );

    expect(section(document, 'problems'), [
      {'section': 'playlists', 'message': 'could not be read'},
      {'section': 'playHistory', 'message': 'unreadable'},
    ]);
  });

  test('GivenNoProblems_WhenTheDocumentIsBuilt_ThenProblemsIsAnEmptyList', () {
    expect(built()['problems'], isEmpty);
  });

  test(
    'GivenAnEmptyLibrary_WhenTheDocumentIsBuilt_ThenEverySectionIsEmpty',
    () {
      final document = buildDataExport(
        ExportSources(
          songs: const [],
          playlists: const [],
          history: PlayHistory.empty,
          now: now,
        ),
      );

      for (final key in const [
        'songs',
        'artists',
        'albums',
        'playlists',
        'playHistory',
        'problems',
      ]) {
        expect(document[key], isEmpty, reason: key);
      }
    },
  );

  test('GivenTheEncodedDocument_WhenItIsDecoded_ThenTheNonAsciiTitleAndWindowsPathSurvive', () {
    final bytes = encodeDataExport(built());
    final decoded = jsonDecode(utf8.decode(bytes)) as Map<String, Object?>;
    final song =
        (decoded['songs']! as List<Object?>)[2]! as Map<String, Object?>;

    expect(song['title'], 'Café del Mar 夜');
    expect(song['path'], r'C:\Music\Zoë\夜.mp3');
  });

  test('GivenTheEncodedDocument_WhenItsBytesAreRead_ThenItIsIndentedByTwoAndEndsWithANewline', () {
    final text = utf8.decode(encodeDataExport(built()));

    expect(text, startsWith('{\n  "format": "orpheus-data",\n'));
    expect(text, endsWith('}\n'));
  });
}

/// The document for the fixtures above, written out by hand from the schema.
const String _golden = r'''
{
  "format": "orpheus-data",
  "formatVersion": 1,
  "exportedAt": "2026-10-18T22:30:00.000Z",
  "orpheusVersion": "1.5.0",
  "songs": [
    {
      "id": "s1",
      "path": "/library/zzz-a.flac",
      "title": "Alpha",
      "artist": "Ann",
      "albumArtist": null,
      "album": "First",
      "trackNumber": 1,
      "trackTotal": null,
      "discNumber": null,
      "year": 2001,
      "genres": [
        "Rock"
      ],
      "durationMs": 185000
    },
    {
      "id": "s2",
      "path": "/library/zzz-b.flac",
      "title": "Beta",
      "artist": "Ann",
      "albumArtist": null,
      "album": "First",
      "trackNumber": 2,
      "trackTotal": null,
      "discNumber": null,
      "year": 2001,
      "genres": [
        "Rock",
        "Pop"
      ],
      "durationMs": 240000
    },
    {
      "id": "s3",
      "path": "C:\\Music\\Zoë\\夜.mp3",
      "title": "Café del Mar 夜",
      "artist": "Zoë",
      "albumArtist": null,
      "album": "Second",
      "trackNumber": 3,
      "trackTotal": 9,
      "discNumber": 2,
      "year": 1999,
      "genres": [],
      "durationMs": 200500
    },
    {
      "id": "s4",
      "path": "/library/zzz-d.flac",
      "title": null,
      "artist": null,
      "albumArtist": null,
      "album": null,
      "trackNumber": null,
      "trackTotal": null,
      "discNumber": null,
      "year": null,
      "genres": [],
      "durationMs": null
    }
  ],
  "artists": [
    {
      "name": "Ann",
      "songs": [
        "s1",
        "s2"
      ]
    },
    {
      "name": "Zoë",
      "songs": [
        "s3"
      ]
    },
    {
      "name": null,
      "songs": [
        "s4"
      ]
    }
  ],
  "albums": [
    {
      "title": "First",
      "albumArtist": "Ann",
      "year": 2001,
      "songs": [
        "s1",
        "s2"
      ]
    },
    {
      "title": "Second",
      "albumArtist": "Zoë",
      "year": 1999,
      "songs": [
        "s3"
      ]
    },
    {
      "title": null,
      "albumArtist": null,
      "year": null,
      "songs": [
        "s4"
      ]
    }
  ],
  "playlists": [
    {
      "id": "p1",
      "name": "Road trip",
      "createdAt": "2026-01-02T03:04:05.000Z",
      "modifiedAt": "2026-02-03T04:05:06.007Z",
      "hasCustomCover": false,
      "entries": [
        {
          "path": "/library/zzz-b.flac",
          "songId": "s2",
          "title": "Beta",
          "artist": "Ann",
          "album": "First",
          "durationMs": 240000
        },
        {
          "path": "/old/gone.mp3",
          "songId": null,
          "title": "Gone",
          "artist": "Nobody",
          "album": null,
          "durationMs": null
        }
      ]
    },
    {
      "id": "p2",
      "name": "Café 夜",
      "createdAt": "2026-03-01T00:00:00.000Z",
      "modifiedAt": "2026-03-01T00:00:00.000Z",
      "hasCustomCover": true,
      "entries": [
        {
          "path": "C:\\Music\\Zoë\\夜.mp3",
          "songId": "s3",
          "title": "Café del Mar 夜",
          "artist": "Zoë",
          "album": "Second",
          "durationMs": 200500
        }
      ]
    }
  ],
  "autoPlaylists": [
    {
      "kind": "lately",
      "name": "Favourites lately",
      "fallback": true,
      "songs": [
        "s1",
        "s2",
        "s4"
      ]
    },
    {
      "kind": "allTime",
      "name": "All-time favourites",
      "songs": [
        "s1",
        "s2",
        "s4",
        "s3"
      ]
    }
  ],
  "playHistory": [
    {
      "path": "/library/zzz-a.flac",
      "songId": "s1",
      "plays": 4,
      "lastPlayedAt": "2026-10-10T12:00:00.000Z",
      "recentPlays": [
        "2026-10-01T10:00:00.000Z",
        "2026-10-10T12:00:00.000Z"
      ]
    },
    {
      "path": "/library/zzz-b.flac",
      "songId": "s2",
      "plays": 3,
      "lastPlayedAt": "2026-10-17T08:00:00.000Z",
      "recentPlays": [
        "2026-10-17T08:00:00.000Z"
      ]
    },
    {
      "path": "C:\\Music\\Zoë\\夜.mp3",
      "songId": "s3",
      "plays": 1,
      "lastPlayedAt": "2025-01-01T00:00:00.000Z",
      "recentPlays": []
    },
    {
      "path": "/old/gone.mp3",
      "songId": null,
      "plays": 6,
      "lastPlayedAt": "2026-09-30T09:00:00.000Z",
      "recentPlays": [
        "2026-09-30T09:00:00.000Z"
      ]
    },
    {
      "path": "/library/zzz-d.flac",
      "songId": "s4",
      "plays": 2,
      "lastPlayedAt": "2026-10-18T10:00:00.000Z",
      "recentPlays": [
        "2026-10-18T10:00:00.000Z"
      ]
    }
  ],
  "statistics": {
    "totalPlays": 16,
    "distinctTracks": 5,
    "untaggedTracks": 1,
    "topTracks": [
      {
        "name": "gone.mp3",
        "plays": 6,
        "share": 0.375
      },
      {
        "name": "Alpha",
        "plays": 4,
        "share": 0.25
      },
      {
        "name": "Beta",
        "plays": 3,
        "share": 0.1875
      },
      {
        "name": "zzz-d.flac",
        "plays": 2,
        "share": 0.125
      },
      {
        "name": "Café del Mar 夜",
        "plays": 1,
        "share": 0.0625
      }
    ],
    "topArtists": [
      {
        "name": "Ann",
        "plays": 7,
        "share": 0.875
      },
      {
        "name": "Zoë",
        "plays": 1,
        "share": 0.125
      }
    ],
    "topAlbums": [
      {
        "name": "First",
        "plays": 7,
        "share": 0.875
      },
      {
        "name": "Second",
        "plays": 1,
        "share": 0.125
      }
    ],
    "topGenres": [
      {
        "name": "Rock",
        "plays": 7,
        "share": 0.4375
      },
      {
        "name": "Pop",
        "plays": 3,
        "share": 0.1875
      }
    ]
  },
  "problems": []
}
''';
