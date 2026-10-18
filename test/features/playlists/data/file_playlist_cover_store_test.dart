import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/playlists/data/file_playlist_cover_store.dart';
import 'package:path/path.dart' as p;

/// Keeping the playlists' own covers on disk, one file per playlist.
void main() {
  late Directory root;
  late FilePlaylistCoverStore store;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('orpheus-playlist-covers');
    store = FilePlaylistCoverStore(p.join(root.path, 'support'));
  });

  tearDown(() async {
    if (root.existsSync()) await root.delete(recursive: true);
  });

  Uint8List bytes(List<int> values) => Uint8List.fromList(values);

  test('GivenACover_WhenPutAndRead_ThenTheBytesComeBack', () async {
    await store.put('p1', bytes([1, 2, 3]));

    expect(await store.read('p1'), [1, 2, 3]);
    expect(
      File(p.join(root.path, 'support', 'playlist-covers', 'p1')).existsSync(),
      isTrue,
    );
  });

  test('GivenNoCover_WhenRead_ThenThereIsNone', () async {
    expect(await store.read('p1'), isNull);
  });

  test('GivenACover_WhenPutAgain_ThenTheNewBytesReplaceIt', () async {
    await store.put('p1', bytes([1, 2, 3]));
    await store.put('p1', bytes([9]));

    expect(await store.read('p1'), [9]);
    expect(Directory(store.folder).listSync(), hasLength(1));
  });

  test('GivenACover_WhenDeleted_ThenItIsGone', () async {
    await store.put('p1', bytes([1, 2, 3]));

    await store.delete('p1');

    expect(await store.read('p1'), isNull);
  });

  test('GivenNoCover_WhenDeleted_ThenNothingHappens', () async {
    await store.delete('p1');

    expect(await store.read('p1'), isNull);
  });

  test('GivenTwoPlaylistsWithTheSameBytes_WhenOneIsDeleted_ThenTheOtherKeepsItsCover', () async {
    await store.put('p1', bytes([7, 7, 7]));
    await store.put('p2', bytes([7, 7, 7]));

    await store.delete('p1');

    expect(await store.read('p1'), isNull);
    expect(await store.read('p2'), [7, 7, 7]);
  });

  test('GivenAnIdThatIsAPath_WhenUsed_ThenItIsRefused', () async {
    await expectLater(
      store.put('../escape', bytes([1])),
      throwsA(isA<ArgumentError>()),
    );
    await expectLater(store.read(''), throwsA(isA<ArgumentError>()));
  });
}
