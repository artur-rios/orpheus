import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/library/data/tag_reading.dart';

import '../../../support/flac_fixture.dart';

/// Reading the tags out of a real file.
void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('orpheus-tags');
  });

  tearDown(() async {
    if (directory.existsSync()) await directory.delete(recursive: true);
  });

  File write(String name, List<int> bytes) =>
      File('${directory.path}/$name')..writeAsBytesSync(bytes);

  test(
    'GivenATaggedFlacFile_WhenItsTagsAreRead_ThenTheTitleArtistAndAlbumComeBack',
    () {
      final file = write(
        'track.flac',
        taggedFlac(
          tags: {
            'TITLE': 'Paranoid Android',
            'ARTIST': 'Radiohead',
            'ALBUM': 'OK Computer',
            'TRACKNUMBER': '2',
            'DATE': '1997',
          },
        ),
      );

      final read = readTags(file);

      expect(read.metadata.title, 'Paranoid Android');
      expect(read.metadata.artist, 'Radiohead');
      expect(read.metadata.album, 'OK Computer');
      expect(read.metadata.track, 2);
      expect(read.metadata.year, 1997);
    },
  );

  test(
    'GivenAFlacFileWithAnAlbumArtistTag_WhenItsTagsAreRead_ThenTheAlbumArtistComesBackApartFromTheArtist',
    () {
      // The reader keeps `ALBUMARTIST` in a list of its own, and this used to
      // leave it unread — so a compilation's "Various Artists" never reached
      // the library, and the record was filed under its busiest guest.
      final file = write(
        'track.flac',
        taggedFlac(
          tags: {
            'TITLE': 'Hey Ya!',
            'ARTIST': 'OutKast',
            'ALBUMARTIST': 'Various Artists',
            'ALBUM': 'Now 16',
          },
        ),
      );

      final read = readTags(file);

      expect(read.metadata.artist, 'OutKast');
      expect(read.metadata.albumArtist, 'Various Artists');
    },
  );

  test(
    'GivenAFlacFileWhoseAlbumArtistIsSpelledTheFfmpegWay_WhenItsTagsAreRead_ThenTheAlbumArtistComesBack',
    () {
      final file = write(
        'track.flac',
        taggedFlac(tags: {'ARTIST': 'OutKast', 'ALBUM_ARTIST': 'Various'}),
      );

      expect(readTags(file).metadata.albumArtist, 'Various');
    },
  );

  test(
    'GivenAFileWhoseTagsAreNotAscii_WhenItsTagsAreRead_ThenTheAccentsSurvive',
    () {
      final file = write(
        'track.flac',
        taggedFlac(tags: {'ARTIST': 'Céu', 'TITLE': 'Malemolência'}),
      );

      final read = readTags(file);

      expect(read.metadata.artist, 'Céu');
      expect(read.metadata.title, 'Malemolência');
    },
  );

  test(
    'GivenAFileWithAnEmbeddedFrontCover_WhenItsTagsAreRead_ThenThePictureComesBack',
    () {
      final picture = onePixelPng();
      final file = write(
        'track.flac',
        taggedFlac(tags: {'TITLE': 'With art'}, picture: picture),
      );

      final read = readTags(file);

      expect(read.picture, isNotNull);
      expect(read.picture, picture);
    },
  );

  test(
    'GivenThePictureIsNotWanted_WhenItsTagsAreRead_ThenTheTagsComeBackWithoutIt',
    () {
      final file = write(
        'track.flac',
        taggedFlac(tags: {'TITLE': 'With art'}, picture: onePixelPng()),
      );

      final read = readTags(file, withPicture: false);

      expect(read.metadata.title, 'With art');
      expect(read.picture, isNull);
    },
  );

  test(
    'GivenAFileThatIsNotAudioAtAll_WhenItsTagsAreRead_ThenItThrowsRatherThanInventingTags',
    () {
      // The scanner catches this and lists the file as untitled: a file whose
      // tags will not parse is very often a file that still plays.
      final file = write('broken.flac', 'not a flac file at all'.codeUnits);

      expect(() => readTags(file), throwsA(anything));
    },
  );
}
