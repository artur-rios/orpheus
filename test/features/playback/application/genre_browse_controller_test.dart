import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/core/di/providers.dart';
import 'package:orpheus/features/library/domain/music_catalog.dart';
import 'package:orpheus/features/library/domain/music_entry.dart';
import 'package:orpheus/features/library/domain/music_grouping.dart';
import 'package:orpheus/features/playback/application/genre_browse_controller.dart';
import 'package:orpheus/features/playback/application/music_browse_controller.dart';

import '../../../support/entries.dart';
import '../../../support/test_container.dart';

/// Where the owner is inside Genres, apart from where they are in Music.
void main() {
  GenreBrowseController controllerOf(Harness harness) =>
      harness.read(genreBrowseControllerProvider.notifier);

  GenreBrowseState stateOf(Harness harness) =>
      harness.read(genreBrowseControllerProvider);

  group('a library with two rock artists and a pop one', () {
    final library = [
      entry(
        id: 'r1',
        title: 'Roar',
        artist: 'Band',
        album: 'Loud',
        genres: ['Rock'],
        track: 1,
      ),
      entry(
        id: 'r2',
        title: 'Riff',
        artist: 'Band',
        album: 'Loud',
        genres: ['Rock'],
        track: 2,
      ),
      entry(
        id: 'r3',
        title: 'Quiet',
        artist: 'Band',
        album: 'Soft',
        genres: ['Rock'],
      ),
      entry(
        id: 'r4',
        title: 'Solo',
        artist: 'Soloist',
        album: 'Alone',
        genres: ['Rock'],
      ),
      entry(
        id: 'p1',
        title: 'Hook',
        artist: 'Singer',
        album: 'Catchy',
        genres: ['Pop'],
      ),
    ];

    /// [entries] as a re-scan hands them over, derived as a scan derives them.
    MusicCatalog scanned(List<MusicEntry> entries) =>
        MusicCatalog(entries: albumArtistsAcross(entries));

    /// [library] with the genres of the tracks [ids] name replaced by [genres].
    List<MusicEntry> retagged(Set<String> ids, List<String> genres) => [
      for (final e in library)
        ids.any((id) => e.file.path.endsWith('zzz-$id.flac'))
            ? MusicEntry(
                file: e.file,
                metadata: e.metadata.copyWith(genres: genres),
              )
            : e,
    ];

    Future<Harness> harnessOpenOnLoud() async {
      final harness = Harness(library: library);
      await harness.library();
      controllerOf(harness)
        ..openGenre('rock')
        ..openArtist('Band')
        ..openAlbum('Loud', 'Band');

      return harness;
    }

    void rescan(Harness harness, List<MusicEntry> entries) => harness
        .read(musicLibraryControllerProvider.notifier)
        .replaceWith(scanned(entries));

    test('GivenTheGenresTab_WhenItIsFirstShown_ThenTheListIsShown', () {
      final state = stateOf(Harness(library: library));

      expect(state.inGenre, isFalse);
      expect(state.genre, isNull);
      expect(state.music.view, MusicView.artists);
    });

    test('GivenAGenreIsOpen_WhenTheMusicTabDrillsIntoAnArtist_ThenTheGenresPlaceIsUntouched', () {
      // The two tabs browse the same views but keep separate places: a drill
      // under Rock must not move the Music tab, nor the other way round.
      final harness = Harness(library: library);
      controllerOf(harness).openGenre('rock');

      harness.read(musicBrowseControllerProvider.notifier).openArtist('Band');

      expect(stateOf(harness).inGenre, isTrue);
      expect(stateOf(harness).music.inArtist, isFalse);
      expect(harness.read(musicBrowseControllerProvider).inArtist, isTrue);
    });

    test('GivenNoGenreIsOpened_WhenStateIsRead_ThenItIsOpenRatherThanNothingSelected', () {
      // The tracks that carry no genre are a real group an owner can open,
      // and a state that could not tell it from "nothing selected" would make
      // it unreachable.
      final harness = Harness(library: library);

      controllerOf(harness).openGenre(null);

      expect(stateOf(harness).genre, isNull);
      expect(stateOf(harness).inGenre, isTrue);
    });

    test('GivenAGenreWasLeftDeepInARecord_WhenAnotherIsOpened_ThenItOpensAtTheTopOfArtists', () {
      final harness = Harness(library: library);
      controllerOf(harness)
        ..openGenre('rock')
        ..show(MusicView.albums)
        ..openAlbum('Loud', 'Band')
        ..closeGenre();

      controllerOf(harness).openGenre('pop');

      expect(stateOf(harness).genre, 'pop');
      expect(stateOf(harness).music.view, MusicView.artists);
      expect(stateOf(harness).music.inAlbum, isFalse);
    });

    test('GivenARecordInsideAGenre_WhenBackIsPressedThreeTimes_ThenTheListIsShownAndTheFourthBackIsNotTaken', () async {
      final harness = Harness(library: library);
      await harness.library();
      controllerOf(harness)
        ..openGenre('rock')
        ..openArtist('Band')
        ..openAlbum('Loud', 'Band');

      expect(controllerOf(harness).back(), isTrue);
      expect(stateOf(harness).music.inAlbum, isFalse);
      expect(stateOf(harness).music.artist, 'Band');

      expect(controllerOf(harness).back(), isTrue);
      expect(stateOf(harness).music.inArtist, isFalse);
      expect(stateOf(harness).inGenre, isTrue);

      expect(controllerOf(harness).back(), isTrue);
      expect(stateOf(harness).inGenre, isFalse);

      expect(controllerOf(harness).back(), isFalse);
    });

    test(
      'GivenAnOpenGenre_WhenARescanRemovesEveryTrackOfIt_ThenTheListIsShown',
      () async {
        final harness = await harnessOpenOnLoud();

        rescan(harness, [library.last]);

        expect(stateOf(harness).inGenre, isFalse);
        expect(stateOf(harness).music.inAlbum, isFalse);
      },
    );

    test('GivenAnOpenRecord_WhenAnEditTakesItsLastRockTagOff_ThenTheOwnerStaysOnTheRecord', () async {
      // The record is still in the library, and being thrown out of it the
      // moment its tag changed would be a jump nobody asked for.
      final harness = await harnessOpenOnLoud();

      rescan(harness, retagged({'r1', 'r2'}, ['Pop']));

      expect(stateOf(harness).inGenre, isTrue);
      expect(stateOf(harness).music.inAlbum, isTrue);
      expect(stateOf(harness).music.album, 'Loud');
    });

    test('GivenTheOwnerStayedOnARecordThatLeftTheGenre_WhenTheyGoUp_ThenTheyLandWhereTheGenreStillHasSomething', () async {
      final harness = await harnessOpenOnLoud();
      rescan(harness, retagged({'r1', 'r2'}, ['Pop']));

      controllerOf(harness).upToArtist();

      // Band's other record is still rock, so its records are what is left.
      expect(stateOf(harness).inGenre, isTrue);
      expect(stateOf(harness).music.inAlbum, isFalse);
      expect(stateOf(harness).music.inArtist, isTrue);
      expect(stateOf(harness).music.artist, 'Band');
    });

    test('GivenTheOwnerStayedOnARecordThatLeftTheGenre_WhenItsArtistHasNothingElseThere_ThenTheyLandOnTheGenresTop', () async {
      final harness = Harness(library: library);
      await harness.library();
      controllerOf(harness)
        ..openGenre('rock')
        ..openArtist('Soloist')
        ..openAlbum('Alone', 'Soloist');
      rescan(harness, retagged({'r4'}, ['Pop']));

      controllerOf(harness).upToArtist();

      expect(stateOf(harness).inGenre, isTrue);
      expect(stateOf(harness).music.inArtist, isFalse);
      expect(stateOf(harness).music.inAlbum, isFalse);
    });

    test('GivenAnArtistInAGenreThatIsGone_WhenTheOwnerGoesUpToArtists_ThenTheListIsShown', () async {
      // Nothing of the genre is left to land on, so the list is the nearest
      // place that still has something in it. The library is asked at the
      // moment of going up, whatever the owner was shown before.
      final harness = Harness(library: [library.last]);
      await harness.library();
      controllerOf(harness)
        ..openGenre('rock')
        ..openArtist('Band')
        ..upToArtists();

      expect(stateOf(harness).inGenre, isFalse);
    });

    test('GivenAnOpenRecordRenamedByARetag_WhenTheLibraryIsRescanned_ThenItIsFollowedInsideTheGenre', () async {
      final harness = await harnessOpenOnLoud();

      rescan(harness, [
        for (final e in library)
          e.album == 'Loud'
              ? MusicEntry(
                  file: e.file,
                  metadata: e.metadata.copyWith(album: 'Louder'),
                )
              : e,
      ]);

      expect(stateOf(harness).inGenre, isTrue);
      expect(stateOf(harness).music.album, 'Louder');
      expect(stateOf(harness).music.artist, 'Band');
      expect(stateOf(harness).music.inAlbum, isTrue);
    });

    test('GivenAnArtistOpenInAGenre_WhenARescanLeavesTheirRecordsAsTheyWere_ThenTheStateIsTheSameObject', () async {
      final harness = Harness(library: library);
      await harness.library();
      controllerOf(harness)
        ..openGenre('rock')
        ..openArtist('Band');
      final before = stateOf(harness);

      rescan(harness, library);

      expect(identical(stateOf(harness), before), isTrue);
    });
  });
}
