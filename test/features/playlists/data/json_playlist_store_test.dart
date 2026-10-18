import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/playlists/data/json_playlist_store.dart';
import 'package:orpheus/features/playlists/domain/playlist.dart';
import 'package:path/path.dart' as p;

/// Keeping the playlists on disk.
void main() {
  late Directory root;
  late JsonPlaylistStore store;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('orpheus-playlists');
    store = JsonPlaylistStore(
      p.join(root.path, 'support'),
      clock: () => DateTime(2026, 10, 18, 9, 5, 7),
    );
  });

  tearDown(() async {
    if (root.existsSync()) await root.delete(recursive: true);
  });

  List<String> namesIn(String directory) => [
    for (final entity in Directory(directory).listSync())
      p.basename(entity.path),
  ]..sort();

  Playlist roadTrip() => Playlist(
    id: 'p1',
    name: 'Road trip',
    coverId: 'cover-9',
    createdAt: DateTime.utc(2026, 9, 1, 8, 30),
    modifiedAt: DateTime.utc(2026, 10, 2, 17, 45, 12),
    entries: const [
      PlaylistEntry(
        id: 'e1',
        path: '/library/a.flac',
        title: 'Alpha',
        artist: 'Ann',
        album: 'First',
        duration: Duration(minutes: 3, seconds: 21, milliseconds: 250),
      ),
      // The same song twice: two places, two ids.
      PlaylistEntry(id: 'e2', path: '/library/a.flac'),
      PlaylistEntry(id: 'e3', path: '/library/b.flac', title: 'Beta'),
    ],
  );

  Playlist empty() => Playlist(
    id: 'p2',
    name: 'Nothing yet',
    createdAt: DateTime.utc(2026, 10),
    modifiedAt: DateTime.utc(2026, 10),
  );

  String asideName() => 'playlists.json.bad-20261018T090507';

  test('GivenPlaylists_WhenWrittenAndRead_ThenTheyRoundTrip', () async {
    await store.write([roadTrip(), empty()]);

    final read = await store.read();

    expect(read, [roadTrip(), empty()]);
    expect(read.first.coverId, 'cover-9');
    expect(read.first.entries[0].duration?.inMilliseconds, 201250);
    expect(read.first.entries.map((e) => e.id), ['e1', 'e2', 'e3']);
    expect(read.first.entries[1].title, isNull);
    expect(read.first.modifiedAt, DateTime.utc(2026, 10, 2, 17, 45, 12));
  });

  test(
    'GivenPlaylistsWrittenTwice_WhenRead_ThenTheSecondWriteIsWhatIsThere',
    () async {
      await store.write([roadTrip(), empty()]);
      await store.write([empty()]);

      expect(await store.read(), [empty()]);
      expect(namesIn(store.directory), ['playlists.json']);
    },
  );

  test('GivenAWrittenDocument_WhenItIsInspected_ThenItIsVersioned', () async {
    await store.write([empty()]);

    final document = jsonDecode(
      await File(store.path).readAsString(),
    ) as Map<String, dynamic>;

    expect(document['version'], 1);
    expect(document['playlists'], hasLength(1));
  });

  test('GivenNoFile_WhenRead_ThenThereAreNone', () async {
    expect(await store.read(), isEmpty);
    expect(Directory(store.directory).existsSync(), isFalse);
  });

  test('GivenGarbage_WhenRead_ThenItIsKeptAsideAndNoneAreLoaded', () async {
    await Directory(store.directory).create(recursive: true);
    await File(store.path).writeAsString('{ this is not json');

    expect(await store.read(), isEmpty);

    expect(File(store.path).existsSync(), isFalse);
    expect(
      File(p.join(store.directory, asideName())).readAsStringSync(),
      '{ this is not json',
    );
  });

  test('GivenAWrongShape_WhenRead_ThenItIsKeptAside', () async {
    await Directory(store.directory).create(recursive: true);
    const wrong = '{"version": 1, "playlists": [{"id": "p1"}]}';
    await File(store.path).writeAsString(wrong);

    expect(await store.read(), isEmpty);

    expect(File(store.path).existsSync(), isFalse);
    expect(
      File(p.join(store.directory, asideName())).readAsStringSync(),
      wrong,
    );
  });

  test('GivenAnotherVersion_WhenRead_ThenItIsKeptAside', () async {
    await Directory(store.directory).create(recursive: true);
    const future = '{"version": 2, "playlists": []}';
    await File(store.path).writeAsString(future);

    expect(await store.read(), isEmpty);

    expect(File(store.path).existsSync(), isFalse);
    expect(
      File(p.join(store.directory, asideName())).readAsStringSync(),
      future,
    );
  });

  test('GivenADocumentKeptAside_WhenPlaylistsAreWritten_ThenTheyReadBackAndTheCopyStays', () async {
    await Directory(store.directory).create(recursive: true);
    await File(store.path).writeAsString('garbage');
    await store.read();

    await store.write([roadTrip()]);

    expect(await store.read(), [roadTrip()]);
    expect(namesIn(store.directory), ['playlists.json', asideName()]);
  });

  test('GivenAnUnreadableDocumentThatCannotBeSetAside_WhenRead_ThenItThrowsAndTheDocumentStays', () async {
    await Directory(store.directory).create(recursive: true);
    await File(store.path).writeAsString('garbage');
    // A non-empty directory where the copy would go: the rename refuses.
    final taken = Directory(p.join(store.directory, asideName()));
    await taken.create();
    await File(p.join(taken.path, 'inside')).writeAsBytes([1]);

    await expectLater(store.read(), throwsA(isA<FileSystemException>()));

    // Neither empty-handed nor overwritten: the document is still there for
    // the next try, and a write is not the way past it.
    expect(File(store.path).readAsStringSync(), 'garbage');
  });

  test('GivenAWriteThatFails_WhenWritten_ThenTheOldDocumentIsIntact', () async {
    await store.write([roadTrip()]);

    // The rename cannot replace a directory: the document is moved out of the
    // way and a directory put where it was, which is how atomic_write_test
    // makes the rename fail. The old document is kept beside it to compare.
    final before = File(store.path).readAsBytesSync();
    await File(store.path).delete();
    await Directory(store.path).create();
    await File(p.join(store.path, 'inside')).writeAsBytes([1]);

    await expectLater(
      store.write([empty()]),
      throwsA(isA<FileSystemException>()),
    );

    // Nothing was disturbed and no temporary file was left behind.
    expect(File(p.join(store.path, 'inside')).readAsBytesSync(), [1]);
    expect(namesIn(store.directory), ['playlists.json']);

    // And the old document, put back where it was, is still whole.
    await Directory(store.path).delete(recursive: true);
    await File(store.path).writeAsBytes(before);
    expect(await store.read(), [roadTrip()]);
  });
}
