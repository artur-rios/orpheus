import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/autofill/domain/tag_writer.dart';

/// Which files an autofill may write to at all.
void main() {
  // FLAC is written by Orpheus's own editor, which changes only the comments
  // and pictures it is asked to: see the preservation gate in
  // audio_metadata_tag_writer_test.dart.
  test('GivenAFlac_WhenItIsAsked_ThenItMayBeWrittenWhateverTheExtensionsCase', () {
    for (final path in ['/m/a.flac', '/m/b.FLAC', '/m/c.Flac']) {
      expect(canWriteTagsTo(path), isTrue, reason: path);
    }
    expect(writableExtensions, {'.flac'});
  });

  // Every other format the package writes loses tags it was not asked to
  // change, so none of them may be written.
  test('GivenAFormatAWriteWouldLoseTagsFrom_WhenItIsAsked_ThenItMayNotBeWritten', () {
    for (final path in [
      '/m/a.mp3',
      '/m/c.m4a',
      '/m/d.mp4',
      '/m/e.wav',
      '/m/f.ape',
    ]) {
      expect(canWriteTagsTo(path), isFalse, reason: path);
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
