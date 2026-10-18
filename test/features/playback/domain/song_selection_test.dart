import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/playback/domain/song_selection.dart';

/// Which songs the owner has picked in a list, and where Shift-click starts.
void main() {
  const songs = 'songs';
  const album = 'album';
  const order = ['a', 'b', 'c', 'd', 'e', 'f'];

  group('toggle', () {
    test('GivenNothing_WhenASongIsToggled_ThenItIsSelectedInThatScopeAndIsTheAnchor', () {
      final selection = SongSelection.none.toggle(songs, 'b');

      expect(selection.paths, {'b'});
      expect(selection.scope, songs);
      expect(selection.anchor, 'b');
      expect(selection.isActive, isTrue);
      expect(selection.isActiveIn(songs), isTrue);
      expect(selection.isActiveIn(album), isFalse);
    });

    test('GivenASelectedSong_WhenToggledAgain_ThenTheSelectionEnds', () {
      final selection = SongSelection.none
          .toggle(songs, 'b')
          .toggle(songs, 'b');

      expect(selection, SongSelection.none);
      expect(selection.isActive, isFalse);
    });

    test(
      'GivenTwoSelectedSongs_WhenOneIsToggledOff_ThenItIsTheAnchorStill',
      () {
        final selection = SongSelection.none
            .toggle(songs, 'a')
            .toggle(songs, 'b')
            .toggle(songs, 'a');

        expect(selection.paths, {'b'});
        expect(selection.anchor, 'a');
      },
    );

    test('GivenASelectionInSongs_WhenASongIsToggledInAnAlbum_ThenOnlyThatSongIsSelectedInTheAlbum', () {
      final selection = SongSelection.none
          .toggle(songs, 'a')
          .toggle(songs, 'b')
          .toggle(album, 'c');

      expect(selection.paths, {'c'});
      expect(selection.scope, album);
      expect(selection.anchor, 'c');
    });
  });

  group('rangeTo', () {
    test('GivenAnAnchorAtB_WhenRangeToE_ThenBThroughEAreAdded', () {
      final selection = SongSelection.none
          .toggle(songs, 'a')
          .toggle(songs, 'b')
          .rangeTo(songs, 'e', order);

      expect(selection.paths, {'a', 'b', 'c', 'd', 'e'});
      expect(selection.anchor, 'e');
    });

    test('GivenAnAnchorAtD_WhenRangeToAFromD_ThenAThroughDAreAdded', () {
      final selection = SongSelection.none
          .toggle(songs, 'd')
          .rangeTo(songs, 'a', order);

      expect(selection.paths, {'a', 'b', 'c', 'd'});
    });

    test('GivenNoAnchor_WhenRangeTo_ThenItActsAsAToggle', () {
      final selection = SongSelection.none.rangeTo(songs, 'c', order);

      expect(selection.paths, {'c'});
      expect(selection.anchor, 'c');
    });

    test('GivenAnAnchorAbsentFromTheOrder_WhenRangeTo_ThenItActsAsAToggle', () {
      final selection = SongSelection.none
          .toggle(songs, 'gone')
          .rangeTo(songs, 'c', order);

      expect(selection.paths, {'gone', 'c'});
      expect(selection.anchor, 'c');
    });

    test(
      'GivenASelectionInAnotherScope_WhenRangeTo_ThenItStartsFreshInThisOne',
      () {
        final selection = SongSelection.none
            .toggle(album, 'a')
            .rangeTo(songs, 'c', order);

        expect(selection.paths, {'c'});
        expect(selection.scope, songs);
      },
    );
  });

  group('selectAll', () {
    test(
      'GivenSomeSelected_WhenSelectAll_ThenEverySongInTheOrderIsSelected',
      () {
        final selection = SongSelection.none
            .toggle(songs, 'b')
            .selectAll(songs, order);

        expect(selection.paths, order.toSet());
        expect(selection.scope, songs);
      },
    );
  });

  group('retainIn', () {
    test('GivenSelectedSongsOneOfWhichVanished_WhenRetained_ThenOnlyTheVanishedOneDrops', () {
      final selection = SongSelection.none
          .toggle(songs, 'a')
          .toggle(songs, 'b')
          .toggle(songs, 'c')
          .retainIn(songs, ['a', 'c', 'd']);

      expect(selection.paths, {'a', 'c'});
      expect(selection.anchor, 'c');
    });

    test('GivenTheAnchorVanished_WhenRetained_ThenThereIsNoAnchor', () {
      final selection = SongSelection.none
          .toggle(songs, 'a')
          .toggle(songs, 'b')
          .retainIn(songs, ['a', 'c']);

      expect(selection.paths, {'a'});
      expect(selection.anchor, isNull);
    });

    test(
      'GivenEverySelectedSongVanished_WhenRetained_ThenTheSelectionEnds',
      () {
        final selection = SongSelection.none
            .toggle(songs, 'a')
            .toggle(songs, 'b')
            .retainIn(songs, ['x', 'y']);

        expect(selection, SongSelection.none);
      },
    );

    test('GivenASelectionInAnotherScope_WhenRetainedInThisOne_ThenTheSelectionEnds', () {
      final selection = SongSelection.none
          .toggle(album, 'a')
          .retainIn(songs, order);

      expect(selection, SongSelection.none);
    });
  });
}
