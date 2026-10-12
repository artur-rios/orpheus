import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/autofill/data/audio_metadata_tag_writer.dart';
import 'package:orpheus/features/autofill/data/id3_tag_editor.dart';
import 'package:orpheus/features/autofill/domain/autofill_field.dart';
import 'package:orpheus/features/autofill/domain/tag_writer.dart';
import 'package:path/path.dart' as p;

import '../../../support/flac_fixture.dart' show onePixelPng;
import '../../../support/id3_fixture.dart';

/// Editing an MP3 file's ID3v2 tag in memory, and nothing else in it.
void main() {
  late Directory root;
  const writer = AudioMetadataTagWriter();

  setUp(() async => root = await Directory.systemTemp.createTemp('orpheus-id3'));
  tearDown(() async {
    if (root.existsSync()) await root.delete(recursive: true);
  });

  /// What the tag reader makes of [bytes], through the writer's own
  /// [AudioMetadataTagWriter.inspect].
  Future<FileTags> readBack(Uint8List bytes) async {
    final path = p.join(root.path, 'a.mp3');
    File(path).writeAsBytesSync(bytes);

    return writer.inspect(path);
  }

  final fixture = File(p.join('test', 'support', 'tag_fixtures', 'tagged.mp3')).readAsBytesSync();
  // Real MPEG audio, which the reader needs to find after a tag.
  final audio = fixture.sublist(10 + ((fixture[6] << 21) | (fixture[7] << 14) | (fixture[8] << 7) | fixture[9]));
  final oldCover = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3]);

  /// A tag holding every field, as ID3v2.[major] spells it.
  List<Uint8List> fieldFrames(int major) => [
    textFrame('TIT2', 'Airbag', major: major),
    textFrame('TPE1', 'Radiohed', major: major),
    textFrame('TPE2', 'Radiohed', major: major),
    textFrame('TALB', 'OK Computer', major: major),
    textFrame('TRCK', '1/11', major: major),
    textFrame('TPOS', '2/3', major: major),
    textFrame(major == 4 ? 'TDRC' : 'TYER', '1996', major: major),
    textFrame('TCON', 'Rock', major: major),
    apicFrame(oldCover, major: major),
  ];

  /// An MP3: a tag of [frames] and [padding] zero bytes, then the audio.
  Uint8List mp3Of(List<Uint8List> frames, {int major = 4, int padding = 256, bool footer = false}) =>
      id3Tag(frames: [...frames, if (padding > 0) Uint8List(padding)], major: major, footer: footer, trailing: audio);

  final proposed = <AutofillField, Object?>{
    AutofillField.title: 'Paranoid Android',
    AutofillField.artist: 'Radiohead',
    AutofillField.albumArtist: 'Radiohead',
    AutofillField.album: 'OK Computer (Remastered)',
    AutofillField.trackNumber: 2,
    AutofillField.trackTotal: 12,
    AutofillField.discNumber: 1,
    AutofillField.discTotal: 1,
    AutofillField.year: 1997,
    AutofillField.genre: 'Alternative Rock',
    AutofillField.cover: onePixelPng(),
  };

  /// The frames writing each field replaces.
  const replaces = <AutofillField, Set<String>>{
    AutofillField.title: {'TIT2'},
    AutofillField.artist: {'TPE1'},
    AutofillField.albumArtist: {'TPE2'},
    AutofillField.album: {'TALB'},
    AutofillField.trackNumber: {'TRCK'},
    AutofillField.trackTotal: {'TRCK'},
    AutofillField.discNumber: {'TPOS'},
    AutofillField.discTotal: {'TPOS'},
    AutofillField.year: {'TDRC', 'TYER'},
    AutofillField.genre: {'TCON'},
    AutofillField.cover: {'APIC'},
  };

  for (final major in [4, 3]) {
    group('each field of an ID3v2.$major tag', () {
      final tagged = mp3Of(fieldFrames(major), major: major);

      for (final field in AutofillField.values) {
        final name = field.name[0].toUpperCase() + field.name.substring(1);
        test('GivenAnId3v2${major}Tag_WhenIts${name}IsWritten_ThenItReadsBackAndNothingElseChanges', () async {
          final before = await readBack(tagged);

          final edited = editId3Tags(tagged, {field: proposed[field]});
          final after = await readBack(edited);

          if (field == AutofillField.cover) {
            expect(after.cover, proposed[AutofillField.cover]);
          } else {
            expect(after.values[field], proposed[field]);
            expect(after.cover, before.cover);
          }
          for (final other in AutofillField.values.where((f) => f != field && f != AutofillField.cover)) {
            expect(after.values[other], before.values[other], reason: other.name);
          }
          // Every other frame, byte for byte and in its order.
          List<String> others(Uint8List file) => [
            for (final frame in tagOf(file).frames)
              if (!replaces[field]!.contains(frame.id)) latin1.decode(frame.raw),
          ];
          expect(others(edited), others(tagged));
          expect(tagOf(edited).major, major);
          expect(tagOf(edited).audio, audio);
        });
      }

      test('GivenAnId3v2${major}Tag_WhenEveryFieldIsWritten_ThenEachReadsBack', () async {
        final after = await readBack(editId3Tags(tagged, proposed));

        for (final field in AutofillField.values.where((f) => f != AutofillField.cover)) {
          expect(after.values[field], proposed[field], reason: field.name);
        }
        expect(after.cover, proposed[AutofillField.cover]);
      });

      test('GivenAnId3v2${major}Tag_WhenTextBeyondLatin1IsWritten_ThenItReadsBackAsWritten', () async {
        final edited = editId3Tags(tagged, {
          AutofillField.title: 'Svefn-g-englar',
          AutofillField.artist: 'Sigur Rós',
          AutofillField.album: 'Ágætis byrjun 日本 🎵',
        });

        final after = await readBack(edited);
        expect(after.values[AutofillField.artist], 'Sigur Rós');
        expect(after.values[AutofillField.album], 'Ágætis byrjun 日本 🎵');
        // UTF-8 where the version has it, UTF-16 with a byte-order mark
        // where it does not.
        final body = tagOf(edited).frames.singleWhere((f) => f.id == 'TPE1').body;
        expect(
          body,
          major == 4
              ? [3, ...utf8.encode('Sigur Rós')]
              : [1, 0xFF, 0xFE, for (final unit in 'Sigur Rós'.codeUnits) ...[unit & 0xFF, unit >> 8]],
        );
      });
    });
  }

  group('the frames it is asked to change', () {
    final tagged = mp3Of(fieldFrames(4));

    test('GivenATaggedFile_WhenNothingIsWritten_ThenEveryByteIsAsItWas', () {
      expect(editId3Tags(tagged, const {}), tagged);
    });

    test('GivenAField_WhenWrittenAsNull_ThenItsFrameIsRemovedAndNoneWritten', () {
      final edited = editId3Tags(tagged, {AutofillField.genre: null});

      expect(idsOf(edited), ['TIT2', 'TPE1', 'TPE2', 'TALB', 'TRCK', 'TPOS', 'TDRC', 'APIC']);
    });

    test('GivenTheFrameRepeated_WhenItsFieldIsWritten_ThenOneFrameTakesThePlaceOfAll', () {
      final file = mp3Of([
        textFrame('TXXX', 'kept'),
        textFrame('TIT2', 'Airbag'),
        textFrame('TPE1', 'Radiohed'),
        textFrame('TIT2', 'Airbag (Live)'),
      ]);

      final edited = editId3Tags(file, {AutofillField.title: 'Paranoid Android'});

      expect(idsOf(edited), ['TXXX', 'TIT2', 'TPE1']);
      expect(textOf(edited, 'TIT2'), 'Paranoid Android');
    });

    test('GivenNoFrameForTheField_WhenItIsWritten_ThenItIsAppendedAfterTheLastFrame', () {
      final file = mp3Of([textFrame('TIT2', 'Airbag'), textFrame('TPE1', 'Radiohed')]);

      final edited = editId3Tags(file, {AutofillField.genre: 'Rock', AutofillField.album: 'OK Computer'});

      expect(idsOf(edited), ['TIT2', 'TPE1', 'TALB', 'TCON']);
      final added = tagOf(edited).frames.last.raw;
      // A new frame has no flags.
      expect(added.sublist(8, 10), [0, 0]);
    });
  });

  group('the frames it was not asked to change', () {
    for (final major in [4, 3]) {
      test('GivenFramesNoFieldCoversInAnId3v2${major}Tag_WhenEveryFieldIsWritten_ThenEachIsKeptByteForByteAndInOrder', () {
        final kept = [
          txxxFrame('CUSTOM', 'kept', major: major),
          commFrame('kept', major: major),
          usltFrame('Words', major: major),
          syltFrame(entries: [(at: const Duration(seconds: 1), text: 'Line')], major: major),
          apicFrame(Uint8List.fromList([4, 5, 6]), pictureType: 4, major: major),
          frame('PRIV', Uint8List.fromList([...latin1.encode('owner'), 0, 0xFF, 0x00, 0x10]), major: major),
        ];
        final fields = fieldFrames(major);
        final file = mp3Of([
          kept[0],
          ...fields.sublist(0, 3),
          kept[1],
          kept[2],
          ...fields.sublist(3, 7),
          kept[3],
          kept[4],
          fields[7],
          kept[5],
          fields[8],
        ], major: major);

        final edited = editId3Tags(file, proposed);

        expect(idsOf(edited), [
          'TXXX', 'TIT2', 'TPE1', 'TPE2', 'COMM', 'USLT', 'TALB', 'TRCK', 'TPOS', //
          if (major == 4) 'TDRC' else 'TYER', 'SYLT', 'APIC', 'TCON', 'PRIV', 'APIC',
        ]);
        // Every frame but the ones the fields wrote: the back cover is an
        // APIC the cover field does not replace.
        final keptAfter = [
          for (final frame in tagOf(edited).frames)
            if (!replaces.values.any((ids) => ids.contains(frame.id)) || pictureTypeOf(frame) == 4) frame.raw,
        ];
        expect(keptAfter, kept);
      });
    }

    test('GivenAFrameWithFormatFlags_WhenAnotherFieldIsWritten_ThenItIsKeptVerbatim', () {
      // Compressed and with a data length indicator: nothing this can read,
      // and nothing it has to.
      final compressed = frame('PRIV', Uint8List.fromList([0, 0, 0, 9, 0x78, 0x9C, 1, 2, 3]), flags: 0x09);
      final file = mp3Of([textFrame('TIT2', 'Airbag'), compressed]);

      final edited = editId3Tags(file, {AutofillField.title: 'Paranoid Android'});

      expect(tagOf(edited).frames.last.raw, compressed);
    });

    test('GivenACompressedFrameOfAWrittenField_WhenItIsWritten_ThenItIsRemovedLikeAnyOther', () {
      final file = mp3Of([
        frame('TIT2', Uint8List.fromList([0, 0, 0, 9, 0x78, 0x9C, 1, 2, 3]), flags: 0x09),
        textFrame('TPE1', 'Radiohed'),
      ]);

      final edited = editId3Tags(file, {AutofillField.title: 'Paranoid Android'});

      expect(idsOf(edited), ['TIT2', 'TPE1']);
      expect(textOf(edited, 'TIT2'), 'Paranoid Android');
    });
  });

  group('a number and its total in one frame', () {
    test('GivenTrackThreeOfTwelve_WhenTheTrackTotalIsWritten_ThenItIsThreeOfTen', () async {
      final edited = editId3Tags(mp3Of([textFrame('TRCK', '3/12')]), {AutofillField.trackTotal: 10});

      expect(textOf(edited, 'TRCK'), '3/10');
      final after = await readBack(edited);
      expect(after.values[AutofillField.trackNumber], 3);
      expect(after.values[AutofillField.trackTotal], 10);
    });

    test('GivenTrackThreeOfTwelve_WhenTheTrackNumberIsWritten_ThenItIsFourOfTwelve', () {
      final edited = editId3Tags(mp3Of([textFrame('TRCK', '3/12')]), {AutofillField.trackNumber: 4});

      expect(textOf(edited, 'TRCK'), '4/12');
    });

    test('GivenTrackZeroThreeOfTwelve_WhenTheTrackTotalIsWritten_ThenTheNumberKeepsItsSpelling', () {
      final edited = editId3Tags(mp3Of([textFrame('TRCK', '03/12', major: 3)], major: 3), {
        AutofillField.trackTotal: 10,
      });

      expect(textOf(edited, 'TRCK'), '03/10');
    });

    test('GivenTrackThree_WhenTheTrackTotalIsRemoved_ThenItIsThreeAlone', () {
      final edited = editId3Tags(mp3Of([textFrame('TRCK', '3/12')]), {AutofillField.trackTotal: null});

      expect(textOf(edited, 'TRCK'), '3');
    });

    // `/12` is not a position: a total with no number cannot be stored, and
    // a write that dropped it would say it had written it.
    test('GivenNoTrackNumber_WhenOnlyTheTotalIsWritten_ThenItIsRefused', () {
      expect(
        () => editId3Tags(mp3Of([textFrame('TIT2', 'Airbag')]), {AutofillField.trackTotal: 12}),
        throwsArgumentError,
      );
    });

    test('GivenATrackFrameWithOnlyATotal_WhenOnlyTheTotalIsWritten_ThenItIsRefused', () {
      for (final existing in ['/12', '']) {
        expect(
          () => editId3Tags(mp3Of([textFrame('TRCK', existing)]), {AutofillField.trackTotal: 10}),
          throwsArgumentError,
          reason: existing,
        );
      }
    });

    test('GivenTrackThreeOfTwelve_WhenTheNumberIsRemovedAndATotalWritten_ThenItIsRefused', () {
      final file = mp3Of([textFrame('TRCK', '3/12')]);

      expect(
        () => editId3Tags(file, {AutofillField.trackNumber: null, AutofillField.trackTotal: 12}),
        throwsArgumentError,
      );
      // The total the file holds would be dropped just the same.
      expect(() => editId3Tags(file, {AutofillField.trackNumber: null}), throwsArgumentError);
    });

    test('GivenNoDiscNumber_WhenOnlyTheDiscTotalIsWritten_ThenItIsRefused', () {
      expect(
        () => editId3Tags(mp3Of([textFrame('TIT2', 'Airbag')]), {AutofillField.discTotal: 2}),
        throwsArgumentError,
      );
    });

    test('GivenTrackThreeOfTwelve_WhenBothHalvesAreRemoved_ThenTheFrameIsRemoved', () {
      final edited = editId3Tags(mp3Of([textFrame('TIT2', 'Airbag'), textFrame('TRCK', '3/12')]), {
        AutofillField.trackNumber: null,
        AutofillField.trackTotal: null,
      });

      expect(idsOf(edited), ['TIT2']);
    });

    test('GivenDiscOneOfTwo_WhenTheDiscTotalIsWritten_ThenItIsOneOfThree', () async {
      final edited = editId3Tags(mp3Of([textFrame('TPOS', '1/2')]), {AutofillField.discTotal: 3});

      expect(textOf(edited, 'TPOS'), '1/3');
      final after = await readBack(edited);
      expect(after.values[AutofillField.discNumber], 1);
      expect(after.values[AutofillField.discTotal], 3);
    });

    test('GivenATrackTotalThatIsNotANumber_WhenTheTrackNumberIsWritten_ThenItIsRefusedRatherThanLost', () {
      final file = mp3Of([textFrame('TRCK', '3/twelve')]);

      expect(() => editId3Tags(file, {AutofillField.trackNumber: 5}), throwsFormatException);
    });

    test('GivenACompressedTrackFrame_WhenOnlyItsTotalIsWritten_ThenItIsUnsupported', () {
      final file = mp3Of([frame('TRCK', Uint8List.fromList([0, 0, 0, 9, 0x78, 0x9C, 1, 2, 3]), flags: 0x09)]);

      expect(() => editId3Tags(file, {AutofillField.trackTotal: 12}), throwsA(isA<UnsupportedTagException>()));
    });
  });

  group('the year', () {
    test('GivenAnId3v24TagWithATyer_WhenTheYearIsWritten_ThenATdrcTakesItsPlace', () async {
      final file = mp3Of([textFrame('TIT2', 'Airbag'), textFrame('TYER', '1996'), textFrame('TCON', 'Rock')]);

      final edited = editId3Tags(file, {AutofillField.year: 1997});

      expect(idsOf(edited), ['TIT2', 'TDRC', 'TCON']);
      expect(textOf(edited, 'TDRC'), '1997');
      expect((await readBack(edited)).values[AutofillField.year], 1997);
    });

    test('GivenAnId3v23Tag_WhenTheYearIsWritten_ThenItIsAFourDigitTyerAndTheDayAndTimeAreKept', () async {
      final file = mp3Of([
        textFrame('TYER', '1996', major: 3),
        textFrame('TDAT', '2105', major: 3),
        textFrame('TIME', '1200', major: 3),
      ], major: 3);

      final edited = editId3Tags(file, {AutofillField.year: 997});

      expect(idsOf(edited), ['TYER', 'TDAT', 'TIME']);
      expect(textOf(edited, 'TYER'), '0997');
      expect(tagOf(edited).frames.skip(1).map((f) => f.raw), tagOf(file).frames.skip(1).map((f) => f.raw));
      expect((await readBack(edited)).values[AutofillField.year], 997);
    });

    test('GivenAnId3v23TagWithATdrc_WhenTheYearIsWritten_ThenATyerTakesItsPlace', () {
      final file = mp3Of([textFrame('TIT2', 'Airbag', major: 3), textFrame('TDRC', '1996-05-21', major: 3)], major: 3);

      final edited = editId3Tags(file, {AutofillField.year: 1997});

      expect(idsOf(edited), ['TIT2', 'TYER']);
      expect(textOf(edited, 'TYER'), '1997');
    });
  });

  group('pictures', () {
    final back = Uint8List.fromList([4, 5, 6]);
    final file = mp3Of([
      textFrame('TIT2', 'Airbag'),
      apicFrame(back, pictureType: 4),
      apicFrame(oldCover),
      textFrame('TCON', 'Rock'),
    ]);

    test('GivenABackAndAFrontCover_WhenTheCoverIsWritten_ThenTheFrontIsReplacedInPlaceAndTheBackKept', () async {
      final edited = editId3Tags(file, {AutofillField.cover: onePixelPng()});

      final before = tagOf(file).frames;
      final after = tagOf(edited).frames;
      expect(after.map((f) => f.id), ['TIT2', 'APIC', 'APIC', 'TCON']);
      expect(after[1].raw, before[1].raw);
      expect(after[2].body, [0, ...ascii.encode('image/png'), 0, 3, 0, ...onePixelPng()]);
      expect((await readBack(edited)).cover, onePixelPng());
    });

    test('GivenABackAndAFrontCover_WhenTheCoverIsRemoved_ThenOnlyTheBackIsLeft', () {
      final edited = editId3Tags(file, {AutofillField.cover: null});

      expect(idsOf(edited), ['TIT2', 'APIC', 'TCON']);
      expect(tagOf(edited).frames[1].raw, tagOf(file).frames[1].raw);
    });

    test('GivenNoPicture_WhenAJpegCoverIsWritten_ThenItIsAppendedAsAJpeg', () async {
      final jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 1, 2]);

      final edited = editId3Tags(mp3Of([textFrame('TIT2', 'Airbag')]), {AutofillField.cover: jpeg});

      expect(tagOf(edited).frames.last.body, [0, ...ascii.encode('image/jpeg'), 0, 3, 0, ...jpeg]);
      expect((await readBack(edited)).cover, jpeg);
    });

    test('GivenACompressedPicture_WhenTheCoverIsWritten_ThenItIsUnsupported', () {
      final compressed = mp3Of([frame('APIC', Uint8List.fromList([0, 0, 0, 9, 0x78, 0x9C, 1, 2, 3]), flags: 0x09)]);

      expect(() => editId3Tags(compressed, {AutofillField.cover: onePixelPng()}), throwsA(isA<UnsupportedTagException>()));
    });
  });

  group('the size of the tag and the audio after it', () {
    test('GivenATagWithRoom_WhenAFieldIsWritten_ThenTheTagKeepsItsSizeAndTheAudioItsOffset', () {
      final file = mp3Of([textFrame('TIT2', 'Airbag')], padding: 512);

      final edited = editId3Tags(file, {AutofillField.title: 'Paranoid Android', AutofillField.genre: 'Rock'});

      expect(edited.length, file.length);
      expect(tagOf(edited).size, tagOf(file).size);
      expect(edited.sublist(edited.length - audio.length), audio);
    });

    test('GivenATagWithoutRoom_WhenAFieldIsWritten_ThenItGrowsToItsFramesAndAKilobyteOfPaddingAndTheAudioIsUnchanged', () {
      final file = mp3Of([textFrame('TIT2', 'Airbag')], padding: 0);

      final edited = editId3Tags(file, {AutofillField.title: 'Paranoid Android'});

      final tag = tagOf(edited);
      final framesLength = tag.frames.fold(0, (sum, f) => sum + f.raw.length);
      expect(tag.size, framesLength + 1024);
      expect(edited.sublist(10 + framesLength, 10 + tag.size), Uint8List(1024));
      expect(tag.audio, audio);
      expect(edited.length, 10 + tag.size + audio.length);
    });

    test('GivenATagWithAFooter_WhenAFieldIsWritten_ThenTheFooterIsDroppedAndTheAudioKeepsItsOffset', () {
      final file = mp3Of([textFrame('TIT2', 'Airbag')], padding: 64, footer: true);

      final edited = editId3Tags(file, {AutofillField.title: 'Paranoid Android'});

      expect(edited[5] & 0x10, 0);
      expect(edited.length, file.length);
      expect(tagOf(edited).audio, audio);
    });

    test('GivenTheFixtureMp3_WhenEveryFieldIsWritten_ThenEachReadsBackAndTheAudioIsUnchanged', () async {
      final edited = editId3Tags(fixture, proposed);

      final after = await readBack(edited);
      for (final field in AutofillField.values.where((f) => f != AutofillField.cover)) {
        expect(after.values[field], proposed[field], reason: field.name);
      }
      expect(after.cover, onePixelPng());
      expect(tagOf(edited).audio, audio);
    });

    test('GivenTheFixtureMp3_WhenTheTitleIsWritten_ThenEveryOtherFrameIsKeptByteForByte', () {
      final edited = editId3Tags(fixture, {AutofillField.title: 'Paranoid Android'});

      List<Uint8List> others(Uint8List file) => [
        for (final frame in tagOf(file).frames)
          if (frame.id != 'TIT2') frame.raw,
      ];
      expect(others(edited), others(fixture));
      expect(idsOf(edited), idsOf(fixture));
      expect(tagOf(edited).audio, audio);
    });
  });

  group('a file with no ID3v2 tag', () {
    test('GivenAnMp3WithNoTagAndAnId3v1Trailer_WhenAFieldIsWritten_ThenAnId3v24TagIsAddedAndTheRestIsUnchanged', () async {
      final trailer = Uint8List(128)..setAll(0, 'TAGAirbag'.codeUnits);
      final file = Uint8List.fromList([...audio, ...trailer]);

      final edited = editId3Tags(file, {AutofillField.title: 'Paranoid Android'});

      final tag = tagOf(edited);
      expect(tag.major, 4);
      expect(tag.flags, 0);
      expect(idsOf(edited), ['TIT2']);
      expect(tag.size, tag.frames.single.raw.length + 1024);
      expect(tag.audio, file);
      expect((await readBack(edited)).values[AutofillField.title], 'Paranoid Android');
    });

    test('GivenAnMp3WithNoTag_WhenOnlyARemovalIsWritten_ThenItIsLeftAsItWas', () {
      expect(editId3Tags(audio, {AutofillField.title: null}), audio);
    });
  });

  group('tags it will not touch', () {
    test('GivenAnUnsynchronisedTag_WhenEdited_ThenItIsUnsupported', () {
      final file = id3Tag(frames: [textFrame('TIT2', 'Airbag')], unsynchronised: true, trailing: audio);

      expect(() => editId3Tags(file, {AutofillField.title: 'X'}), throwsA(isA<UnsupportedTagException>()));
    });

    test('GivenATagWithAnExtendedHeader_WhenEdited_ThenItIsUnsupported', () {
      final file = id3Tag(frames: [textFrame('TIT2', 'Airbag')], extendedHeader: true, trailing: audio);

      expect(() => editId3Tags(file, {AutofillField.title: 'X'}), throwsA(isA<UnsupportedTagException>()));
    });

    test('GivenAnId3v22Tag_WhenEdited_ThenItIsUnsupported', () {
      final file = id3Tag(
        frames: [frame('TT2', Uint8List.fromList([0, ...'Airbag'.codeUnits]), major: 2)],
        major: 2,
        trailing: audio,
      );

      expect(() => editId3Tags(file, {AutofillField.title: 'X'}), throwsA(isA<UnsupportedTagException>()));
    });

    test('GivenAnId3v25Tag_WhenEdited_ThenItIsUnsupported', () {
      final file = id3Tag(frames: [textFrame('TIT2', 'Airbag')], major: 5, trailing: audio);

      expect(() => editId3Tags(file, {AutofillField.title: 'X'}), throwsA(isA<UnsupportedTagException>()));
    });
  });

  group('input it cannot edit safely', () {
    void expectRefused(Uint8List file) =>
        expect(() => editId3Tags(file, {AutofillField.title: 'X'}), throwsFormatException);

    test('GivenBytesThatAreNeitherATagNorMpegAudio_WhenEdited_ThenItThrowsAFormatException', () {
      expectRefused(Uint8List.fromList('RIFF0000WAVE'.codeUnits));
    });

    test('GivenATruncatedHeader_WhenEdited_ThenItThrowsAFormatException', () {
      expectRefused(Uint8List.fromList('ID3'.codeUnits + [4, 0]));
    });

    test('GivenATagSizeThatIsNotSyncSafe_WhenEdited_ThenItThrowsAFormatException', () {
      expectRefused(mp3Of([textFrame('TIT2', 'Airbag')])..[9] = 0x80);
    });

    test('GivenATagLongerThanTheFile_WhenEdited_ThenItThrowsAFormatException', () {
      final file = mp3Of([textFrame('TIT2', 'Airbag')], padding: 0);

      expectRefused(Uint8List.sublistView(file, 0, 15));
    });

    test('GivenAFrameLongerThanItsTag_WhenEdited_ThenItThrowsAFormatException', () {
      final file = mp3Of([textFrame('TIT2', 'Airbag')], padding: 0);
      // The frame's size, one more than the tag holds.
      file[17] += 1;

      expectRefused(file);
    });

    test('GivenAFrameIdThatIsNotOne_WhenEdited_ThenItThrowsAFormatException', () {
      expectRefused(mp3Of([frame('ti!2', Uint8List.fromList([0, 1]))]));
    });

    test('GivenBytesAfterThePaddingBegins_WhenEdited_ThenItThrowsAFormatException', () {
      // What a tag whose size overstates it looks like: the audio, inside it.
      expectRefused(mp3Of([textFrame('TIT2', 'Airbag'), Uint8List(16), audio.sublist(0, 32)], padding: 0));
    });
  });
}

