import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/playback/data/file_track_probe.dart';
import 'package:path/path.dart' as p;

/// Whether a track's file is still where the catalog says it is.
void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('orpheus-probe-');
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  test('GivenAFileThatIsThere_WhenProbed_ThenItExists', () {
    final track = File(p.join(root.path, 'a.flac'))..writeAsBytesSync([0]);

    expect(const FileTrackProbe().exists(track.path), isTrue);
  });

  test('GivenAFileThatWasDeleted_WhenProbed_ThenItDoesNotExist', () {
    final track = File(p.join(root.path, 'a.flac'))..writeAsBytesSync([0]);
    track.deleteSync();

    expect(const FileTrackProbe().exists(track.path), isFalse);
  });

  test('GivenAFolderWhereTheTrackWas_WhenProbed_ThenItIsNotATrack', () {
    final folder = Directory(p.join(root.path, 'a.flac'))..createSync();

    expect(const FileTrackProbe().exists(folder.path), isFalse);
  });

  test('GivenAnEmptyPath_WhenProbed_ThenItDoesNotExist', () {
    expect(const FileTrackProbe().exists(''), isFalse);
  });
}
