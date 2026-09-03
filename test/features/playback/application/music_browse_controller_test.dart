import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/core/di/providers.dart';
import 'package:orpheus/features/playback/application/music_browse_controller.dart';

import '../../../support/test_container.dart';

/// Drilling into the library, and finding the way back out.
void main() {
  MusicBrowseController controllerOf(Harness harness) =>
      harness.read(musicBrowseControllerProvider.notifier);

  MusicBrowseState stateOf(Harness harness) =>
      harness.read(musicBrowseControllerProvider);

  test('GivenAFreshLibrary_WhenItIsOpened_ThenTheArtistsAreShown', () {
    expect(stateOf(Harness()).view, MusicView.artists);
  });

  test(
    'GivenAnArtistIsOpen_WhenTheOwnerSwitchesToAlbums_ThenTheyLandAtTheTopOfThatView',
    () {
      // An owner switching to Albums asked for the albums list, not for
      // whatever record happened to be open in the view they left.
      final harness = Harness();
      controllerOf(harness).openArtist('Radiohead');

      controllerOf(harness).show(MusicView.albums);

      expect(stateOf(harness).inArtist, isFalse);
      expect(stateOf(harness).artist, isNull);
    },
  );

  test(
    'GivenTheUntaggedArtistGroup_WhenItIsOpened_ThenItIsOpenRatherThanNothingSelected',
    () {
      // The files that name no artist are a real group an owner can open, and
      // a state that could not tell it from "nothing selected" would make it
      // unreachable.
      final harness = Harness();

      controllerOf(harness).openArtist(null);

      expect(stateOf(harness).artist, isNull);
      expect(stateOf(harness).inArtist, isTrue);
    },
  );

  test(
    'GivenARecordOpenedThroughItsArtist_WhenTheOwnerGoesUp_ThenTheyReturnToThatArtistsRecords',
    () {
      final harness = Harness();
      controllerOf(harness)
        ..openArtist('Radiohead')
        ..openAlbum('OK Computer', 'Radiohead');

      controllerOf(harness).upToArtist();

      expect(stateOf(harness).inAlbum, isFalse);
      expect(stateOf(harness).inArtist, isTrue);
      expect(stateOf(harness).artist, 'Radiohead');
    },
  );

  test(
    'GivenARecordOpenedStraightFromTheAlbumsView_WhenTheOwnerGoesUp_ThenTheyReturnToTheAlbums',
    () {
      // There is no artist list to return to on that path — inventing one
      // would take the owner somewhere they never were.
      final harness = Harness();
      controllerOf(harness)
        ..show(MusicView.albums)
        ..openAlbum('OK Computer', 'Radiohead');

      controllerOf(harness).upToArtist();

      expect(stateOf(harness).inArtist, isFalse);
      expect(stateOf(harness).inAlbum, isFalse);
      expect(stateOf(harness).view, MusicView.albums);
    },
  );

  group('the system back gesture', () {
    test(
      'GivenARecordIsOpen_WhenBackIsPressed_ThenItStepsOutRatherThanLeavingTheApplication',
      () {
        final harness = Harness();
        controllerOf(harness)
          ..openArtist('Radiohead')
          ..openAlbum('OK Computer', 'Radiohead');

        expect(controllerOf(harness).back(), isTrue);
        expect(stateOf(harness).inAlbum, isFalse);
      },
    );

    test(
      'GivenTheOwnerIsAtTheTopOfTheLibrary_WhenBackIsPressed_ThenTheGestureIsLeftAlone',
      () {
        final harness = Harness();

        expect(controllerOf(harness).back(), isFalse);
      },
    );
  });
}