/// A text frame holding [text], in the encoding [encoding] names — by
/// default the one the editor writes for [major].
Uint8List textFrame(String id, String text, {int major = 4, int? encoding}) {
  final chosen = encoding ?? (major == 4 ? 3 : 1);

  return frame(id, Uint8List.fromList([chosen, ...encodedText(text, chosen)]), major: major);
}

/// An `APIC` frame holding [image] as a PNG, as a picture of [pictureType],
/// with no description.
Uint8List apicFrame(Uint8List image, {int pictureType = 3, int major = 4}) => frame(
  'APIC',
  Uint8List.fromList([0, ...ascii.encode('image/png'), 0, pictureType, 0, ...image]),
  major: major,
);

/// A `TXXX` frame: a user-defined text field, [description] holding [value].
Uint8List txxxFrame(String description, String value, {int major = 4}) => frame(
  'TXXX',
  Uint8List.fromList([0, ...latin1.encode(description), 0, ...latin1.encode(value)]),
  major: major,
);

/// A `COMM` frame: a comment, in English, with no description.
Uint8List commFrame(String text, {int major = 4}) => frame(
  'COMM',
  Uint8List.fromList([0, ...'eng'.codeUnits, 0, ...latin1.encode(text)]),
  major: major,
);

/// One frame as [tagOf] finds it: its id, its body, and the whole of it,
/// header included.
typedef ParsedFrame = ({String id, Uint8List body, Uint8List raw});

