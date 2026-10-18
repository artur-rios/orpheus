import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/library/data/tag_reading.dart';
import 'package:path/path.dart' as p;

import '../../../support/ape_fixture.dart';
import '../../../support/flac_fixture.dart';
import '../../../support/id3_fixture.dart';

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

  /// A file made of [frames] as an ID3v2.4 tag, followed by real MPEG audio.
  File writeMp3(List<Uint8List> frames) =>
      write('track.mp3', [...id3Tag(frames: frames), ..._mpegAudio()]);

  /// A text frame: the encoding byte, then the text in that encoding.
  Uint8List textFrame(String id, String text) =>
      frame(id, Uint8List.fromList([3, ...encodedText(text, 3)]));

  test(
    'GivenAFlacFileWithTwoGenresInOneValue_WhenItsTagsAreRead_ThenBothAreKept',
    () {
      final file = write(
        'track.flac',
        taggedFlac(tags: {'TITLE': 'x', 'GENRE': 'Rock; Pop'}),
      );

      expect(readTags(file).metadata.genres, ['Rock', 'Pop']);
    },
  );

  test(
    'GivenAFlacFileWithTwoGenreComments_WhenItsTagsAreRead_ThenBothAreKept',
    () {
      // Vorbis comments repeat a field rather than packing one: a second
      // GENRE is a second genre, not a replacement for the first.
      final file = write(
        'track.flac',
        flacOf([
          streamInfoBlock(),
          vorbisCommentBlock(['TITLE=x', 'GENRE=Rock', 'GENRE=Pop']),
        ]),
      );

      expect(readTags(file).metadata.genres, ['Rock', 'Pop']);
    },
  );

  test(
    'GivenAnApeFileWithTwoGenresInItsGenreItem_WhenItsTagsAreRead_ThenBothAreKept',
    () {
      // APEv2 holds several values in one item, a zero byte between each.
      final file = write(
        'track.ape',
        taggedApe(tags: {'Title': 'x', 'Genre': 'Rock\u0000Pop'}),
      );

      expect(readTags(file).metadata.genres, ['Rock', 'Pop']);
    },
  );

  test(
    'GivenAnMp3WithAV24GenreFrameOfTwoValues_WhenItsTagsAreRead_ThenBothAreKept',
    () {
      final file = writeMp3([
        textFrame('TIT2', 'x'),
        textFrame('TCON', 'Rock\u0000Pop'),
      ]);

      expect(readTags(file).metadata.genres, ['Rock', 'Pop']);
    },
  );

  test(
    'GivenAnMp3WhoseGenreHasASlash_WhenItsTagsAreRead_ThenItIsOneGenre',
    () {
      final file = writeMp3([
        textFrame('TIT2', 'x'),
        textFrame('TCON', 'Hip-Hop/Rap'),
      ]);

      expect(readTags(file).metadata.genres, ['Hip-Hop/Rap']);
    },
  );

  test(
    'GivenAnMp3WhoseGenreFrameHoldsOnlyAnUnknownCode_WhenItsTagsAreRead_ThenItHasNoGenre',
    () {
      // The frame exists and resolved to nothing, which is an answer rather
      // than a reason to fall back on what the package made of it.
      final file = writeMp3([
        textFrame('TIT2', 'x'),
        textFrame('TCON', '999'),
      ]);

      expect(readTags(file).metadata.genres, isEmpty);
    },
  );

  test(
    'GivenAnMp3WithNoGenreFrame_WhenItsTagsAreRead_ThenItHasNoGenre',
    () {
      final file = writeMp3([textFrame('TIT2', 'x')]);

      expect(readTags(file).metadata.genres, isEmpty);
    },
  );

  test(
    'GivenTheFixtureFiles_WhenTheirTagsAreRead_ThenEachHasItsGenreAsAList',
    () {
      for (final name in ['tagged.mp3', 'tagged.m4a', 'tagged.ogg', 'tagged.wav']) {
        final file = File(p.join('test', 'support', 'tag_fixtures', name));

        expect(readTags(file).metadata.genres, ['Rock'], reason: name);
      }
    },
  );
}

/// Real MPEG audio, without a tag: the fixture MP3's, after its ID3v2 tag.
Uint8List _mpegAudio() {
  final mp3 = File(
    p.join('test', 'support', 'tag_fixtures', 'tagged.mp3'),
  ).readAsBytesSync();

  return mp3.sublist(
    10 + ((mp3[6] << 21) | (mp3[7] << 14) | (mp3[8] << 7) | mp3[9]),
  );
}
