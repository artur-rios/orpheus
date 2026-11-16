import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/library/domain/audio_file.dart';
import 'package:orpheus/features/library/domain/music_entry.dart';
import 'package:orpheus/features/library/domain/track_metadata.dart';

/// One track as the library reads its tags.
void main() {
  final file = AudioFile(
    path: '/music/a.flac',
    sizeInBytes: 1,
    modifiedAt: DateTime.utc(2026),
  );

  MusicEntry entryOf(TrackMetadata metadata, {String? ofRecord}) =>
      MusicEntry(file: file, metadata: metadata, albumArtistOfRecord: ofRecord);

  test(
    'GivenTagsPaddedWithSpaces_WhenRead_ThenTheSpacesAreGone',
    () {
      final entry = entryOf(
        const TrackMetadata(title: '  Song ', artist: ' Band', album: 'LP  '),
      );

      expect(entry.title, 'Song');
      expect(entry.artist, 'Band');
      expect(entry.album, 'LP');
    },
  );

  test(
    'GivenTagsThatAreOnlySpaces_WhenRead_ThenTheyAreMissing',
    () {
      final entry = entryOf(
        const TrackMetadata(title: '   ', artist: '', album: '\t'),
      );

      expect(entry.title, isNull);
      expect(entry.artist, isNull);
      expect(entry.album, isNull);
    },
  );

  test(
    'GivenAnAlbumArtistTag_WhenTheAlbumArtistIsRead_ThenTheTagWins',
    () {
      final entry = entryOf(
        const TrackMetadata(artist: 'Guest', albumArtist: ' Band '),
        ofRecord: 'Derived',
      );

      expect(entry.albumArtist, 'Band');
    },
  );

  test(
    'GivenNoAlbumArtistTag_WhenTheAlbumArtistIsRead_ThenTheRecordsArtistIsUsed',
    () {
      final entry = entryOf(
        const TrackMetadata(artist: 'Guest', albumArtist: '  '),
        ofRecord: 'Band',
      );

      expect(entry.albumArtist, 'Band');
    },
  );

  test(
    'GivenNoAlbumArtistAndNoRecordArtist_WhenTheAlbumArtistIsRead_ThenItIsTheArtist',
    () {
      final entry = entryOf(const TrackMetadata(artist: ' Solo '));

      expect(entry.albumArtist, 'Solo');
    },
  );

  test(
    'GivenAnEntry_WhenItIsGivenARecordArtist_ThenOnlyThatChanges',
    () {
      const metadata = TrackMetadata(title: 'Song', artist: 'Guest');
      final entry = entryOf(metadata, ofRecord: 'Old');

      final changed = entry.withRecordArtist('Band');

      expect(changed.albumArtist, 'Band');
      expect(changed.file, same(file));
      expect(changed.metadata, same(metadata));
      expect(entry.albumArtist, 'Old');
    },
  );
}
