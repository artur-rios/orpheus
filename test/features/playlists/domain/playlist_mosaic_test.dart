import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/library/domain/music_entry.dart';
import 'package:orpheus/features/playlists/domain/playlist.dart';
import 'package:orpheus/features/playlists/domain/playlist_mosaic.dart';

import '../../../support/entries.dart';

/// Which covers a playlist's mosaic is drawn from.
void main() {
  final t0 = DateTime.utc(2026);

  Playlist playlistOf(List<MusicEntry> songs) => Playlist(
    id: 'p',
    name: 'Mix',
    entries: [
      for (var i = 0; i < songs.length; i++)
        PlaylistEntry(id: 'e$i', path: songs[i].file.path),
    ],
    createdAt: t0,
    modifiedAt: t0,
  );

  Map<String, MusicEntry> catalogOf(List<MusicEntry> songs) => {
    for (final song in songs) song.file.path: song,
  };

  MusicEntry onAlbum(String id, String album, String? cover) =>
      entry(id: id, album: album, albumArtist: 'A', coverId: cover);

  test('GivenSixSongsOnFiveAlbums_WhenTheMosaicIsMade_ThenItIsFourInOrder', () {
    final songs = [
      onAlbum('1', 'One', 'c1'),
      onAlbum('2', 'One', 'c1'),
      onAlbum('3', 'Two', 'c2'),
      onAlbum('4', 'Three', 'c3'),
      onAlbum('5', 'Four', 'c4'),
      onAlbum('6', 'Five', 'c5'),
    ];

    final ids = mosaicCoverIds(playlistOf(songs), catalogOf(songs));

    expect(ids, ['c1', 'c2', 'c3', 'c4']);
  });

  test('GivenManySongsOnOneAlbum_WhenTheMosaicIsMade_ThenItIsOneId', () {
    final songs = [
      onAlbum('1', 'One', 'c1'),
      onAlbum('2', 'One', 'c1'),
      onAlbum('3', 'One', 'c1'),
    ];

    expect(mosaicCoverIds(playlistOf(songs), catalogOf(songs)), ['c1']);
  });

  test(
    'GivenTwoArtistsWithTheSameAlbumTitle_WhenTheMosaicIsMade_ThenBothCount',
    () {
      final songs = [
        entry(id: '1', album: 'Hits', albumArtist: 'A', coverId: 'c1'),
        entry(id: '2', album: 'Hits', albumArtist: 'B', coverId: 'c2'),
      ];

      expect(mosaicCoverIds(playlistOf(songs), catalogOf(songs)), ['c1', 'c2']);
    },
  );

  test(
    'GivenASongMissingFromTheCatalog_WhenTheMosaicIsMade_ThenItIsSkipped',
    () {
      final songs = [onAlbum('1', 'One', 'c1'), onAlbum('2', 'Two', 'c2')];

      final ids = mosaicCoverIds(playlistOf(songs), catalogOf([songs[1]]));

      expect(ids, ['c2']);
    },
  );

  test('GivenSongsWithoutCovers_WhenTheMosaicIsMade_ThenItIsEmpty', () {
    final songs = [onAlbum('1', 'One', null), entry(id: '2')];

    expect(mosaicCoverIds(playlistOf(songs), catalogOf(songs)), isEmpty);
  });

  test('GivenAnEmptyPlaylist_WhenTheMosaicIsMade_ThenItIsEmpty', () {
    expect(mosaicCoverIds(playlistOf([]), {}), isEmpty);
  });

  test('GivenAnAlbumWhoseFirstTrackHasNoCover_WhenTheMosaicIsMade_ThenAnotherTrackSuppliesIt', () {
    final songs = [onAlbum('1', 'One', null), onAlbum('2', 'One', 'c1')];

    expect(mosaicCoverIds(playlistOf(songs), catalogOf(songs)), ['c1']);
  });

  test('GivenSongsWithNoAlbumAndDifferentCovers_WhenTheMosaicIsMade_ThenEachCovers', () {
    final songs = [
      entry(id: '1', coverId: 'c1'),
      entry(id: '2', coverId: 'c2'),
      entry(id: '3', coverId: 'c1'),
    ];

    expect(mosaicCoverIds(playlistOf(songs), catalogOf(songs)), ['c1', 'c2']);
  });
}
