import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/library/domain/audio_extensions.dart';

/// Which files a scan collects, and which pictures it takes for a sleeve.
void main() {
  for (final path in [
    '/music/a.mp3',
    '/music/a.flac',
    '/music/a.m4a',
    '/music/a.opus',
    '/music/a.ape',
    r'C:\Music\A.FLAC',
    '/music/Mixed.Mp3',
    '/music/a song.with.dots.ogg',
  ]) {
    test('GivenThePath${_label(path)}_WhenAsked_ThenItIsAudio', () {
      expect(isAudioPath(path), isTrue);
    });
  }

  for (final path in [
    '/music/notes.txt',
    '/music/cover.jpg',
    '/music/a.lrc',
    '/music/a.m3u',
    '/music/mp3',
    '/music/.flac.bak',
    '/music/no-extension',
    '',
  ]) {
    test('GivenThePath${_label(path)}_WhenAsked_ThenItIsNotAudio', () {
      expect(isAudioPath(path), isFalse);
    });
  }

  test(
    'GivenEveryCollectedExtension_WhenRead_ThenEachIsLowerCaseWithItsDot',
    () {
      for (final extension in [...audioExtensions, ...coverExtensions]) {
        expect(extension, startsWith('.'));
        expect(extension, extension.toLowerCase());
      }
    },
  );

  for (final path in [
    '/music/album/cover.jpg',
    '/music/album/Folder.PNG',
    '/music/album/front.jpeg',
    '/music/album/AlbumArt.webp',
  ]) {
    test('GivenThePicture${_label(path)}_WhenAsked_ThenItIsACover', () {
      expect(isCoverPath(path), isTrue);
    });
  }

  for (final path in [
    // A cover's name with an extension no sleeve is looked for under.
    '/music/album/cover.gif',
    '/music/album/cover.bmp',
    // A picture whose name is not one of the conventions.
    '/music/album/back.jpg',
    '/music/album/cover-2.jpg',
    '/music/album/my cover.png',
    // No extension at all.
    '/music/album/cover',
  ]) {
    test('GivenThePicture${_label(path)}_WhenAsked_ThenItIsNotACover', () {
      expect(isCoverPath(path), isFalse);
    });
  }

  test(
    'GivenTheCoverNames_WhenRead_ThenCoverIsPreferredOverFolderOverFront',
    () {
      expect(coverBaseNames.indexOf('cover'), 0);
      expect(
        coverBaseNames.indexOf('folder'),
        lessThan(coverBaseNames.indexOf('front')),
      );
    },
  );
}

/// [path] as one identifier, for a test name.
String _label(String path) {
  final label = path.replaceAll(RegExp('[^A-Za-z0-9]'), '');

  return label.isEmpty ? 'Empty' : label;
}
