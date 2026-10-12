import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:orpheus/core/di/providers.dart';
import 'package:orpheus/core/settings/in_memory_settings_store.dart';

import '../../../support/fakes.dart';
import '../../../support/test_container.dart';

/// Registering and removing the folders the library is built from.
void main() {
  test(
    'GivenNoFolderIsRegistered_WhenTheOwnerPicksOne_ThenItIsAddedAndRemembered',
    () async {
      final harness = Harness(picker: FakeFolderPicker('/home/me/Music'));

      final added = await harness
          .read(libraryFoldersControllerProvider.notifier)
          .addByPicking();

      expect(added, isTrue);
      expect(harness.read(libraryFoldersControllerProvider), ['/home/me/Music']);
      expect(harness.settings.libraryFolders, ['/home/me/Music']);
    },
  );

  test(
    'GivenTheOwnerDismissesTheFolderChooser_WhenNothingIsPicked_ThenNothingChanges',
    () async {
      // A dismissed dialog must not cost a re-scan of the whole library.
      final harness = Harness(picker: FakeFolderPicker());

      final added = await harness
          .read(libraryFoldersControllerProvider.notifier)
          .addByPicking();

      expect(added, isFalse);
      expect(harness.read(libraryFoldersControllerProvider), isEmpty);
    },
  );

  test(
    'GivenAFolderIsAlreadyRegistered_WhenItIsAddedAgain_ThenItIsNotAddedTwice',
    () async {
      final harness = Harness(
        settings: InMemorySettingsStore(libraryFolders: const ['/music']),
      );

      final added = await harness
          .read(libraryFoldersControllerProvider.notifier)
          .add('/music');

      expect(added, isFalse);
      expect(harness.read(libraryFoldersControllerProvider), ['/music']);
    },
  );

  test(
    'GivenAFolderIsRegistered_WhenItIsAddedAgainWithATrailingSeparator_ThenItIsNotAddedTwice',
    () async {
      // Compared as strings these were two folders, and the library was
      // scanned — and listed — twice over.
      final harness = Harness(
        settings: InMemorySettingsStore(libraryFolders: const ['/music']),
      );

      final added = await harness
          .read(libraryFoldersControllerProvider.notifier)
          .add('/music/');

      expect(added, isFalse);
      expect(harness.read(libraryFoldersControllerProvider), ['/music']);
    },
  );

  test(
    'GivenAWindowsHost_WhenARegisteredFolderIsAddedInAnotherCase_ThenItIsNotAddedTwice',
    () async {
      final harness = Harness(
        platform: const FakeHostPlatform(isWindows: true, isLinux: false),
        settings: InMemorySettingsStore(
          libraryFolders: const [r'C:\Users\me\Music'],
        ),
      );

      final added = await harness
          .read(libraryFoldersControllerProvider.notifier)
          .add(r'c:\users\me\music\');

      expect(added, isFalse);
      expect(harness.read(libraryFoldersControllerProvider), [
        r'C:\Users\me\Music',
      ]);
    },
  );

  test(
    'GivenALinuxHost_WhenAFolderIsAddedInAnotherCase_ThenItIsADifferentFolder',
    () async {
      // Case is the folder's name there, not its spelling.
      final harness = Harness(
        settings: InMemorySettingsStore(libraryFolders: const ['/music']),
      );

      final added = await harness
          .read(libraryFoldersControllerProvider.notifier)
          .add('/Music');

      expect(added, isTrue);
      expect(harness.read(libraryFoldersControllerProvider), [
        '/music',
        '/Music',
      ]);
    },
  );

  test(
    'GivenTwoOfferedFoldersAreOneFolderAndALinkToIt_WhenTheyAreAllAdded_ThenOnlyTheFirstArrives',
    () async {
      // Android's `/sdcard/Music` and `/storage/emulated/0/Music`, made here
      // out of a temporary folder and a link to it.
      final root = await Directory.systemTemp.createTemp('orpheus-folders');
      addTearDown(() => root.delete(recursive: true));
      final music = await Directory(p.join(root.path, 'Music')).create();
      final link = await Link(p.join(root.path, 'sdcard')).create(music.path);

      final harness = Harness(
        platform: FakeHostPlatform(
          isWindows: Platform.isWindows,
          isLinux: !Platform.isWindows,
        ),
      );

      final added = await harness
          .read(libraryFoldersControllerProvider.notifier)
          .addAll([music.path, link.path]);

      expect(added, isTrue);
      expect(harness.read(libraryFoldersControllerProvider), [music.path]);
    },
  );

  test(
    'GivenTwoFoldersAreRegistered_WhenOneIsRemoved_ThenTheOtherStays',
    () async {
      final harness = Harness(
        settings: InMemorySettingsStore(
          libraryFolders: const ['/music', '/podcasts'],
        ),
      );

      await harness
          .read(libraryFoldersControllerProvider.notifier)
          .remove('/music');

      expect(harness.read(libraryFoldersControllerProvider), ['/podcasts']);
      expect(harness.settings.libraryFolders, ['/podcasts']);
    },
  );

  test(
    'GivenSomeOfferedFoldersAreAlreadyRegistered_WhenTheyAreAllAdded_ThenOnlyTheNewOnesArrive',
    () async {
      final harness = Harness(
        settings: InMemorySettingsStore(libraryFolders: const ['/music']),
      );

      final added = await harness
          .read(libraryFoldersControllerProvider.notifier)
          .addAll(['/music', '/downloads']);

      expect(added, isTrue);
      expect(harness.read(libraryFoldersControllerProvider), [
        '/music',
        '/downloads',
      ]);
    },
  );
}
