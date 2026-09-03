import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/library/data/file_cover_store.dart';
import 'package:orpheus/features/library/domain/cover_store.dart';

/// Caching the pictures a scan pulled out of the owner's files.
void main() {
  late Directory directory;
  late FileCoverStore store;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('orpheus-covers');
    store = FileCoverStore('${directory.path}/covers');
  });

  tearDown(() async {
    if (directory.existsSync()) await directory.delete(recursive: true);
  });

  Uint8List picture(int seed) =>
      Uint8List.fromList([for (var index = 0; index < 64; index++) seed + index]);

  test(
    'GivenAPicture_WhenItIsStoredAndReadBack_ThenTheSameBytesComeOut',
    () async {
      final id = await store.put(picture(1));

      expect(await store.read(id), picture(1));
      expect(await store.contains(id), isTrue);
    },
  );

  test(
    'GivenAStoredPicture_WhenItsLocationIsAsked_ThenTheFileHoldingItIsNamed',
    () async {
      // What the platform's media session is handed: it loads and scales the
      // sleeve itself from a path rather than taking the bytes.
      final id = await store.put(picture(1));

      final location = await store.locationOf(id);

      expect(location, store.pathFor(id));
      expect(File(location!).readAsBytesSync(), picture(1));
    },
  );

  test(
    'GivenAPictureTheStoreDoesNotHold_WhenItsLocationIsAsked_ThenThereIsNone',
    () async {
      // A path to a file that is not there would be a notification showing a
      // blank square where the sleeve should be.
      expect(await store.locationOf('never-stored-0'), isNull);
    },
  );

  test(
    'GivenTheSamePictureTwice_WhenBothAreStored_ThenThereIsOneFileAndOneId',
    () async {
      // Content-addressed, which is what keeps the cache proportional to the
      // number of records rather than the number of files.
      final first = await store.put(picture(1));
      final second = await store.put(picture(1));

      expect(first, second);
      expect(Directory(store.directory).listSync().length, 1);
    },
  );

  test(
    'GivenTwoDifferentPictures_WhenBothAreStored_ThenTheyGetDifferentIds',
    () async {
      expect(await store.put(picture(1)), isNot(await store.put(picture(9))));
    },
  );

  test(
    'GivenNothingIsStoredUnderAnId_WhenItIsRead_ThenThereIsNoPictureRatherThanAFailure',
    () async {
      expect(await store.read('nothing-here'), isNull);
      expect(await store.contains('nothing-here'), isFalse);
    },
  );

  test(
    'GivenSomeStoredPictures_WhenTheCacheIsCleared_ThenNoneAreLeft',
    () async {
      await store.put(picture(1));

      await store.clear();

      expect(Directory(store.directory).existsSync(), isFalse);
    },
  );

  test('GivenTwoRunsOfTheApplication_WhenTheSameBytesAreHashed_ThenTheIdIsTheSame', () {
    // Written out rather than taken from Dart's own hash, which is free to
    // change between releases — an id that changed would orphan every cached
    // picture in the library.
    expect(coverIdOf(Uint8List.fromList([1, 2, 3])), 'd0aa6218672cf5ab-3');
  });
}
