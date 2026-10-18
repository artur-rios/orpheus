import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/library/data/id3_genres.dart';
import 'package:orpheus/features/library/data/id3v2_frames.dart';

import '../../../support/id3_fixture.dart';

/// Every genre in an MP3's genre frame, read from the tag's own bytes.
void main() {
  /// A text frame: the encoding byte, then [text] in that encoding.
  Uint8List textFrame(String id, String text, int encoding, {int major = 4}) =>
      frame(
        id,
        Uint8List.fromList([encoding, ...encodedText(text, encoding)]),
        major: major,
      );

  /// A v2.3 tag whose single `TCON` frame holds [text] in Latin-1.
  Uint8List genreTag(String text) =>
      id3Tag(major: 3, frames: [textFrame('TCON', text, 0, major: 3)]);

  test('GivenAV24FrameWithTwoValues_WhenItsGenresAreRead_ThenBothComeBack', () {
    final tag = id3Tag(frames: [textFrame('TCON', 'Rock\u0000Pop', 3)]);

    expect(id3GenreValues(tag), ['Rock', 'Pop']);
  });

  test(
    'GivenAV24Utf16FrameWithABomPerValue_WhenItsGenresAreRead_ThenBothComeBack',
    () {
      // Encoding 1, each value with its own byte-order mark, separated by a
      // zero 16-bit unit, and the last one terminated too.
      final utf16TwoValueTag = id3Tag(
        frames: [
          frame(
            'TCON',
            Uint8List.fromList([
              1,
              ...[0xFF, 0xFE, 0x52, 0x00, 0x6F, 0x00, 0x63, 0x00, 0x6B, 0x00],
              0,
              0,
              ...[0xFF, 0xFE, 0x50, 0x00, 0x6F, 0x00, 0x70, 0x00],
              0,
              0,
            ]),
          ),
        ],
      );

      expect(id3GenreValues(utf16TwoValueTag), ['Rock', 'Pop']);
    },
  );

  test('GivenASlashInAGenre_WhenItsGenresAreRead_ThenItIsOneValue', () {
    expect(id3GenreValues(genreTag('Hip-Hop/Rap')), ['Hip-Hop/Rap']);
  });

  test('GivenABareNumber_WhenItsGenresAreRead_ThenItIsNamed', () {
    expect(id3GenreValues(genreTag('17')), ['Rock']);
  });

  test('GivenAParenthesisedNumber_WhenItsGenresAreRead_ThenItIsNamed', () {
    expect(id3GenreValues(genreTag('(17)')), ['Rock']);
  });

  test(
    'GivenTwoParenthesisedNumbers_WhenItsGenresAreRead_ThenBothAreNamed',
    () {
      expect(id3GenreValues(genreTag('(17)(18)')), ['Rock', 'Techno']);
    },
  );

  test(
    'GivenANumberFollowedByText_WhenItsGenresAreRead_ThenTheTextIsTheGenre',
    () {
      expect(id3GenreValues(genreTag('(17)Rock & Roll')), ['Rock & Roll']);
    },
  );

  test('GivenTheRemixReference_WhenItsGenresAreRead_ThenItIsRemix', () {
    expect(id3GenreValues(genreTag('(RX)')), ['Remix']);
  });

  test('GivenTheCoverReference_WhenItsGenresAreRead_ThenItIsCover', () {
    expect(id3GenreValues(genreTag('(CR)')), ['Cover']);
  });

  test('GivenANumberOutsideTheTable_WhenItsGenresAreRead_ThenItIsDropped', () {
    expect(id3GenreValues(genreTag('999')), isEmpty);
  });

  test(
    'GivenADoubledOpeningParenthesis_WhenItsGenresAreRead_ThenOneIsTakenOff',
    () {
      expect(id3GenreValues(genreTag('((Ska)')), ['(Ska)']);
    },
  );

  test('GivenPlainText_WhenItsGenresAreRead_ThenItIsKeptAsWritten', () {
    expect(id3GenreValues(genreTag('Post-Rock')), ['Post-Rock']);
  });

  test('GivenAV22Tag_WhenItsGenresAreRead_ThenTheThreeLetterFrameIsRead', () {
    final tag = id3Tag(
      major: 2,
      frames: [textFrame('TCO', '(17)', 0, major: 2)],
    );

    expect(id3GenreValues(tag), ['Rock']);
  });

  test('GivenTwoGenreFrames_WhenItsGenresAreRead_ThenEveryValueComesBack', () {
    final tag = id3Tag(
      frames: [
        textFrame('TCON', 'Rock', 3),
        textFrame('TIT2', 'Song', 3),
        textFrame('TCON', 'Pop', 3),
      ],
    );

    expect(id3GenreValues(tag), ['Rock', 'Pop']);
  });

  test(
    'GivenATagWithNoGenreFrame_WhenItsGenresAreRead_ThenThereIsNoAnswer',
    () {
      expect(id3GenreValues(id3Tag(frames: [usltFrame('words')])), isNull);
    },
  );

  test('GivenBytesThatAreNoTag_WhenItsGenresAreRead_ThenThereIsNoAnswer', () {
    expect(id3GenreValues(Uint8List.fromList('fLaC'.codeUnits)), isNull);
  });

  group('readId3v2Tag', () {
    late Directory directory;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('orpheus-id3');
    });

    tearDown(() async {
      if (directory.existsSync()) await directory.delete(recursive: true);
    });

    File write(String name, List<int> bytes) =>
        File('${directory.path}/$name')..writeAsBytesSync(bytes);

    test(
      'GivenAFileOpeningWithATag_WhenItsTagIsRead_ThenExactlyTheTagComesBack',
      () {
        final tag = id3Tag(frames: [textFrame('TCON', 'Rock', 3)]);
        final file = write('track.mp3', [...tag, ...List.filled(64, 0xAB)]);

        expect(readId3v2Tag(file), tag);
      },
    );

    test('GivenAFileWithNoTag_WhenItsTagIsRead_ThenThereIsNone', () {
      final file = write('track.flac', 'fLaC'.codeUnits + List.filled(32, 1));

      expect(readId3v2Tag(file), isNull);
    });

    test('GivenAFileShorterThanAHeader_WhenItsTagIsRead_ThenThereIsNone', () {
      expect(readId3v2Tag(write('tiny.mp3', [0x49, 0x44, 0x33])), isNull);
    });

    test('GivenAFileThatDoesNotExist_WhenItsTagIsRead_ThenThereIsNone', () {
      expect(readId3v2Tag(File('${directory.path}/missing.mp3')), isNull);
    });

    test('GivenATagLongerThanItsFile_WhenItsTagIsRead_ThenOnlyWhatIsThereComesBack', () {
      final tag = id3Tag(frames: [textFrame('TCON', 'Rock', 3)]);
      final truncated = tag.sublist(0, tag.length - 3);
      final file = write('cut.mp3', truncated);

      expect(readId3v2Tag(file), truncated);
    });
  });
}
