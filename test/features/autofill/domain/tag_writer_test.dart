import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/autofill/domain/tag_writer.dart';

/// Which files an autofill may write to at all.
void main() {
  // MP3 and FLAC are written by Orpheus's own editors, which change only the
  // frames, comments and pictures they are asked to: see the preservation
  // gate in audio_metadata_tag_writer_test.dart.
  test('GivenAnMp3OrAFlac_WhenItIsAsked_ThenItMayBeWrittenWhateverTheExtensionsCase', () {
    for (final path in [
      '/m/a.flac',
      '/m/b.FLAC',
      '/m/c.Flac',
      '/m/d.mp3',
      '/m/e.MP3',
      '/m/f.Mp3',
    ]) {
      expect(canWriteTagsTo(path), isTrue, reason: path);
    }
    expect(writableExtensions, {'.mp3', '.flac'});
  });

  // Every other format the package writes loses tags it was not asked to
  // change, so none of them may be written.
  test(
    'GivenAFormatAWriteWouldLoseTagsFrom_WhenItIsAsked_ThenItMayNotBeWritten',
    () {
      for (final path in ['/m/c.m4a', '/m/d.mp4', '/m/e.wav', '/m/f.ape']) {
        expect(canWriteTagsTo(path), isFalse, reason: path);
      }
    },
  );

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
