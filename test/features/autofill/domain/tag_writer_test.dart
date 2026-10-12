import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/autofill/domain/tag_writer.dart';

/// Which files an autofill may write to at all.
void main() {
  test('GivenAFormatTheWriterHandles_WhenItIsAsked_ThenItMayBeWritten', () {
    for (final path in [
      '/m/a.mp3',
      '/m/b.FLAC',
      '/m/c.m4a',
      '/m/d.wav',
      '/m/e.ape',
    ]) {
      expect(canWriteTagsTo(path), isTrue, reason: path);
    }
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
