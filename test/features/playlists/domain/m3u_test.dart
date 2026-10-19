import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/library/domain/music_entry.dart';
import 'package:orpheus/features/playlists/domain/m3u.dart';
import 'package:orpheus/features/playlists/domain/playlist.dart';

import '../../../support/entries.dart';

/// Writing a playlist as an extended M3U.
void main() {
  final t0 = DateTime.utc(2026);

  Playlist playlistOf(List<PlaylistEntry> entries) => Playlist(
    id: 'p',
    name: 'Road trip',
    entries: entries,
    createdAt: t0,
    modifiedAt: t0,
  );

  Map<String, MusicEntry> catalogOf(List<MusicEntry> songs) => {
    for (final song in songs) song.file.path: song,
  };

  PlaylistEntry at(MusicEntry song, [String id = 'e1']) =>
      PlaylistEntry(id: id, path: song.file.path);

  test('GivenAnEmptyPlaylist_WhenExported_ThenOnlyTheHeaderIsWritten', () {
    expect(playlistToM3u(playlistOf([]), {}), '#EXTM3U\n');
  });

  test('GivenASongInTheCatalog_WhenExported_ThenTheCatalogsTagsAreUsed', () {
    final song = entry(
      id: '1',
      title: 'Airbag',
      artist: 'Radiohead',
      duration: const Duration(seconds: 284, milliseconds: 600),
    );
    final playlist = playlistOf([
      PlaylistEntry(
        id: 'e1',
        path: song.file.path,
        title: 'Stale',
        artist: 'Stale',
        duration: const Duration(seconds: 1),
      ),
    ]);

    final text = playlistToM3u(playlist, catalogOf([song]));

    expect(
      text,
      '#EXTM3U\n'
      '#EXTINF:284,Radiohead - Airbag\n'
      '/library/zzz-1.flac\n',
    );
  });

  test(
    'GivenASongMissingFromTheCatalog_WhenExported_ThenTheSnapshotIsUsed',
    () {
      final playlist = playlistOf([
        const PlaylistEntry(
          id: 'e1',
          path: '/music/gone.mp3',
          title: 'Gone',
          artist: 'Someone',
          duration: Duration(seconds: 61),
        ),
      ]);

      final text = playlistToM3u(playlist, {});

      expect(
        text,
        '#EXTM3U\n'
        '#EXTINF:61,Someone - Gone\n'
        '/music/gone.mp3\n',
      );
    },
  );

  test('GivenAnUnknownDuration_WhenExported_ThenItIsMinusOne', () {
    final song = entry(id: '1', title: 'Airbag', artist: 'Radiohead');

    final text = playlistToM3u(playlistOf([at(song)]), catalogOf([song]));

    expect(text, contains('#EXTINF:-1,Radiohead - Airbag\n'));
  });

  test('GivenAnArtistOrATitleOnly_WhenExported_ThenNoDashIsWritten', () {
    final playlist = playlistOf([
      const PlaylistEntry(id: 'a', path: '/m/a.mp3', title: 'Only title'),
      const PlaylistEntry(id: 'b', path: '/m/b.mp3', artist: 'Only artist'),
    ]);

    final text = playlistToM3u(playlist, {});

    expect(text, contains('#EXTINF:-1,Only title\n'));
    expect(text, contains('#EXTINF:-1,Only artist\n'));
  });

  test('GivenNoTags_WhenExported_ThenTheFileNameLabelsTheLine', () {
    final playlist = playlistOf([
      const PlaylistEntry(id: 'a', path: '/m/untitled.mp3'),
    ]);

    expect(playlistToM3u(playlist, {}), contains('#EXTINF:-1,untitled.mp3\n'));
  });

  test('GivenTheSameSongTwice_WhenExported_ThenItIsWrittenTwice', () {
    final song = entry(id: '1', title: 'Airbag', artist: 'Radiohead');
    final playlist = playlistOf([at(song, 'e1'), at(song, 'e2')]);

    final text = playlistToM3u(playlist, catalogOf([song]));

    expect('/library/zzz-1.flac\n'.allMatches(text), hasLength(2));
  });

  test('GivenANonAsciiTitle_WhenExported_ThenItIsKeptAsText', () {
    final song = entry(id: '1', title: 'Ça ira – 夜に駆ける', artist: 'Beyoncé');

    final text = playlistToM3u(playlistOf([at(song)]), catalogOf([song]));

    expect(text, contains('#EXTINF:-1,Beyoncé - Ça ira – 夜に駆ける\n'));
  });

  test('GivenALineBreakInATag_WhenExported_ThenTheLabelStaysOneLine', () {
    final song = entry(id: '1', title: 'Two\r\nlines', artist: 'A');

    final text = playlistToM3u(playlistOf([at(song)]), catalogOf([song]));

    expect(text.split('\n'), [
      '#EXTM3U',
      '#EXTINF:-1,A - Two lines',
      '/library/zzz-1.flac',
      '',
    ]);
  });

  test('GivenAnExport_WhenItIsRead_ThenLinesEndWithNewlineOnly', () {
    final song = entry(id: '1', title: 'Airbag', artist: 'Radiohead');

    final text = playlistToM3u(playlistOf([at(song)]), catalogOf([song]));

    expect(text, isNot(contains('\r')));
  });
}
