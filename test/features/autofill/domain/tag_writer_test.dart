import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/autofill/domain/tag_writer.dart';

/// Which files an autofill may write to at all.
void main() {
  // Every format the package writes loses tags it was not asked to change,
  // so none may be written: see the preservation gate in
  // audio_metadata_tag_writer_test.dart.
  test('GivenAFormatAWriteWouldLoseTagsFrom_WhenItIsAsked_ThenItMayNotBeWritten', () {
    for (final path in [
      '/m/a.mp3',
      '/m/b.FLAC',
      '/m/c.m4a',
      '/m/d.mp4',
      '/m/e.wav',
      '/m/f.ape',
    ]) {
      expect(canWriteTagsTo(path), isFalse, reason: path);
    }
    expect(writableExtensions, isEmpty);
  });

  test(
    'GivenAFormatTheWriterCannotWrite_WhenItIsAsked_ThenItMayNotBeWritten',
    () {
      for (final path in [
        '/m/a.ogg',
        '/m/b.opus',
        '/m/c.aiff',
        '/m/d.mka',
        '/m/e',
      ]) {
        expect(canWriteTagsTo(path), isFalse, reason: path);
      }
    },
  );
}
