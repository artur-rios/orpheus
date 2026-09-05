import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/core/di/providers.dart';
import 'package:orpheus/core/theme/app_theme.dart';
import 'package:orpheus/features/lyrics/domain/lyrics.dart';
import 'package:orpheus/features/lyrics/presentation/lyrics_view.dart';
import 'package:orpheus/features/playback/domain/media_player.dart';
import 'package:orpheus/features/playback/presentation/album_art.dart';
import 'package:orpheus/features/playback/presentation/now_playing_screen.dart';

import '../../../support/entries.dart';
import '../../../support/fakes.dart';
import '../../../support/pump.dart';
import '../../../support/test_container.dart';

/// Reading along with what is playing.
///
/// The sheets here are invented lines with times attached: what these tests
/// are about is which line is lit at a moment, and where tapping one goes.
void main() {
  final library = [
    entry(
      id: '1',
      title: 'Airbag',
      artist: 'Radiohead',
      album: 'OK Computer',
      track: 1,
    ),
  ];

  final track = library.first.file.path;

  /// A record of two tracks, for the flows that move from one to the next.
  final pair = [
    ...library,
    entry(
      id: '2',
      title: 'Karma Police',
      artist: 'Radiohead',
      album: 'OK Computer',
      track: 2,
    ),
  ];

  final sheet = Lyrics.synced(const [
    LyricLine(text: 'The opening line', at: Duration(seconds: 10)),
    LyricLine(text: 'The second line', at: Duration(seconds: 20)),
    LyricLine(text: 'The closing line', at: Duration(seconds: 30)),
  ]);

  /// The player, open, over a library with one record playing.
  Future<Harness> playing(WidgetTester tester, {Lyrics? lyrics}) async {
    final harness = Harness(
      library: library,
      lyrics: ScriptedLyricsSource(lyrics == null ? {} : {track: lyrics}),
    );
    await harness.library();
    await harness
        .read(audioPlaybackControllerProvider.notifier)
        .playAlbum(library.first.file);
    await tester.pumpHarness(harness, const NowPlayingScreen());

    return harness;
  }

  /// Puts the words on screen in place of the sleeve.
  Future<void> showLyrics(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.lyrics_outlined));
    await tester.pumpAndSettle();
  }

  /// Reports [position] as the engine would.
  Future<void> reachPosition(
    WidgetTester tester,
    Harness harness,
    Duration position,
  ) async {
    harness.player.report(
      PlaybackStatus(
        isPlaying: true,
        position: position,
        duration: const Duration(minutes: 4),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'GivenATrackWithWords_WhenTheOwnerAsksForThem_ThenTheyTakeTheSleevesPlace',
    (tester) async {
      await playing(tester, lyrics: sheet);

      expect(find.byType(RaisedAlbumArt), findsOneWidget);
      expect(find.text('The opening line'), findsNothing);

      await showLyrics(tester);

      expect(find.text('The opening line'), findsOneWidget);
      expect(find.text('The closing line'), findsOneWidget);
      expect(find.byType(RaisedAlbumArt), findsNothing);
    },
  );

  testWidgets(
    'GivenTheWordsAreShowing_WhenTheOwnerAsksForTheSleeveAgain_ThenItComesBack',
    (tester) async {
      await playing(tester, lyrics: sheet);
      await showLyrics(tester);

      await tester.tap(find.byIcon(Icons.lyrics));
      await tester.pumpAndSettle();

      expect(find.byType(RaisedAlbumArt), findsOneWidget);
      expect(find.text('The opening line'), findsNothing);
    },
  );

  testWidgets(
    'GivenTheWordsAreShowing_WhenTheTrackReachesALine_ThenThatLineIsTheOneLit',
    (tester) async {
      final harness = await playing(tester, lyrics: sheet);
      await showLyrics(tester);

      await reachPosition(tester, harness, const Duration(seconds: 25));

      final lit = tester.widget<Text>(find.text('The second line'));
      final unlit = tester.widget<Text>(find.text('The opening line'));

      expect(lit.style?.color, AppTheme.light.colorScheme.primary);
      expect(unlit.style?.color, isNot(AppTheme.light.colorScheme.primary));
    },
  );

  testWidgets(
    'GivenTheTrackHasNotReachedTheFirstLine_WhenTheWordsAreShowing_ThenNoneIsLit',
    (tester) async {
      // The intro. Nothing is being sung, and nothing pretends to be.
      final harness = await playing(tester, lyrics: sheet);
      await showLyrics(tester);

      await reachPosition(tester, harness, const Duration(seconds: 2));

      for (final line in const [
        'The opening line',
        'The second line',
        'The closing line',
      ]) {
        expect(
          tester.widget<Text>(find.text(line)).style?.color,
          isNot(AppTheme.light.colorScheme.primary),
        );
      }
    },
  );

  testWidgets(
    'GivenATimedLine_WhenTheOwnerTapsIt_ThenPlaybackMovesToWhereItIsSung',
    (tester) async {
      final harness = await playing(tester, lyrics: sheet);
      await showLyrics(tester);

      await tester.tap(find.text('The closing line'));
      await tester.pumpAndSettle();

      expect(harness.player.seeks.last, const Duration(seconds: 30));
    },
  );

  testWidgets(
    'GivenATrackThisMachineHoldsNoWordsFor_WhenTheyAreAskedFor_ThenItSaysSoAndSaysWhere',
    (tester) async {
      await playing(tester);

      await showLyrics(tester);

      expect(find.text('No lyrics for this track'), findsOneWidget);
      expect(
        find.textContaining('never fetches them from the internet'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'GivenWordsWithNoTimes_WhenTheyAreShowing_ThenTheyAreShownAndSaidNotToFollow',
    (tester) async {
      await playing(
        tester,
        lyrics: Lyrics.plain(const ['A line', 'Another line']),
      );

      await showLyrics(tester);

      expect(find.text('A line'), findsOneWidget);
      expect(
        find.text(
          'These lyrics carry no times, so they do not follow the music.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'GivenWordsWithNoTimes_WhenTheOwnerTapsALine_ThenNothingIsSeeked',
    (tester) async {
      // An untimed line is not a place in the track, so it is not a button
      // that pretends to be one.
      final harness = await playing(
        tester,
        lyrics: Lyrics.plain(const ['A line', 'Another line']),
      );
      await showLyrics(tester);

      await tester.tap(find.text('Another line'));
      await tester.pumpAndSettle();

      expect(harness.player.seeks, isEmpty);
    },
  );

  testWidgets(
    'GivenTheWordsWereShowingForOneTrack_WhenTheNextOneStarts_ThenItsOwnWordsAreShown',
    (tester) async {
      final harness = Harness(
        library: pair,
        lyrics: ScriptedLyricsSource({
          pair.first.file.path: sheet,
          pair.last.file.path: Lyrics.synced(const [
            LyricLine(text: 'The next track opens', at: Duration(seconds: 1)),
          ]),
        }),
      );
      await harness.library();
      await harness
          .read(audioPlaybackControllerProvider.notifier)
          .playAlbum(pair.first.file);
      await tester.pumpHarness(harness, const NowPlayingScreen());
      await showLyrics(tester);

      expect(find.text('The opening line'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.skip_next));
      await tester.pumpAndSettle();

      expect(find.text('The next track opens'), findsOneWidget);
      expect(find.text('The opening line'), findsNothing);
      expect(harness.lyrics.asked, [pair.first.file.path, pair.last.file.path]);
    },
  );

  /// A sheet long enough that most of it is off the panel at any moment.
  final longSheet = Lyrics.synced([
    for (var index = 0; index < 40; index++)
      LyricLine(text: 'Line $index', at: Duration(seconds: index * 5)),
  ]);

  /// How far the words themselves have been scrolled.
  double wordsScrolledTo(WidgetTester tester) => tester
      .state<ScrollableState>(
        find.descendant(
          of: find.byType(LyricsPanel),
          matching: find.byType(Scrollable),
        ),
      )
      .position
      .pixels;

  testWidgets(
    'GivenALineFarDownTheSheet_WhenTheTrackReachesIt_ThenItIsScrolledIntoSight',
    (tester) async {
      final harness = await playing(tester, lyrics: longSheet);
      await showLyrics(tester);

      await reachPosition(tester, harness, const Duration(seconds: 150));

      // On screen, rather than merely built: every line of a sheet is built,
      // and a view that never scrolled would pass an assertion that only
      // asked whether the widget existed.
      final panel = tester.getRect(find.byType(LyricsPanel));
      final line = tester.getRect(find.text('Line 30'));

      expect(line.top, greaterThanOrEqualTo(panel.top));
      expect(line.bottom, lessThanOrEqualTo(panel.bottom));
    },
  );

  testWidgets(
    'GivenReducedMotionIsAskedFor_WhenTheLineChanges_ThenTheLineIsPutThereRatherThanSlidThere',
    (tester) async {
      // The words still follow the music; it is the sliding that stops. Two
      // frames is not enough for an animation to have gone anywhere, so an
      // offset this far in is one that was jumped to.
      final harness = await playing(tester, lyrics: longSheet);
      await showLyrics(tester);

      harness.player.report(
        const PlaybackStatus(
          isPlaying: true,
          position: Duration(seconds: 150),
          duration: Duration(minutes: 4),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(wordsScrolledTo(tester), greaterThan(0));
    },
  );

  testWidgets(
    'GivenTheOwnerHasScrolledTheWordsThemselves_WhenTheLineChanges_ThenTheyAreLeftWhereTheyWere',
    (tester) async {
      // A reader who scrolls ahead to see what is coming is not dragged back
      // the moment the next line starts.
      final harness = await playing(tester, lyrics: longSheet);
      await showLyrics(tester);

      await tester.drag(find.text('Line 0'), const Offset(0, -300));
      await tester.pumpAndSettle();

      final scrolled = wordsScrolledTo(tester);
      expect(scrolled, greaterThan(0));

      await reachPosition(tester, harness, const Duration(seconds: 5));

      expect(wordsScrolledTo(tester), scrolled);
    },
  );
}
