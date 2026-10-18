import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/playlists/domain/playlist.dart';

import '../../../support/entries.dart';

/// The playlist value and the operations that make a new one from it.
void main() {
  final t0 = DateTime.utc(2026, 1, 1);
  final t1 = DateTime.utc(2026, 1, 2);
  final t2 = DateTime.utc(2026, 1, 3);

  PlaylistEntry song(String id, {String? path}) =>
      PlaylistEntry(id: id, path: path ?? '/library/$id.flac');

  Playlist playlistOf(List<PlaylistEntry> entries) => Playlist(
    id: 'p',
    name: 'Road trip',
    entries: entries,
    createdAt: t0,
    modifiedAt: t0,
  );

  List<String> ids(Playlist playlist) => [
    for (final entry in playlist.entries) entry.id,
  ];

  group('adding', () {
    test('GivenAPlaylist_WhenSongsAreAdded_ThenTheyAreAtTheEndInOrder', () {
      final playlist = playlistOf([song('a')]);

      final next = playlist.adding([song('b'), song('c')], t1);

      expect(ids(next), ['a', 'b', 'c']);
      expect(ids(playlist), ['a']);
    });

    test('GivenAPlaylist_WhenSongsAreAdded_ThenModifiedAtMoves', () {
      final next = playlistOf([]).adding([song('a')], t1);

      expect(next.modifiedAt, t1);
      expect(next.createdAt, t0);
    });
  });

  group('removing', () {
    test('GivenTheSameSongTwice_WhenOneCopyIsRemoved_ThenTheOtherStays', () {
      final playlist = playlistOf([
        song('first', path: '/library/x.flac'),
        song('second', path: '/library/x.flac'),
      ]);

      final next = playlist.removing({'first'}, t1);

      expect(ids(next), ['second']);
      expect(next.pathsIn(), {'/library/x.flac'});
    });

    test(
      'GivenSeveralEntryIds_WhenTheyAreRemoved_ThenTheRestKeepTheirOrder',
      () {
        final playlist = playlistOf([
          song('a'),
          song('b'),
          song('c'),
          song('d'),
        ]);

        final next = playlist.removing({'b', 'd'}, t1);

        expect(ids(next), ['a', 'c']);
        expect(next.modifiedAt, t1);
      },
    );
  });

  group('moving', () {
    test(
      'GivenTheSameSongTwice_WhenOneCopyIsMovedForward_ThenOnlyThatCopyMoves',
      () {
        final playlist = playlistOf([
          song('x1', path: '/library/x.flac'),
          song('y'),
          song('z'),
          song('x2', path: '/library/x.flac'),
        ]);

        // ReorderableListView: dropping before index 3 means "after z".
        final next = playlist.moving(0, 3, t1);

        expect(ids(next), ['y', 'z', 'x1', 'x2']);
      },
    );

    test(
      'GivenTheSameSongTwice_WhenOneCopyIsMovedBackward_ThenOnlyThatCopyMoves',
      () {
        final playlist = playlistOf([
          song('x1', path: '/library/x.flac'),
          song('y'),
          song('x2', path: '/library/x.flac'),
          song('z'),
        ]);

        final next = playlist.moving(2, 0, t1);

        expect(ids(next), ['x2', 'x1', 'y', 'z']);
      },
    );

    test('GivenAnEntry_WhenItIsDroppedAfterTheEnd_ThenItIsLast', () {
      final playlist = playlistOf([song('a'), song('b'), song('c')]);

      expect(ids(playlist.moving(0, 3, t1)), ['b', 'c', 'a']);
    });

    test('GivenAnEntry_WhenItIsDroppedWhereItIs_ThenNothingMoves', () {
      final playlist = playlistOf([song('a'), song('b'), song('c')]);

      expect(ids(playlist.moving(1, 1, t1)), ['a', 'b', 'c']);
      expect(ids(playlist.moving(1, 2, t1)), ['a', 'b', 'c']);
    });

    test('GivenAnIndexOutsideTheList_WhenMoved_ThenItIsRefused', () {
      final playlist = playlistOf([song('a'), song('b')]);

      expect(() => playlist.moving(2, 0, t1), throwsRangeError);
      expect(() => playlist.moving(0, 3, t1), throwsRangeError);
      expect(() => playlist.moving(-1, 0, t1), throwsRangeError);
    });

    test('GivenAMove_WhenItIsMade_ThenModifiedAtMoves', () {
      final next = playlistOf([song('a'), song('b')]).moving(0, 2, t1);

      expect(next.modifiedAt, t1);
    });
  });

  group('renamed', () {
    test('GivenABlankName_WhenRenamed_ThenItIsRefused', () {
      final playlist = playlistOf([]);

      expect(() => playlist.renamed('', t1), throwsArgumentError);
      expect(() => playlist.renamed('   \t', t1), throwsArgumentError);
    });

    test('GivenNamePaddedWithSpaces_WhenRenamed_ThenItIsTrimmed', () {
      final next = playlistOf([]).renamed('  Night drive  ', t1);

      expect(next.name, 'Night drive');
      expect(next.modifiedAt, t1);
    });
  });

  group('withCover', () {
    test('GivenNoCover_WhenOneIsChosen_ThenItIsSet', () {
      final next = playlistOf([]).withCover('cover-1', t1);

      expect(next.coverId, 'cover-1');
      expect(next.modifiedAt, t1);
    });

    test('GivenACover_WhenItIsCleared_ThenTheCoverIsNull', () {
      final withCover = playlistOf([song('a')]).withCover('cover-1', t1);

      final next = withCover.withCover(null, t2);

      expect(next.coverId, isNull);
      expect(next.modifiedAt, t2);
      expect(ids(next), ['a']);
    });
  });

  group('pathsIn', () {
    test('GivenTheSameSongTwice_WhenPathsAreAsked_ThenItIsOnce', () {
      final playlist = playlistOf([
        song('a', path: '/library/x.flac'),
        song('b', path: '/library/x.flac'),
        song('c'),
      ]);

      expect(playlist.pathsIn(), {'/library/x.flac', '/library/c.flac'});
    });
  });

  group('refreshedFrom', () {
    test(
      'GivenASongInTheCatalog_WhenRefreshed_ThenTheSnapshotIsTheCatalogs',
      () {
        const stale = PlaylistEntry(
          id: 'e1',
          path: '/library/zzz-1.flac',
          title: 'Old',
          artist: 'Old artist',
          album: 'Old album',
          duration: Duration(seconds: 1),
        );
        final fresh = stale.refreshedFrom(
          entry(
            id: '1',
            title: 'New',
            artist: 'New artist',
            album: 'New album',
            duration: const Duration(seconds: 200),
          ),
        );

        expect(fresh.id, 'e1');
        expect(fresh.path, '/library/zzz-1.flac');
        expect(fresh.title, 'New');
        expect(fresh.artist, 'New artist');
        expect(fresh.album, 'New album');
        expect(fresh.duration, const Duration(seconds: 200));
      },
    );
  });

  group('equality', () {
    test(
      'GivenTwoPlaylistsWithTheSameContent_WhenCompared_ThenTheyAreEqual',
      () {
        final a = playlistOf([song('a')]);
        final b = playlistOf([song('a')]);

        expect(a, b);
        expect(a.hashCode, b.hashCode);
        expect(a, isNot(a.adding([song('b')], t0)));
      },
    );
  });

  group('validPlaylistName', () {
    test('GivenPaddedText_WhenValidated_ThenItIsTrimmed', () {
      expect(validPlaylistName('  Mix '), 'Mix');
    });

    test('GivenBlankText_WhenValidated_ThenItIsNull', () {
      expect(validPlaylistName('  '), isNull);
      expect(validPlaylistName(''), isNull);
    });
  });

  group('mostRecentFirst', () {
    Playlist made(String id, {required DateTime created, DateTime? changed}) =>
        Playlist(
          id: id,
          name: id,
          createdAt: created,
          modifiedAt: changed ?? created,
        );

    List<String> order(List<Playlist> playlists) => [
      for (final playlist in playlists) playlist.id,
    ];

    test('GivenPlaylists_WhenOrdered_ThenTheLastChangedComesFirst', () {
      final ordered = mostRecentFirst([
        made('old', created: t0),
        made('newest', created: t0, changed: t2),
        made('newer', created: t1),
      ]);

      expect(order(ordered), ['newest', 'newer', 'old']);
    });

    test(
      'GivenTwoChangedAtTheSameTime_WhenOrdered_ThenTheLaterMadeComesFirst',
      () {
        final ordered = mostRecentFirst([
          made('first made', created: t0, changed: t2),
          made('second made', created: t1, changed: t2),
        ]);

        expect(order(ordered), ['second made', 'first made']);
      },
    );

    test('GivenPlaylists_WhenOrdered_ThenTheListGivenIsNotChanged', () {
      final given = [made('a', created: t0), made('b', created: t1)];

      mostRecentFirst(given);

      expect(order(given), ['a', 'b']);
    });
  });
}
