import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/autofill/data/audio_metadata_tag_writer.dart';
import 'package:orpheus/features/autofill/data/flac_tag_editor.dart';
import 'package:orpheus/features/autofill/domain/autofill_field.dart';
import 'package:orpheus/features/autofill/domain/tag_writer.dart';
import 'package:path/path.dart' as p;

import '../../../support/flac_fixture.dart';

/// Editing a FLAC file's tags in memory, and nothing else in it.
void main() {
  late Directory root;
  const writer = AudioMetadataTagWriter();

  setUp(() async => root = await Directory.systemTemp.createTemp('orpheus-flac'));
  tearDown(() async {
    if (root.existsSync()) await root.delete(recursive: true);
  });

  /// What the tag reader makes of [bytes], through the writer's own
  /// [AudioMetadataTagWriter.inspect].
  Future<FileTags> readBack(Uint8List bytes) async {
    final path = p.join(root.path, 'a.flac');
    File(path).writeAsBytesSync(bytes);

    return writer.inspect(path);
  }

  final oldCover = Uint8List.fromList([1, 2, 3]);
  final tagged = flacOf([
    streamInfoBlock(),
    vorbisCommentBlock([
      'TITLE=Airbag',
      'ARTIST=Radiohed',
      'ALBUMARTIST=Radiohed',
      'ALBUM=OK Computer',
      'TRACKNUMBER=1',
      'TRACKTOTAL=11',
      'DISCNUMBER=2',
      'DISCTOTAL=3',
      'DATE=1996',
      'GENRE=Rock',
    ]),
    pictureBlock(oldCover),
  ]);

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

  group('each field', () {
    for (final field in AutofillField.values) {
      final name = field.name[0].toUpperCase() + field.name.substring(1);
      test('GivenATaggedFlac_WhenIts${name}IsWritten_ThenItReadsBackAndNothingElseChanges', () async {
        final before = await readBack(tagged);

        final edited = editFlacTags(tagged, {field: proposed[field]});
        final after = await readBack(edited);

        expectWellFormed(edited);
        if (field == AutofillField.cover) {
          expect(after.cover, proposed[AutofillField.cover]);
        } else {
          expect(after.values[field], proposed[field]);
          expect(after.cover, before.cover);
        }
        for (final other in AutofillField.values.where((f) => f != field && f != AutofillField.cover)) {
          expect(after.values[other], before.values[other], reason: other.name);
        }
      });
    }

    test('GivenATaggedFlac_WhenEveryFieldIsWritten_ThenEachReadsBack', () async {
      final after = await readBack(editFlacTags(tagged, proposed));

      for (final field in AutofillField.values.where((f) => f != AutofillField.cover)) {
        expect(after.values[field], proposed[field], reason: field.name);
      }
      expect(after.cover, proposed[AutofillField.cover]);
    });

    test('GivenATaggedFlac_WhenNothingIsWritten_ThenEveryByteIsAsItWas', () {
      expect(editFlacTags(tagged, const {}), tagged);
    });

    test('GivenAField_WhenWrittenAsNull_ThenItsCommentIsRemovedAndNoneWritten', () {
      final file = flacOf([
        streamInfoBlock(),
        vorbisCommentBlock(['TITLE=Airbag', 'GENRE=Rock', 'COMMENT=kept']),
      ]);

      final edited = editFlacTags(file, {AutofillField.genre: null});

      expect(commentsOf(edited).comments, ['TITLE=Airbag', 'COMMENT=kept']);
    });

    test('GivenADateAndAYear_WhenTheYearIsWritten_ThenOneFourDigitDateTakesTheirPlace', () async {
      final file = flacOf([
        streamInfoBlock(),
        vorbisCommentBlock(['DATE=1996-05-21', 'COMMENT=kept', 'YEAR=1996']),
      ]);

      final edited = editFlacTags(file, {AutofillField.year: 1997});

      expect(commentsOf(edited).comments, ['DATE=1997', 'COMMENT=kept']);
      expect((await readBack(edited)).values[AutofillField.year], 1997);
    });
  });

  group('the comments it was not asked to change', () {
    test('GivenCommentsAroundTheChangedOnes_WhenTwoFieldsAreWritten_ThenTheRestAndTheVendorAreKeptInOrder', () {
      final file = flacOf([
        streamInfoBlock(),
        vorbisCommentBlock([
          'TITLE=Airbag',
          'COMMENT=kept',
          'ARTIST=Radiohed',
          'CUSTOM=kept',
          'PERFORMER=Thom Yorke',
          'ARTISTSORT=Radiohead',
        ], vendor: 'reference libFLAC 1.4.3 20230623'),
      ]);

      final edited = editFlacTags(file, {
        AutofillField.title: 'Paranoid Android',
        AutofillField.artist: 'Radiohead',
      });

      final after = commentsOf(edited);
      expect(after.vendor, 'reference libFLAC 1.4.3 20230623');
      expect(after.comments, [
        'TITLE=Paranoid Android',
        'COMMENT=kept',
        'ARTIST=Radiohead',
        'CUSTOM=kept',
        'PERFORMER=Thom Yorke',
        'ARTISTSORT=Radiohead',
      ]);
      // Byte for byte, lengths included: every kept comment is the very bytes
      // it was, and only the two changed ones differ.
      bool unchanged(String raw) => !raw.contains('TITLE=') && !raw.substring(4).startsWith('ARTIST=');
      final kept = rawCommentsOf(file).where(unchanged).toList();
      expect(kept, hasLength(4));
      expect(rawCommentsOf(edited).where(unchanged), kept);
    });

    test('GivenTheKeyInAnyCaseAndRepeated_WhenItsFieldIsWritten_ThenOneCommentTakesThePlaceOfAll', () {
      final file = flacOf([
        streamInfoBlock(),
        vorbisCommentBlock(['COMMENT=kept', 'title=Airbag', 'CUSTOM=kept', 'Title=Airbag (Live)']),
      ]);

      final edited = editFlacTags(file, {AutofillField.title: 'Paranoid Android'});

      expect(commentsOf(edited).comments, ['COMMENT=kept', 'TITLE=Paranoid Android', 'CUSTOM=kept']);
    });

    test('GivenNoCommentForTheField_WhenItIsWritten_ThenItIsAppended', () {
      final file = flacOf([
        streamInfoBlock(),
        vorbisCommentBlock(['TITLE=Airbag', 'COMMENT=kept']),
      ]);

      final edited = editFlacTags(file, {AutofillField.genre: 'Rock'});

      expect(commentsOf(edited).comments, ['TITLE=Airbag', 'COMMENT=kept', 'GENRE=Rock']);
    });

    test('GivenAnAlbumArtistSpelledTheFfmpegWay_WhenTheAlbumArtistIsWritten_ThenAlbumArtistReplacesIt', () async {
      final file = flacOf([
        streamInfoBlock(),
        vorbisCommentBlock(['ALBUM_ARTIST=Radiohed', 'COMMENT=kept', 'ALBUM ARTIST=Radiohed']),
      ]);

      final edited = editFlacTags(file, {AutofillField.albumArtist: 'Radiohead'});

      expect(commentsOf(edited).comments, ['ALBUMARTIST=Radiohead', 'COMMENT=kept']);
      expect((await readBack(edited)).values[AutofillField.albumArtist], 'Radiohead');
    });

    test('GivenAnAlbumArtistSpelledTheFfmpegWay_WhenAnotherFieldIsWritten_ThenItIsLeftAlone', () {
      final file = flacOf([
        streamInfoBlock(),
        vorbisCommentBlock(['TITLE=Airbag', 'ALBUM_ARTIST=Radiohed']),
      ]);

      final edited = editFlacTags(file, {AutofillField.title: 'Paranoid Android'});

      expect(commentsOf(edited).comments, ['TITLE=Paranoid Android', 'ALBUM_ARTIST=Radiohed']);
    });

    test('GivenACommentWithNoEqualsSign_WhenAFieldIsWritten_ThenItIsKeptAsItWas', () {
      final file = flacOf([
        streamInfoBlock(),
        vorbisCommentBlock(['TITLE=Airbag', 'TITLE', 'COMMENT=kept']),
      ]);

      final edited = editFlacTags(file, {AutofillField.title: 'Paranoid Android'});

      expect(commentsOf(edited).comments, ['TITLE=Paranoid Android', 'TITLE', 'COMMENT=kept']);
    });
  });

  group('a number and its total in one comment', () {
    FlacBlock comments(List<String> comments) => vorbisCommentBlock(comments);

    test('GivenTrackNumberThreeOfTwelve_WhenTheTrackTotalIsWritten_ThenTheNumberIsPlainAndTheTotalHasItsOwnComment', () async {
      final file = flacOf([streamInfoBlock(), comments(['TRACKNUMBER=3/12', 'COMMENT=kept'])]);

      final edited = editFlacTags(file, {AutofillField.trackTotal: 10});

      expect(commentsOf(edited).comments, ['TRACKNUMBER=3', 'COMMENT=kept', 'TRACKTOTAL=10']);
      final after = await readBack(edited);
      expect(after.values[AutofillField.trackNumber], 3);
      expect(after.values[AutofillField.trackTotal], 10);
    });

    test('GivenTrackNumberThreeOfTwelve_WhenTheTrackNumberIsWritten_ThenTheTotalMovesToItsOwnComment', () async {
      final file = flacOf([streamInfoBlock(), comments(['TRACKNUMBER=3/12', 'COMMENT=kept'])]);

      final edited = editFlacTags(file, {AutofillField.trackNumber: 5});

      expect(commentsOf(edited).comments, ['TRACKNUMBER=5', 'COMMENT=kept', 'TRACKTOTAL=12']);
    });

    test('GivenTrackNumberThreeOfTwelveAndATotal_WhenTheTrackNumberIsWritten_ThenTheTotalCommentIsKept', () {
      final file = flacOf([streamInfoBlock(), comments(['TRACKNUMBER=3/12', 'TOTALTRACKS=12'])]);

      final edited = editFlacTags(file, {AutofillField.trackNumber: 5});

      expect(commentsOf(edited).comments, ['TRACKNUMBER=5', 'TOTALTRACKS=12']);
    });

    test('GivenTrackNumberThreeOfTwelve_WhenTheTrackTotalIsRemoved_ThenTheNumberIsPlainAndNoTotalIsLeft', () {
      final file = flacOf([streamInfoBlock(), comments(['TRACKNUMBER=03/12', 'TRACKTOTAL=12'])]);

      final edited = editFlacTags(file, {AutofillField.trackTotal: null});

      expect(commentsOf(edited).comments, ['TRACKNUMBER=03']);
    });

    test('GivenDiscOneOfTwo_WhenTheDiscTotalIsWritten_ThenTheNumberIsPlainAndTheTotalHasItsOwnComment', () async {
      final file = flacOf([streamInfoBlock(), comments(['DISCNUMBER=1/2', 'TOTALDISCS=2'])]);

      final edited = editFlacTags(file, {AutofillField.discTotal: 3});

      expect(commentsOf(edited).comments, ['DISCNUMBER=1', 'DISCTOTAL=3']);
      final after = await readBack(edited);
      expect(after.values[AutofillField.discNumber], 1);
      expect(after.values[AutofillField.discTotal], 3);
    });

    test('GivenATotalThatIsNotANumber_WhenTheTrackNumberIsWritten_ThenItIsRefusedRatherThanLost', () {
      final file = flacOf([streamInfoBlock(), comments(['TRACKNUMBER=3/twelve'])]);

      expect(() => editFlacTags(file, {AutofillField.trackNumber: 5}), throwsFormatException);
    });
  });

  group('pictures', () {
    final back = Uint8List.fromList([4, 5, 6]);
    final front = Uint8List.fromList([7, 8, 9]);
    final file = flacOf([
      streamInfoBlock(),
      vorbisCommentBlock(['TITLE=Airbag']),
      pictureBlock(back, pictureType: 4),
      pictureBlock(front),
      paddingBlock(16),
    ]);

    test('GivenABackAndAFrontCover_WhenTheCoverIsWritten_ThenTheFrontIsReplacedInPlaceAndTheBackKept', () async {
      final edited = editFlacTags(file, {AutofillField.cover: onePixelPng()});

      expectWellFormed(edited);
      final before = blocksOf(file).blocks;
      final after = blocksOf(edited).blocks;
      expect(after.map((b) => b.type), [0, 4, 6, 6, 1]);
      expect(after[2].body, before[2].body);
      expect(after[3].body, pictureBody(onePixelPng(), mime: 'image/png'));
      expect(after[4].body, before[4].body);
      expect((await readBack(edited)).cover, onePixelPng());
    });

    test('GivenABackAndAFrontCover_WhenTheCoverIsNotWritten_ThenBothAreUntouched', () {
      final edited = editFlacTags(file, {AutofillField.title: 'Paranoid Android'});

      final before = blocksOf(file).blocks;
      final after = blocksOf(edited).blocks;
      expect(after.map((b) => b.type), [0, 4, 6, 6, 1]);
      expect(after[2].body, before[2].body);
      expect(after[3].body, before[3].body);
    });

    test('GivenABackAndAFrontCoverLast_WhenTheCoverIsRemoved_ThenOnlyTheBackIsLeftAndItIsTheLastBlock', () {
      final coverLast = flacOf([
        streamInfoBlock(),
        vorbisCommentBlock(['TITLE=Airbag']),
        pictureBlock(back, pictureType: 4),
        pictureBlock(front),
      ]);

      final edited = editFlacTags(coverLast, {AutofillField.cover: null});

      expectWellFormed(edited);
      final after = blocksOf(edited).blocks;
      expect(after.map((b) => b.type), [0, 4, 6]);
      expect(after[2].body, blocksOf(coverLast).blocks[2].body);
      expect(after[2].last, isTrue);
    });

    test('GivenNoPicture_WhenACoverIsWritten_ThenItGoesDirectlyAfterTheComments', () async {
      final bare = flacOf([
        streamInfoBlock(),
        seekTableBlock(),
        vorbisCommentBlock(['TITLE=Airbag']),
        paddingBlock(8),
      ]);
      final jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 1, 2]);

      final edited = editFlacTags(bare, {AutofillField.cover: jpeg});

      expectWellFormed(edited);
      final after = blocksOf(edited).blocks;
      expect(after.map((b) => b.type), [0, 3, 4, 6, 1]);
      expect(after[3].body, pictureBody(jpeg, mime: 'image/jpeg'));
      expect((await readBack(edited)).cover, jpeg);
    });

    test('GivenAFrontCoverEmbeddedInTheComments_WhenTheCoverIsWritten_ThenItIsReplacedToo', () async {
      final embedded = base64Encode(pictureBody(Uint8List.fromList([7, 7, 7]), mime: 'image/png'));
      final embeddedBack = base64Encode(pictureBody(back, mime: 'image/png', pictureType: 4));
      final withEmbedded = flacOf([
        streamInfoBlock(),
        vorbisCommentBlock([
          'TITLE=Airbag',
          'METADATA_BLOCK_PICTURE=$embedded',
          'METADATA_BLOCK_PICTURE=$embeddedBack',
        ]),
      ]);

      final edited = editFlacTags(withEmbedded, {AutofillField.cover: onePixelPng()});

      expect(commentsOf(edited).comments, ['TITLE=Airbag', 'METADATA_BLOCK_PICTURE=$embeddedBack']);
      expect((await readBack(edited)).cover, onePixelPng());
    });
  });

  group('everything else in the file', () {
    test('GivenEveryKindOfBlockAndAudio_WhenEveryFieldIsWritten_ThenTheOtherBlocksAndTheAudioAreUnchangedAndInOrder', () {
      final audio = List<int>.generate(4096, (i) => (i * 31 + 7) & 0xFF);
      final file = flacOf([
        streamInfoBlock(),
        applicationBlock('ATCH', [1, 2, 3, 4, 5]),
        seekTableBlock(),
        vorbisCommentBlock(['TITLE=Airbag', 'COMMENT=kept']),
        (type: 5, body: Uint8List.fromList(List<int>.filled(40, 9))),
        pictureBlock(Uint8List.fromList([1]), pictureType: 8),
        paddingBlock(1024),
      ], audio: audio);

      final edited = editFlacTags(file, proposed);

      expectWellFormed(edited);
      final before = blocksOf(file);
      final after = blocksOf(edited);
      expect(after.audio, audio);
      expect(after.prefix, before.prefix);
      expect(after.blocks.map((b) => b.type), [0, 2, 3, 4, 6, 5, 6, 1]);
      final untouchedBefore = before.blocks.where((b) => b.type != 4).toList();
      final untouchedAfter = [
        for (final (index, block) in after.blocks.indexed)
          if (index != 3 && index != 4) block,
      ];
      expect(untouchedAfter.map((b) => b.body), untouchedBefore.map((b) => b.body));
    });

    test('GivenALeadingId3Tag_WhenAFieldIsWritten_ThenTheTagIsKeptVerbatimInFront', () {
      final id3 = id3v2Tag('Airbag');
      final file = flacOf([
        streamInfoBlock(),
        vorbisCommentBlock(['TITLE=Airbag']),
      ], id3v2: id3, audio: [1, 2, 3]);

      final edited = editFlacTags(file, {AutofillField.title: 'Paranoid Android'});

      expect(edited.sublist(0, id3.length), id3);
      expect(String.fromCharCodes(edited.sublist(id3.length, id3.length + 4)), 'fLaC');
      expectWellFormed(edited);
      expect(commentsOf(edited).comments, ['TITLE=Paranoid Android']);
      expect(blocksOf(edited).audio, [1, 2, 3]);
    });

    test('GivenNoCommentBlock_WhenAFieldIsWritten_ThenOneIsAddedAfterTheStreamInfo', () async {
      final file = flacOf([streamInfoBlock(), paddingBlock(32)], audio: [1, 2, 3]);

      final edited = editFlacTags(file, {AutofillField.title: 'Paranoid Android'});

      expectWellFormed(edited);
      final after = blocksOf(edited);
      expect(after.blocks.map((b) => b.type), [0, 4, 1]);
      expect(commentsOf(edited).vendor, 'Orpheus');
      expect(commentsOf(edited).comments, ['TITLE=Paranoid Android']);
      expect(after.audio, [1, 2, 3]);
      expect((await readBack(edited)).values[AutofillField.title], 'Paranoid Android');
    });

    test('GivenTheCommentsWereTheLastBlock_WhenACoverIsAdded_ThenOnlyTheCoverIsFlaggedLast', () {
      final edited = editFlacTags(taggedFlac(tags: {'TITLE': 'Airbag'}), {AutofillField.cover: onePixelPng()});

      expectWellFormed(edited);
      expect(blocksOf(edited).blocks.map((b) => (b.type, b.last)), [(0, false), (4, false), (6, true)]);
    });
  });

  group('input it cannot edit safely', () {
    test('GivenBytesThatAreNotFlac_WhenEdited_ThenItThrowsAFormatException', () {
      expect(
        () => editFlacTags(Uint8List.fromList('RIFF0000WAVE'.codeUnits), {AutofillField.title: 'X'}),
        throwsFormatException,
      );
    });

    test('GivenABlockLongerThanTheFile_WhenEdited_ThenItThrowsAFormatException', () {
      final file = taggedFlac(tags: {'TITLE': 'Airbag'});

      expect(
        () => editFlacTags(Uint8List.sublistView(file, 0, file.length - 3), {AutofillField.title: 'X'}),
        throwsFormatException,
      );
    });

    test('GivenMetadataThatEndsBeforeItsLastBlock_WhenEdited_ThenItThrowsAFormatException', () {
      // The STREAMINFO block alone, not flagged last, and nothing after it.
      final file = flacOf([streamInfoBlock(), paddingBlock(4)]);

      expect(
        () => editFlacTags(Uint8List.sublistView(file, 0, file.length - 8), {AutofillField.title: 'X'}),
        throwsFormatException,
      );
    });

    test('GivenACommentLongerThanItsBlock_WhenEdited_ThenItThrowsAFormatException', () {
      final body = vorbisCommentBlock(['TITLE=Airbag']).body;
      // The comment's own length, one more than the block holds.
      final lengthAt = body.length - 'TITLE=Airbag'.length - 4;
      ByteData.sublistView(body).setUint32(lengthAt, 13, Endian.little);
      final file = flacOf([streamInfoBlock(), (type: 4, body: body)]);

      expect(() => editFlacTags(file, {AutofillField.title: 'X'}), throwsFormatException);
    });

    test('GivenAnId3TagLongerThanTheFile_WhenEdited_ThenItThrowsAFormatException', () {
      final id3 = id3v2Tag('Airbag');
      id3[9] = 0x7F;

      expect(
        () => editFlacTags(Uint8List.fromList([...id3.sublist(0, 10), ...'fLaC'.codeUnits]), {AutofillField.title: 'X'}),
        throwsFormatException,
      );
    });
  });
}

