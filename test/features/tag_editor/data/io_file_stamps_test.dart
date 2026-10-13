import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/tag_editor/data/io_file_stamps.dart';
import 'package:path/path.dart' as p;

/// A file's size and time, as the disk has them now.
void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('orpheus-stamps');
  });

  tearDown(() => directory.delete(recursive: true));

  test('GivenAFile_WhenStamped_ThenItsSizeAndTimeAreWhatTheDiskSays', () async {
    final file = File(p.join(directory.path, 'track.flac'))
      ..writeAsBytesSync([1, 2, 3]);

    final stamp = await const IoFileStamps().stamp(file.path);

    expect(stamp.path, file.path);
    expect(stamp.sizeInBytes, 3);
    expect(stamp.modifiedAt, file.statSync().modified);
  });

  test('GivenNoFile_WhenStamped_ThenItThrows', () async {
    await expectLater(
      const IoFileStamps().stamp(p.join(directory.path, 'gone.flac')),
      throwsA(isA<FileSystemException>()),
    );
  });
}
