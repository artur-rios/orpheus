import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/lyrics/data/id3_synced_lyrics.dart';

import '../../../support/id3_fixture.dart';

/// Reading ID3's synchronised lyrics frame.
///
/// The sheets here are invented lines with times attached: what is under test
/// is the shape of the frame — its versions, its flags and its encodings — and
/// a made-up sheet exercises every one of them.
void main() {
  /// A tag holding one `SYLT` frame built from [entries].
  Uint8List tagWith(
    List<({Duration at, String text})> entries, {
    int major = 4,
    int encoding = 0,
    int timestampFormat = 2,
    int contentType = 1,
    String descriptor = '',
    int flags = 0,
    bool dataLengthIndicator = false,
    bool frameUnsynchronised = false,
    bool tagUnsynchronised = false,
    bool extendedHeader = false,
  }) => id3Tag(
    major: major,
    unsynchronised: tagUnsynchronised,
    extendedHeader: extendedHeader,
    frames: [
      syltFrame(
        entries: entries,
        major: major,
        encoding: encoding,
        timestampFormat: timestampFormat,
        contentType: contentType,
        descriptor: descriptor,
        flags: flags,
        dataLengthIndicator: dataLengthIndicator,
        unsynchronised: frameUnsynchronised,
      ),
    ],
    trailing: List.filled(64, 0x55),
  );

  const sheet = [
    (at: Duration(seconds: 10), text: 'The opening line'),
    (at: Duration(seconds: 20), text: 'The second line'),
  ];

  test(
    'GivenATagWithOneLinePerEntry_WhenTheFrameIsRead_ThenEachEntryIsALine',
    () {
      // What most writers produce: no newline anywhere, one entry per line.
      final lyrics = parseId3SyncedLyrics(tagWith(sheet));

      expect(lyrics!.isSynced, isTrue);
      expect(lyrics.lines.map((line) => line.text), [
        'The opening line',
        'The second line',
      ]);
      expect(lyrics.lines.first.at, const Duration(seconds: 10));
      expect(lyrics.lines.last.at, const Duration(seconds: 20));
    },
  );

  test(
    'GivenAFrameTimedPerSyllable_WhenItIsRead_ThenTheSyllablesAreJoinedIntoLines',
    () {
      // The other thing the frame allows: a time per word, with a newline
      // where a line begins. The line's own time is the first syllable's.
      final lyrics = parseId3SyncedLyrics(
        tagWith(const [
          (at: Duration(seconds: 5), text: 'One '),
          (at: Duration(milliseconds: 5400), text: 'word '),
          (at: Duration(milliseconds: 5900), text: 'each'),
          (at: Duration(seconds: 9), text: '\nA second line'),
        ]),
      );

      expect(lyrics!.lines.map((line) => line.text), [
        'One word each',
        'A second line',
      ]);
      expect(lyrics.lines.first.at, const Duration(seconds: 5));
      expect(lyrics.lines.last.at, const Duration(seconds: 9));
    },
  );

  test(
    'GivenAV23Tag_WhenTheFrameIsRead_ThenItsPlainFrameLengthsAreUnderstood',
    () {
      // v2.3 states a frame's length plainly and v2.4 seven bits to the byte.
      // Reading one as the other loses every frame after the first long one.
      final lyrics = parseId3SyncedLyrics(tagWith(sheet, major: 3));

      expect(lyrics!.lines, hasLength(2));
    },
  );

  test(
    'GivenAV22TagWithAThreeLetterFrameId_WhenItIsRead_ThenTheWordsAreStillFound',
    () {
      final lyrics = parseId3SyncedLyrics(tagWith(sheet, major: 2));

      expect(lyrics!.lines.first.text, 'The opening line');
    },
  );

  test(
    'GivenTextInUtf16WithAByteOrderMark_WhenItIsRead_ThenTheAccentsSurvive',
    () {
      final lyrics = parseId3SyncedLyrics(
        tagWith(const [
          (at: Duration(seconds: 1), text: 'Malemolência'),
        ], encoding: 1),
      );

      expect(lyrics!.lines.single.text, 'Malemolência');
    },
  );

  test('GivenTextInBigEndianUtf16_WhenItIsRead_ThenItIsNotReadBackwards', () {
    final lyrics = parseId3SyncedLyrics(
      tagWith(const [(at: Duration(seconds: 1), text: 'Céu')], encoding: 2),
    );

    expect(lyrics!.lines.single.text, 'Céu');
  });

  test('GivenTextInUtf8_WhenItIsRead_ThenTheAccentsSurvive', () {
    final lyrics = parseId3SyncedLyrics(
      tagWith(const [
        (at: Duration(seconds: 1), text: 'Água de beber'),
      ], encoding: 3),
    );

    expect(lyrics!.lines.single.text, 'Água de beber');
  });

  test(
    'GivenAnUnsynchronisedTag_WhenItIsRead_ThenTheInsertedBytesAreNotWords',
    () {
      // A tag whose bytes were rewritten so that no run of them looks like the
      // start of audio. Undoing that is what keeps the text intact — and 'ÿ'
      // is a character that writes as the byte the rewriting is about.
      final lyrics = parseId3SyncedLyrics(
        tagWith(const [
          (at: Duration(seconds: 1), text: 'A line with a ÿ in it'),
        ], tagUnsynchronised: true, major: 3),
      );

      expect(lyrics!.lines.single.text, 'A line with a ÿ in it');
    },
  );

  test(
    'GivenAFrameUnsynchronisedOnItsOwn_WhenItIsRead_ThenTheSameHolds',
    () {
      // From v2.4 the transformation is per frame rather than per tag.
      final lyrics = parseId3SyncedLyrics(
        tagWith(const [
          (at: Duration(seconds: 1), text: 'A line with a ÿ in it'),
        ], frameUnsynchronised: true),
      );

      expect(lyrics!.lines.single.text, 'A line with a ÿ in it');
    },
  );

  test(
    'GivenAFrameWithADataLengthIndicator_WhenItIsRead_ThenTheIndicatorIsNotText',
    () {
      final lyrics = parseId3SyncedLyrics(
        tagWith(sheet, dataLengthIndicator: true),
      );

      expect(lyrics!.lines.first.text, 'The opening line');
    },
  );

  test(
    'GivenATagWithAnExtendedHeader_WhenItIsRead_ThenTheFramesAreStillFound',
    () {
      for (final major in const [3, 4]) {
        final lyrics = parseId3SyncedLyrics(
          tagWith(sheet, major: major, extendedHeader: true),
        );

        expect(lyrics?.lines.first.text, 'The opening line');
      }
    },
  );

  test(
    'GivenAFrameBeforeTheOneWanted_WhenTheTagIsRead_ThenTheWordsAreStillReached',
    () {
      final lyrics = parseId3SyncedLyrics(
        id3Tag(
          frames: [
            usltFrame('Plain words in the other frame'),
            syltFrame(entries: sheet),
          ],
        ),
      );

      expect(lyrics!.lines.first.text, 'The opening line');
    },
  );

  test(
    'GivenTimesCountedInMpegFrames_WhenTheFrameIsRead_ThenNothingIsInvented',
    () {
      // Turning those into a position needs the frame rate of the audio, which
      // a header parse does not have. The caller falls back to the text frame
      // rather than being handed times that are wrong.
      expect(parseId3SyncedLyrics(tagWith(sheet, timestampFormat: 1)), isNull);
    },
  );

  test(
    'GivenAFrameCarryingSomethingOtherThanWords_WhenItIsRead_ThenItIsNotShownAsWords',
    () {
      // The same frame is allowed to carry chords, movement names and trivia.
      for (final contentType in const [0, 3, 4, 5, 6]) {
        expect(
          parseId3SyncedLyrics(tagWith(sheet, contentType: contentType)),
          isNull,
        );
      }
    },
  );

  test(
    'GivenACompressedOrEncryptedFrame_WhenTheTagIsRead_ThenItIsSteppedOver',
    () {
      // Neither can be undone here, and half-reading either would be words
      // made of noise.
      expect(parseId3SyncedLyrics(tagWith(sheet, flags: 0x08)), isNull);
      expect(parseId3SyncedLyrics(tagWith(sheet, flags: 0x04)), isNull);
      expect(
        parseId3SyncedLyrics(tagWith(sheet, major: 3, flags: 0x80)),
        isNull,
      );
    },
  );

  test('GivenTheDescriptor_WhenTheFrameIsRead_ThenItIsNotTakenForALine', () {
    final lyrics = parseId3SyncedLyrics(
      tagWith(sheet, descriptor: 'Written by somebody'),
    );

    expect(lyrics!.lines, hasLength(2));
    expect(lyrics.lines.first.text, 'The opening line');
  });

  test('GivenAFileWithNoId3TagAtAll_WhenItIsRead_ThenThereAreNoWords', () {
    expect(parseId3SyncedLyrics(Uint8List.fromList('fLaC'.codeUnits)), isNull);
    expect(parseId3SyncedLyrics(Uint8List(0)), isNull);
    expect(parseId3SyncedLyrics(Uint8List(64)), isNull);
  });

  test('GivenATagWithNoSyncedLyricsInIt_WhenItIsRead_ThenThereAreNoWords', () {
    expect(
      parseId3SyncedLyrics(id3Tag(frames: [usltFrame('Plain words')])),
      isNull,
    );
  });

  test(
    'GivenAFilesFirstBytes_WhenTheTagLengthIsAskedFor_ThenItIsWhatToRead',
    () {
      // What keeps the reader off the audio: ten bytes in, and it knows
      // exactly how much of the file is header.
      final tag = id3Tag(frames: [syltFrame(entries: sheet)]);
      final length = id3TagLengthOf(
        Uint8List.sublistView(tag, 0, id3HeaderLength),
      );

      expect(length, isNotNull);
      expect(parseId3SyncedLyrics(Uint8List.sublistView(tag, 0, length!)),
          isNotNull);
    },
  );

  test(
    'GivenATagWithAFooter_WhenItsLengthIsAskedFor_ThenTheFooterIsCountedIn',
    () {
      final plain = id3Tag(frames: [syltFrame(entries: sheet)]);
      final withFooter = id3Tag(
        frames: [syltFrame(entries: sheet)],
        footer: true,
      );

      expect(
        id3TagLengthOf(Uint8List.sublistView(withFooter, 0, id3HeaderLength)),
        id3TagLengthOf(Uint8List.sublistView(plain, 0, id3HeaderLength))! + 10,
      );
    },
  );

  test('GivenAFileThatIsNotTagged_WhenItsTagLengthIsAskedFor_ThenThereIsNone', () {
    expect(id3TagLengthOf(Uint8List.fromList('fLaC'.codeUnits)), isNull);
    expect(id3TagLengthOf(Uint8List(id3HeaderLength)), isNull);
  });
}
