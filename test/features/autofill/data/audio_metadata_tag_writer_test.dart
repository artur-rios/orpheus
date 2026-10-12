import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/autofill/data/audio_metadata_tag_writer.dart';
import 'package:orpheus/features/autofill/domain/autofill_field.dart';
import 'package:orpheus/features/autofill/domain/tag_writer.dart';
import 'package:orpheus/features/library/domain/audio_file.dart';
import 'package:path/path.dart' as p;

import '../../../support/ape_fixture.dart';
import '../../../support/flac_fixture.dart';
import '../../../support/id3_fixture.dart';

/// Reading and writing a real file's tags, in a temporary directory.
void main() {
  late Directory root;
  const writer = AudioMetadataTagWriter();

  setUp(() async => root = await Directory.systemTemp.createTemp('orpheus-tags'));
  tearDown(() async {
    if (root.existsSync()) await root.delete(recursive: true);
  });

  /// A copy of the fixture [name] in this test's directory.
  String copyOf(String name) {
    final target = p.join(root.path, name);
    File(p.join('test', 'support', 'tag_fixtures', name)).copySync(target);

    return target;
  }

  String flac(Map<String, String> tags) {
    final target = p.join(root.path, 'a.flac');
    File(target).writeAsBytesSync(taggedFlac(tags: tags));

    return target;
  }

  String ape(Map<String, String> tags) {
    final target = p.join(root.path, 'a.ape');
    File(target).writeAsBytesSync(taggedApe(tags: tags));

    return target;
  }

  group('inspect', () {
    test('GivenAnMp3_WhenInspected_ThenItsTagsAndEveryFieldAreAvailable', skip: unwritable('.mp3'), () async {
      final tags = await writer.inspect(copyOf('tagged.mp3'));

      expect(tags.values[AutofillField.title], 'Airbag');
      expect(tags.values[AutofillField.artist], 'Radiohed');
      expect(tags.values[AutofillField.albumArtist], 'Radiohead');
      expect(tags.values[AutofillField.trackNumber], 1);
      expect(tags.values[AutofillField.trackTotal], 12);
      expect(tags.values[AutofillField.year], 1997);
      expect(tags.writable, AutofillField.values.toSet());
    });

    test('GivenAFlac_WhenInspected_ThenItsTagsAreReadIncludingTheAlbumArtist', skip: unwritable('.flac'), () async {
      final tags = await writer.inspect(flac({'TITLE': 'Airbag', 'ALBUMARTIST': 'Radiohead', 'DISCTOTAL': '2'}));

      expect(tags.values[AutofillField.title], 'Airbag');
      expect(tags.values[AutofillField.albumArtist], 'Radiohead');
      expect(tags.values[AutofillField.discTotal], 2);
      expect(tags.writable, AutofillField.values.toSet());
    });

    test('GivenAFlacWithALeadingId3Tag_WhenInspected_ThenNothingIsWritable', () async {
      // The reader takes the ID3 tag for the file's tags; what the owner would
      // review is not what a write changes.
      final path = p.join(root.path, 'a.flac');
      File(path).writeAsBytesSync(
        flacOf([streamInfoBlock(), vorbisCommentBlock(['TITLE=Airbag'])], id3v2: id3v2Tag('Airbag')),
      );

      expect((await writer.inspect(path)).writable, isEmpty);
    });

    test('GivenAnMp3WhoseOnlyTagIsApe_WhenInspected_ThenNothingIsWritable', () async {
      // The reader takes the APE tag for the file's tags; a write would add an
      // ID3v2 tag in front, which is not what the owner reviewed.
      final path = p.join(root.path, 'a.mp3');
      final mpeg = File(p.join('test', 'support', 'tag_fixtures', 'tagged.mp3')).readAsBytesSync().sublist(236);
      // The APE fixture without its Monkey's Audio marker and stand-in audio.
      File(path).writeAsBytesSync([...mpeg, ...taggedApe(tags: {'Title': 'Airbag'}).sublist(64)]);

      expect((await writer.inspect(path)).writable, isEmpty);
    });

    test('GivenAWav_WhenInspected_ThenOnlyTheFieldsItsFormatHoldsAreWritable', skip: unwritable('.wav'), () async {
      final tags = await writer.inspect(copyOf('tagged.wav'));

      expect(tags.writable, isNot(contains(AutofillField.albumArtist)));
      expect(tags.writable, isNot(contains(AutofillField.discNumber)));
      expect(tags.writable, contains(AutofillField.title));
    });

    test('GivenAnOgg_WhenInspected_ThenNothingIsWritable', () async {
      expect((await writer.inspect(copyOf('tagged.ogg'))).writable, isEmpty);
    });

    test('GivenAFileThatIsNotThere_WhenInspected_ThenNothingIsWritable', () async {
      expect((await writer.inspect(p.join(root.path, 'gone.mp3'))).writable, isEmpty);
    });
  });

  AudioFile asCatalogued(String path) {
    final stat = File(path).statSync();

    return AudioFile(path: path, sizeInBytes: stat.size, modifiedAt: stat.modified);
  }

  final everything = <AutofillField, Object?>{
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

  group('write', () {
    for (final name in ['tagged.mp3', 'tagged.m4a', 'tagged.wav', 'a.flac', 'a.ape']) {
      test('GivenA${p.extension(name)}File_WhenEveryFieldItHoldsIsWritten_ThenEachReadsBack', skip: unwritable(p.extension(name)), () async {
        final path = switch (name) {
          'a.flac' => flac({'TITLE': 'Airbag', 'ARTIST': 'Radiohed', 'COMMENT': 'kept'}),
          'a.ape' => ape({'Title': 'Airbag', 'Artist': 'Radiohed', 'Comment': 'kept'}),
          _ => copyOf(name),
        };
        final writable = AudioMetadataTagWriter.fieldsFor(path);
        final values = {for (final field in writable) field: everything[field]};

        final outcome = await writer.write(path, values, expected: asCatalogued(path));
        final after = await writer.inspect(path);

        expect(outcome, WriteOutcome.written);
        for (final field in writable) {
          if (field == AutofillField.cover) {
            expect(after.cover, everything[AutofillField.cover], reason: '$name cover');
          } else {
            expect(after.values[field], everything[field], reason: '$name ${field.name}');
          }
        }
      });
    }
  });

  group('the preservation gate', () {
    // A format is only writable if a write leaves every tag it was not asked
    // to change exactly as it was — including the ones the package's model
    // does not hold. These read the file back with ffprobe-independent means:
    // the raw bytes must still carry the kept values.
    for (final name in ['tagged.mp3', 'tagged.m4a', 'tagged.wav', 'a.flac', 'a.ape']) {
      test('GivenA${p.extension(name)}FileWithTagsTheAutofillDoesNotTouch_WhenOneFieldIsWritten_ThenTheyAreAllStillThere', skip: lost[p.extension(name)], () async {
        final path = switch (name) {
          'a.flac' => flac({'TITLE': 'Airbag', 'COMMENT': 'kept', 'CUSTOM': 'kept'}),
          'a.ape' => ape({
            'Title': 'Airbag',
            'Artist': 'Radiohed',
            'Album Artist': 'Radiohead',
            'Album': 'OK Computer',
            'Year': '1997',
            'Track': '1/12',
            'Disc': '1/1',
            'Genre': 'Rock',
            'Comment': 'kept',
            'CUSTOM': 'kept',
          }),
          _ => copyOf(name),
        };
        final before = await writer.inspect(path);
        final rawBefore = latin1.decode(File(path).readAsBytesSync(), allowInvalid: true);

        final outcome = await writer.write(path, {AutofillField.title: 'Paranoid Android'}, expected: asCatalogued(path));

        final after = await writer.inspect(path);
        // The write happened: a refused or no-op write keeps everything too.
        expect(outcome, WriteOutcome.written, reason: name);
        expect(after.values[AutofillField.title], 'Paranoid Android', reason: '$name title');
        for (final field in AutofillField.values.where((f) => f != AutofillField.title)) {
          expect(after.values[field], before.values[field], reason: '$name ${field.name}');
        }
        expect(after.cover, before.cover, reason: '$name cover');
        // The tags no field covers: a comment on every format, and on the M4A
        // the album artist (aART) the writer's model cannot hold.
        final raw = latin1.decode(File(path).readAsBytesSync(), allowInvalid: true);
        expect(raw, contains('kept'), reason: '$name comment');
        if (name == 'tagged.m4a') expect(raw, contains('aART'), reason: 'm4a album artist');
        // And every other tag, by its name and its value as the file holds
        // them — which also catches what the reader cannot parse (and so
        // compares equal above) but a rewrite drops, renames or reformats.
        for (final marker in untouched[name]!) {
          expect(occurrences(raw, marker), occurrences(rawBefore, marker), reason: '$name $marker');
        }
      });
    }
  });

  group('refusals', () {
    test('GivenAFileChangedSinceItWasRead_WhenWritten_ThenItIsLeftAlone', skip: unwritable('.mp3'), () async {
      final path = copyOf('tagged.mp3');
      final catalogued = asCatalogued(path);
      // Another tag editor gets there first.
      File(path).writeAsBytesSync([...File(path).readAsBytesSync(), 0]);

      final outcome = await writer.write(path, {AutofillField.title: 'X'}, expected: catalogued);

      expect(outcome, WriteOutcome.changedSinceRead);
      expect((await writer.inspect(path)).values[AutofillField.title], 'Airbag');
    });

    test('GivenAFlacChangedSinceItWasRead_WhenWritten_ThenItIsLeftAlone', () async {
      final path = flac({'TITLE': 'Airbag'});
      final catalogued = asCatalogued(path);
      File(path).writeAsBytesSync([...File(path).readAsBytesSync(), 0]);
      final bytes = File(path).readAsBytesSync();

      final outcome = await writer.write(path, {AutofillField.title: 'X'}, expected: catalogued);

      expect(outcome, WriteOutcome.changedSinceRead);
      expect(File(path).readAsBytesSync(), bytes);
    });

    test('GivenAFlacThatIsGone_WhenWritten_ThenItIsReportedAsChangedAndNotCreated', () async {
      final path = flac({'TITLE': 'Airbag'});
      final catalogued = asCatalogued(path);
      File(path).deleteSync();

      expect(await writer.write(path, {AutofillField.title: 'X'}, expected: catalogued), WriteOutcome.changedSinceRead);
      expect(root.listSync(), isEmpty);
    });

    test(
      'GivenAFlacReachedThroughASymbolicLink_WhenWritten_ThenTheFileItPointsAtHasTheTagsAndTheLinkIsKept',
      skip: Platform.isWindows ? 'creating a symbolic link on Windows may need privileges' : null,
      () async {
        final target = p.join(root.path, 'real.flac');
        File(target).writeAsBytesSync(taggedFlac(tags: {'TITLE': 'Airbag', 'COMMENT': 'kept'}));
        final link = Link(p.join(root.path, 'a.flac'))..createSync(target);

        final outcome = await writer.write(
          link.path,
          {AutofillField.title: 'Paranoid Android'},
          expected: asCatalogued(link.path),
        );

        expect(outcome, WriteOutcome.written);
        expect(FileSystemEntity.isLinkSync(link.path), isTrue);
        expect((await writer.inspect(link.path)).values[AutofillField.title], 'Paranoid Android');
        expect((await writer.inspect(target)).values[AutofillField.title], 'Paranoid Android');
        expect([for (final entity in root.listSync()) p.basename(entity.path)]..sort(), ['a.flac', 'real.flac']);
      },
    );

    test('GivenAFlac_WhenWritten_ThenNoTemporaryFileIsLeftBehind', () async {
      final path = flac({'TITLE': 'Airbag', 'COMMENT': 'kept'});

      final outcome = await writer.write(path, {AutofillField.title: 'Paranoid Android'}, expected: asCatalogued(path));

      expect(outcome, WriteOutcome.written);
      expect([for (final entity in root.listSync()) p.basename(entity.path)], ['a.flac']);
    });

    test('GivenAFlacItCannotParse_WhenWritten_ThenItFailsAndIsUntouched', () async {
      final path = p.join(root.path, 'a.flac');
      final whole = taggedFlac(tags: {'TITLE': 'Airbag'});
      File(path).writeAsBytesSync(whole.sublist(0, whole.length - 3));
      final bytes = File(path).readAsBytesSync();

      final outcome = await writer.write(path, {AutofillField.title: 'X'}, expected: asCatalogued(path));

      expect(outcome, WriteOutcome.failed);
      expect(File(path).readAsBytesSync(), bytes);
      expect([for (final entity in root.listSync()) p.basename(entity.path)], ['a.flac']);
    });

    test('GivenAnMp3WithAnUnsynchronisedTag_WhenWritten_ThenItIsUnsupportedAndUntouched', () async {
      final path = p.join(root.path, 'a.mp3');
      final mpeg = File(p.join('test', 'support', 'tag_fixtures', 'tagged.mp3')).readAsBytesSync().sublist(236);
      final title = frame('TIT2', Uint8List.fromList([3, ...utf8.encode('Airbag')]));
      File(path).writeAsBytesSync(id3Tag(frames: [title], unsynchronised: true, trailing: mpeg));
      final bytes = File(path).readAsBytesSync();

      final outcome = await writer.write(path, {AutofillField.title: 'X'}, expected: asCatalogued(path));

      expect(outcome, WriteOutcome.unsupported);
      expect(File(path).readAsBytesSync(), bytes);
      expect([for (final entity in root.listSync()) p.basename(entity.path)], ['a.mp3']);
    });

    test('GivenAnMp3ItCannotParse_WhenWritten_ThenItFailsAndIsUntouched', () async {
      final path = p.join(root.path, 'a.mp3');
      final whole = File(p.join('test', 'support', 'tag_fixtures', 'tagged.mp3')).readAsBytesSync();
      // Audio inside the tag, where its padding should be: a tag whose size
      // overstates it, which a rewrite of the padding would cut into.
      File(path).writeAsBytesSync([...whole.sublist(0, 9), 0x7F, ...whole.sublist(10)]);
      final bytes = File(path).readAsBytesSync();

      final outcome = await writer.write(path, {AutofillField.title: 'X'}, expected: asCatalogued(path));

      expect(outcome, WriteOutcome.failed);
      expect(File(path).readAsBytesSync(), bytes);
      expect([for (final entity in root.listSync()) p.basename(entity.path)], ['a.mp3']);
    });

    test(
      'GivenAnMp3ReachedThroughASymbolicLink_WhenWritten_ThenTheFileItPointsAtHasTheTagsAndTheLinkIsKept',
      skip: Platform.isWindows ? 'creating a symbolic link on Windows may need privileges' : null,
      () async {
        final target = copyOf('tagged.mp3');
        final link = Link(p.join(root.path, 'a.mp3'))..createSync(target);

        final outcome = await writer.write(
          link.path,
          {AutofillField.title: 'Paranoid Android'},
          expected: asCatalogued(link.path),
        );

        expect(outcome, WriteOutcome.written);
        expect(FileSystemEntity.isLinkSync(link.path), isTrue);
        expect((await writer.inspect(target)).values[AutofillField.title], 'Paranoid Android');
        expect([for (final entity in root.listSync()) p.basename(entity.path)]..sort(), ['a.mp3', 'tagged.mp3']);
      },
    );

    test('GivenAnMp3_WhenWritten_ThenNoTemporaryFileIsLeftBehind', () async {
      final path = copyOf('tagged.mp3');

      final outcome = await writer.write(path, {AutofillField.title: 'Paranoid Android'}, expected: asCatalogued(path));

      expect(outcome, WriteOutcome.written);
      expect([for (final entity in root.listSync()) p.basename(entity.path)], ['tagged.mp3']);
    });

    test('GivenAnOgg_WhenWritten_ThenItIsUnsupportedAndUntouched', () async {
      final path = copyOf('tagged.ogg');
      final bytes = File(path).readAsBytesSync();

      final outcome = await writer.write(path, {AutofillField.title: 'X'}, expected: asCatalogued(path));

      expect(outcome, WriteOutcome.unsupported);
      expect(File(path).readAsBytesSync(), bytes);
    });

    test('GivenAFileThatIsGone_WhenWritten_ThenItIsReportedAsChanged', skip: unwritable('.mp3'), () async {
      final path = copyOf('tagged.mp3');
      final catalogued = asCatalogued(path);
      File(path).deleteSync();

      expect(
        await writer.write(path, {AutofillField.title: 'X'}, expected: catalogued),
        WriteOutcome.changedSinceRead,
      );
    });

    // What the gate leaves of every format it found lossy: nothing to write,
    // and a write asked for anyway refused without touching the file.
    for (final name in [
      'tagged.mp3',
      'tagged.m4a',
      'tagged.wav',
      'a.flac',
      'a.ape',
    ].where((name) => lost.containsKey(p.extension(name)))) {
      test('GivenA${p.extension(name)}File_WhenWritten_ThenThePreservationGateRefusesItAndLeavesItUntouched', () async {
        final path = switch (name) {
          'a.flac' => flac({'TITLE': 'Airbag', 'COMMENT': 'kept'}),
          'a.ape' => ape({'Title': 'Airbag', 'Comment': 'kept'}),
          _ => copyOf(name),
        };
        final bytes = File(path).readAsBytesSync();

        final tags = await writer.inspect(path);
        final outcome = await writer.write(path, {AutofillField.title: 'X'}, expected: asCatalogued(path));

        expect(tags.writable, isEmpty, reason: name);
        expect(outcome, WriteOutcome.unsupported, reason: name);
        expect(File(path).readAsBytesSync(), bytes, reason: name);
      });
    }
  });

  group('what a refused write was', () {
    // (windows, code, probe opened, probe code) -> outcome, a row per branch.
    final cases = <(bool, int?, bool, int?, WriteOutcome)>[
      (false, 13, false, null, WriteOutcome.denied),
      (false, 1, false, null, WriteOutcome.denied),
      (false, 30, false, null, WriteOutcome.denied),
      (false, 5, false, null, WriteOutcome.failed),
      (false, 32, false, null, WriteOutcome.failed),
      (false, null, false, null, WriteOutcome.failed),
      (true, 32, false, null, WriteOutcome.inUse),
      (true, 33, false, null, WriteOutcome.inUse),
      (true, 19, false, null, WriteOutcome.denied),
      (true, 5, true, null, WriteOutcome.inUse),
      (true, 5, false, 32, WriteOutcome.inUse),
      (true, 5, false, 33, WriteOutcome.inUse),
      (true, 5, false, 5, WriteOutcome.denied),
      (true, 5, false, 2, WriteOutcome.failed),
      (true, 5, false, null, WriteOutcome.failed),
      (true, 13, false, null, WriteOutcome.failed),
      (true, null, false, null, WriteOutcome.failed),
    ];

    for (final (windows, code, opened, probeCode, expected) in cases) {
      final system = windows ? 'Windows' : 'APosixSystem';
      final probe = opened ? 'AndAProbeThatOpensIt' : (probeCode == null ? '' : 'AndAProbeRefusedWith$probeCode');
      final outcome = expected.name[0].toUpperCase() + expected.name.substring(1);
      test('Given${system}Error$code${probe}_WhenTheOutcomeIsAsked_ThenItIs$outcome', () {
        expect(
          outcomeFor(windows: windows, code: code, probeCode: probeCode, probeOpened: opened),
          expected,
        );
      });
    }
  });
}

/// What a write loses from each format `audio_metadata_reader` 1.8.0 writes,
/// as that format's preservation test found it — which is why none of them
/// is in `writableExtensions`. A format leaves this map, and its tests run
/// again, when a write that keeps everything replaces the package's: FLAC
/// left it for Orpheus's own editor (`flac_tag_editor.dart`), and MP3 —
/// whose ID3v2 tag the package rebuilt, dropping every TXXX frame and
/// rewriting the TDRC date as a TYER — for `id3_tag_editor.dart`.
const lost = <String, String>{
  '.m4a':
      'the ilst atom is rebuilt from the package model: a write drops aART (the album artist), '
      '©cmt (the comment) and ©too (the encoder)',
  '.wav':
      'the package cannot read a year-only ICRD date, so a write of any field drops it',
  '.ape':
      'the APEv2 tag is rebuilt from the package model: a write renames the Album Artist item to '
      'ALBUMARTIST and rewrites Year=1997 as DATE=1997-01-01',
};

/// Why the tests that write to a format are skipped, where they are.
String? unwritable(String extension) => lost.containsKey(extension)
    ? 'the $extension format is unwritable after the preservation gate: ${lost[extension]}'
    : null;

/// Every tag each preservation fixture carries besides its title, as the
/// file spells it: the frame, atom, chunk or item name, and the value.
///
/// A write of the title alone must leave each exactly as often as it was —
/// a comment and a custom field both reading `kept`, losing one is still a
/// loss.
const untouched = <String, List<String>>{
  'tagged.mp3': [
    'TPE1', 'Radiohed', 'TALB', 'OK Computer', 'TRCK', '1/12', 'TDRC', '1997', //
    'TCON', 'Rock', 'TPE2', 'Radiohead', 'TPOS', '1/1', 'TSSE', 'Lavf61.7.103',
    'TXXX', 'comment', 'CUSTOM', 'kept',
  ],
  'tagged.m4a': [
    '©ART', 'Radiohed', 'aART', 'Radiohead', '©alb', 'OK Computer', //
    '©day', '1997', '©too', 'Lavf61.7.103', '©cmt', 'kept',
    '©gen', 'Rock', 'trkn', 'disk',
  ],
  'tagged.wav': [
    'IART', 'Radiohed', 'ICMT', 'kept', 'ICRD', '1997', 'IGNR', 'Rock', //
    'IPRD', 'OK Computer', 'IPRT', '1/12', 'ISFT', 'Lavf61.7.103',
  ],
  'a.flac': ['COMMENT=kept', 'CUSTOM=kept'],
  'a.ape': [
    'Artist', 'Radiohed', 'Album Artist', 'Radiohead', 'Album', 'OK Computer', //
    'Year', '1997', 'Track', '1/12', 'Disc', '1/1', 'Genre', 'Rock',
    'Comment', 'CUSTOM', 'kept',
  ],
};

/// How often [marker] appears in [raw], ignoring case: an APE item's key is
/// not case-sensitive, and a rewrite that only changes its case has not
/// changed the tag.
int occurrences(String raw, String marker) =>
    marker.toLowerCase().allMatches(raw.toLowerCase()).length;