/// The tag at the start of [file], and what follows it: read independently
/// of the code under test.
({int major, int flags, int size, List<ParsedFrame> frames, Uint8List audio}) tagOf(Uint8List file) {
  expect(String.fromCharCodes(file.sublist(0, 3)), 'ID3');
  final major = file[3];
  final flags = file[5];
  final size = (file[6] << 21) | (file[7] << 14) | (file[8] << 7) | file[9];
  final end = 10 + size;

  final frames = <ParsedFrame>[];
  var offset = 10;
  while (offset + 10 <= end && file[offset] != 0) {
    final length = major == 4
        ? (file[offset + 4] << 21) | (file[offset + 5] << 14) | (file[offset + 6] << 7) | file[offset + 7]
        : (file[offset + 4] << 24) | (file[offset + 5] << 16) | (file[offset + 6] << 8) | file[offset + 7];
    frames.add((
      id: String.fromCharCodes(file.sublist(offset, offset + 4)),
      body: file.sublist(offset + 10, offset + 10 + length),
      raw: file.sublist(offset, offset + 10 + length),
    ));
    offset += 10 + length;
  }
  // Nothing but padding after the last frame.
  expect(file.sublist(offset, end).every((byte) => byte == 0), isTrue, reason: 'padding');

  return (
    major: major,
    flags: flags,
    size: size,
    frames: frames,
    audio: file.sublist(end + (flags & 0x10 != 0 ? 10 : 0)),
  );
}

/// The picture type of an `APIC` [frame], or `null` for any other frame.
int? pictureTypeOf(ParsedFrame frame) =>
    frame.id == 'APIC' ? frame.body[frame.body.indexOf(0, 1) + 1] : null;

/// The id of every frame in [file]'s tag, in order.
List<String> idsOf(Uint8List file) => [for (final frame in tagOf(file).frames) frame.id];

/// The text of [file]'s one [id] frame, in UTF-8 (v2.4) or UTF-16 (v2.3).
String textOf(Uint8List file, String id) {
  final body = tagOf(file).frames.singleWhere((f) => f.id == id).body;

  return switch (body[0]) {
    3 => utf8.decode(body.sublist(1)),
    1 => String.fromCharCodes([
      for (var i = 3; i + 1 < body.length; i += 2) body[i] | body[i + 1] << 8,
    ]),
    _ => fail('an encoding the editor does not write: ${body[0]}'),
  };
}