/// A metadata block as [blocksOf] finds it.
typedef ParsedBlock = ({bool last, int type, Uint8List body});

/// What comes before the first block, the blocks, and what comes after the
/// last: read independently of the code under test.
({Uint8List prefix, List<ParsedBlock> blocks, Uint8List audio}) blocksOf(Uint8List file) {
  var offset = 0;
  if (String.fromCharCodes(file.sublist(0, 3)) == 'ID3') {
    final size = (file[6] << 21) | (file[7] << 14) | (file[8] << 7) | file[9];
    offset = 10 + size;
  }
  expect(String.fromCharCodes(file.sublist(offset, offset + 4)), 'fLaC');
  offset += 4;
  final prefix = file.sublist(0, offset);

  final blocks = <ParsedBlock>[];
  var last = false;
  while (!last) {
    last = file[offset] & 0x80 != 0;
    final type = file[offset] & 0x7F;
    final length = (file[offset + 1] << 16) | (file[offset + 2] << 8) | file[offset + 3];
    blocks.add((last: last, type: type, body: file.sublist(offset + 4, offset + 4 + length)));
    offset += 4 + length;
  }

  return (prefix: prefix, blocks: blocks, audio: file.sublist(offset));
}

/// [file] parses to its end, and only its final metadata block says it is
/// the last.
void expectWellFormed(Uint8List file) {
  final blocks = blocksOf(file).blocks;
  expect(blocks.first.type, 0, reason: 'STREAMINFO first');
  expect([for (final block in blocks) block.last], [...List.filled(blocks.length - 1, false), true]);
}

