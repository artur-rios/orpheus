import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/core/di/providers.dart';
import 'package:orpheus/features/library/domain/music_entry.dart';
import 'package:orpheus/features/library/domain/music_grouping.dart';
import 'package:orpheus/features/playback/application/music_browse_controller.dart';
import 'package:orpheus/features/playback/application/music_navigator.dart';
import 'package:orpheus/features/playback/presentation/music_browser.dart';
import 'package:orpheus/features/playback/presentation/music_scope.dart';

import '../../../support/entries.dart';
import '../../../support/pump.dart';
import '../../../support/test_container.dart';

/// The music browser away from the Music tab: drawn from a part of the
/// library, steered by a navigator of its own, and playing only what it shows.
void main() {
  final library = albumArtistsAcross([
    entry(
      id: '1',
      title: 'Airbag',
      artist: 'Radiohead',
      album: 'OK Computer',
      genres: ['Rock'],
      track: 1,
    ),
    entry(
      id: '2',
      title: 'Karma Police',
      artist: 'Radiohead',
      album: 'OK Computer',
      genres: ['Rock'],
      track: 2,
    ),
    entry(
      id: '3',
      title: 'Everything',
      artist: 'Radiohead',
      album: 'Kid A',
      genres: ['Electronic'],
      track: 1,
    ),
  ]);
  final rock = [
    for (final e in library)
      if (e.album == 'OK Computer') e,
  ];

  /// Puts a browser over [rock] on screen, inside a scope of its own.
  Future<RecordingNavigator> pumpBrowser(
    WidgetTester tester,
    Harness harness, {
    MusicBrowseState state = const MusicBrowseState(),
    List<MusicCrumb> leadingCrumbs = const [],
    List<MusicEntry>? fallbackLibrary,
    VoidCallback? onShuffle,
  }) async {
    final navigator = RecordingNavigator();

    await tester.pumpHarness(
      harness,
      Scaffold(
        body: MusicScope(
          navigator: navigator,
          within: rock,
          child: MusicBrowser(
            state: state,
            library: rock,
            songs: songsIn(rock),
            navigator: navigator,
            rootLabel: 'Rock',
            leadingCrumbs: leadingCrumbs,
            fallbackLibrary: fallbackLibrary,
            onShuffle: onShuffle ?? () {},
            shuffleTooltip: 'Shuffle the genre',
          ),
        ),
      ),
    );

    return navigator;
  }

  testWidgets(
    'GivenABrowserInAScope_WhenAnArtistRowIsTapped_ThenTheScopesNavigatorIsTold',
    (tester) async {
      final harness = Harness(library: library);
      final navigator = await pumpBrowser(tester, harness);

      await tester.tap(find.text('Radiohead'));
      await tester.pumpAndSettle();

      expect(navigator.calls, ['openArtist Radiohead']);
      // The Music tab's own place is not where this drill went.
      expect(harness.read(musicBrowseControllerProvider).inArtist, isFalse);
    },
  );

  testWidgets(
    'GivenABrowserInAScope_WhenAnArtistsPlayIsPressed_ThenOnlyTheScopesTracksAreQueued',
    (tester) async {
      final harness = Harness(library: library);
      await pumpBrowser(tester, harness);

      await tester.tap(
        find.descendant(
          of: find.widgetWithText(ListTile, 'Radiohead'),
          matching: find.byIcon(Icons.play_arrow),
        ),
      );
      await tester.pumpAndSettle();

      final queued = harness.read(audioPlaybackControllerProvider).queue.tracks;
      expect(
        [for (final track in queued) track.path],
        [for (final e in rock) e.file.path],
      );
    },
  );

  testWidgets(
    'GivenABrowserInAScope_WhenAnotherViewIsChosen_ThenItsNavigatorIsTold',
    (tester) async {
      final harness = Harness(library: library);
      final navigator = await pumpBrowser(tester, harness);

      await tester.tap(find.text('Songs'));
      await tester.pumpAndSettle();

      expect(navigator.calls, ['show songs']);
    },
  );

  testWidgets(
    'GivenABrowser_WhenItsShuffleIsPressed_ThenTheShuffleItWasGivenRuns',
    (tester) async {
      final harness = Harness(library: library);
      var shuffles = 0;
      await pumpBrowser(tester, harness, onShuffle: () => shuffles++);

      await tester.tap(find.byTooltip('Shuffle the genre'));
      await tester.pumpAndSettle();

      expect(shuffles, 1);
    },
  );

  testWidgets(
    'GivenLeadingCrumbs_WhenTheBrowserIsAtItsTop_ThenTheBreadcrumbShowsThem',
    (tester) async {
      final harness = Harness(library: library);
      var backToGenres = 0;
      await pumpBrowser(
        tester,
        harness,
        leadingCrumbs: [(label: 'Genres', onTap: () => backToGenres++)],
      );

      expect(find.widgetWithText(TextButton, 'Genres'), findsOneWidget);
      // Where the owner already is, so text rather than a control.
      expect(find.text('Rock'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Rock'), findsNothing);

      await tester.tap(find.widgetWithText(TextButton, 'Genres'));
      await tester.pumpAndSettle();

      expect(backToGenres, 1);
    },
  );

  testWidgets(
    'GivenAnOpenRecordMissingFromTheLibrary_WhenDrawn_ThenItIsDrawnFromTheFallback',
    (tester) async {
      // A record that left the genre while it was open stays on screen whole,
      // rather than turning into an empty list under its own name.
      final harness = Harness(library: library);

      await pumpBrowser(
        tester,
        harness,
        state: const MusicBrowseState(
          artist: 'Radiohead',
          album: 'Kid A',
          inArtist: true,
          inAlbum: true,
        ),
        fallbackLibrary: library,
      );

      expect(find.text('Everything'), findsOneWidget);
    },
  );

  test(
    'GivenEachKindOfBrowseState_WhenAskedWhetherSongsShow_ThenOnlyTheSongsListSaysSo',
    () {
      // What decides whether a caller sorts its songs at all: the Songs list
      // and nothing else, an open record included.
      expect(
        MusicBrowser.showsSongs(const MusicBrowseState(view: MusicView.songs)),
        isTrue,
      );
      expect(
        MusicBrowser.showsSongs(
          const MusicBrowseState(
            view: MusicView.songs,
            album: 'OK Computer',
            artist: 'Radiohead',
            inAlbum: true,
          ),
        ),
        isFalse,
      );
      for (final view in [MusicView.artists, MusicView.albums]) {
        expect(MusicBrowser.showsSongs(MusicBrowseState(view: view)), isFalse);
      }
    },
  );
}

/// A navigator that only writes down what it was asked to do.
class RecordingNavigator implements MusicNavigator {
  /// Every call, in order, as `method argument`.
  final List<String> calls = [];

  @override
  void show(MusicView view) => calls.add('show ${view.name}');

  @override
  void openArtist(String? artist) => calls.add('openArtist $artist');

  @override
  void openAlbum(String? album, String? artist) =>
      calls.add('openAlbum $album $artist');

  @override
  void upToArtists() => calls.add('upToArtists');

  @override
  void upToArtist() => calls.add('upToArtist');
}
