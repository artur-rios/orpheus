import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/autofill/data/audio_metadata_tag_writer.dart';
import 'package:orpheus/features/autofill/domain/autofill_field.dart';
import 'package:path/path.dart' as p;

import '../../../support/flac_fixture.dart';

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

  group('inspect', () {
    test('GivenAnMp3_WhenInspected_ThenItsTagsAndEveryFieldAreAvailable', () async {
      final tags = await writer.inspect(copyOf('tagged.mp3'));

      expect(tags.values[AutofillField.title], 'Airbag');
      expect(tags.values[AutofillField.artist], 'Radiohed');
      expect(tags.values[AutofillField.albumArtist], 'Radiohead');
      expect(tags.values[AutofillField.trackNumber], 1);
      expect(tags.values[AutofillField.trackTotal], 12);
      expect(tags.values[AutofillField.year], 1997);
      expect(tags.writable, AutofillField.values.toSet());
    });

    test('GivenAFlac_WhenInspected_ThenItsTagsAreReadIncludingTheAlbumArtist', () async {
      final tags = await writer.inspect(flac({'TITLE': 'Airbag', 'ALBUMARTIST': 'Radiohead', 'DISCTOTAL': '2'}));

      expect(tags.values[AutofillField.title], 'Airbag');
      expect(tags.values[AutofillField.albumArtist], 'Radiohead');
      expect(tags.values[AutofillField.discTotal], 2);
      expect(tags.writable, AutofillField.values.toSet());
    });

    test('GivenAWav_WhenInspected_ThenOnlyTheFieldsItsFormatHoldsAreWritable', () async {
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
}
