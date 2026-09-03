import 'package:flutter_test/flutter_test.dart';
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