/// Each comment of [file]'s VORBIS_COMMENT block, its four length bytes
/// included, as Latin-1 text so that equal bytes compare equal.
List<String> rawCommentsOf(Uint8List file) {
  final body = blocksOf(file).blocks.singleWhere((b) => b.type == 4).body;
  final data = ByteData.sublistView(body);
  var offset = 4 + data.getUint32(0, Endian.little);
  final count = data.getUint32(offset, Endian.little);
  offset += 4;

  final comments = <String>[];
  for (var i = 0; i < count; i++) {
    final length = data.getUint32(offset, Endian.little);
    comments.add(latin1.decode(body.sublist(offset, offset + 4 + length)));
    offset += 4 + length;
  }

  return comments;
}

/// [file]'s vendor string and comments, decoded.
({String vendor, List<String> comments}) commentsOf(Uint8List file) {
  final body = blocksOf(file).blocks.singleWhere((b) => b.type == 4).body;
  final data = ByteData.sublistView(body);
  final vendorLength = data.getUint32(0, Endian.little);
  final vendor = utf8.decode(body.sublist(4, 4 + vendorLength));
  var offset = 4 + vendorLength;
  final count = data.getUint32(offset, Endian.little);
  offset += 4;
  final comments = <String>[];
  for (var i = 0; i < count; i++) {
    final length = data.getUint32(offset, Endian.little);
    comments.add(utf8.decode(body.sublist(offset + 4, offset + 4 + length)));
    offset += 4 + length;
  }
  expect(offset, body.length, reason: 'nothing after the comments');

  return (vendor: vendor, comments: comments);
}

/// The PICTURE body the editor writes for [image]: no description and no
/// dimensions, which a reader takes from the image itself.
Uint8List pictureBody(Uint8List image, {required String mime, int pictureType = 3}) {
  final data = BytesBuilder();
  void u32(int value) => data.add((ByteData(4)..setUint32(0, value)).buffer.asUint8List());
  u32(pictureType);
  u32(mime.length);
  data.add(ascii.encode(mime));
  u32(0);
  u32(0);
  u32(0);
  u32(0);
  u32(0);
  u32(image.length);
  data.add(image);

  return data.toBytes();
}
