import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/stats/domain/music_stats.dart';
import 'package:orpheus/features/stats/domain/stats_story.dart';
import 'package:orpheus/features/stats/domain/story_share.dart';
import 'package:orpheus/features/stats/presentation/stats_story_screen.dart';
import 'package:orpheus/features/stats/presentation/story_card_view.dart';

import '../../../support/fake_story_share.dart';
import '../../../support/pump.dart';
import '../../../support/test_container.dart';

/// The story on screen: what it shows, how it moves, and what leaves it.
void main() {
  final story = storyFrom(
    const MusicStats(
      totalPlays: 42,
      distinctTracks: 9,
      tracks: [RankedPlays(name: 'Airbag', plays: 5)],
      artists: [
        RankedPlays(name: 'Radiohead', plays: 12),
        RankedPlays(name: 'Miles Davis', plays: 6),
      ],
      albums: [RankedPlays(name: 'OK Computer', plays: 8)],
      genres: [],
      untaggedTracks: 0,
    ),
  );

  testWidgets(
    'GivenAStory_WhenItOpens_ThenItStartsOnTheTotalsAndMovesForwardOnATapOnTheRight',
    (tester) async {
      final harness = Harness();

      await tester.pumpHarness(harness, StatsStoryScreen(cards: story));

      expect(find.text('Your listening, so far'), findsOneWidget);
      expect(find.text('42 plays'), findsOneWidget);

      // The right half is forward. Tapped inside the card, which on this
      // window is a portrait strip in the middle of it.
      final card = tester.getRect(find.byType(StoryCardView));
      await tester.tapAt(Offset(card.right - 20, card.center.dy));
      await tester.pumpAndSettle();

      expect(find.text('Your listening, so far'), findsNothing);
      expect(find.text('Your top artist'), findsOneWidget);
      expect(find.text('Radiohead'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenTheSecondCard_WhenTheLeftHalfIsTapped_ThenItGoesBack',
    (tester) async {
      final harness = Harness();

      await tester.pumpHarness(harness, StatsStoryScreen(cards: story));

      final card = tester.getRect(find.byType(StoryCardView));
      await tester.tapAt(Offset(card.right - 20, card.center.dy));
      await tester.pumpAndSettle();
      await tester.tapAt(Offset(card.left + 20, card.center.dy));
      await tester.pumpAndSettle();

      expect(find.text('Your listening, so far'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenTheLastCard_WhenItIsTappedForward_ThenTheStoryCloses',
    (tester) async {
      final harness = Harness();

      await tester.pumpHarness(
        harness,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => StatsStoryScreen.show(context, story),
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final card = tester.getRect(find.byType(StoryCardView));
      for (var tap = 0; tap < story.length; tap++) {
        await tester.tapAt(Offset(card.right - 20, card.center.dy));
        await tester.pumpAndSettle();
      }

      expect(find.byType(StoryCardView), findsNothing);
      expect(find.text('open'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenADesktopHost_WhenTheStoryIsShown_ThenTheButtonSavesRatherThanShares',
    (tester) async {
      final harness = Harness(
        storyShare: RecordingStoryShare(sharesToApps: false),
      );

      await tester.pumpHarness(harness, StatsStoryScreen(cards: story));

      expect(find.text('Save the picture'), findsOneWidget);
      expect(find.text('Share'), findsNothing);
    },
  );

  testWidgets(
    'GivenAMobileHost_WhenTheStoryIsShown_ThenTheButtonSharesRatherThanSaves',
    (tester) async {
      final harness = Harness(
        storyShare: RecordingStoryShare(sharesToApps: true),
      );

      await tester.pumpHarness(
        harness,
        StatsStoryScreen(cards: story),
        window: phoneWindow,
      );

      expect(find.text('Share'), findsOneWidget);
      expect(find.text('Save the picture'), findsNothing);
    },
  );

  testWidgets(
    'GivenTheOwnerSendsACard_WhenItIsRendered_ThenAPngOfTheCardIsHandedOn',
    (tester) async {
      final harness = Harness(
        storyShare: RecordingStoryShare(outcome: StoryShareOutcome.saved),
      );

      await tester.pumpHarness(harness, StatsStoryScreen(cards: story));

      await sendAndSettle(tester, harness);

      expect(harness.storyShare.sent, hasLength(1));
      expect(harness.storyShare.names.single, endsWith('.png'));
      // A real picture rather than an empty buffer: the PNG signature.
      expect(
        harness.storyShare.sent.single.take(8),
        [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A],
      );
      expect(find.text('Saved.'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenTheOwnerClosesTheShareSheet_WhenNothingWasChosen_ThenNothingIsAnnounced',
    (tester) async {
      // They closed it. They know.
      final harness = Harness(
        storyShare: RecordingStoryShare(outcome: StoryShareOutcome.cancelled),
      );

      await tester.pumpHarness(harness, StatsStoryScreen(cards: story));

      await sendAndSettle(tester, harness);

      expect(harness.storyShare.sent, hasLength(1));
      expect(find.byType(SnackBar), findsNothing);
    },
  );

  testWidgets(
    'GivenTheCardIsShownInsideTheApplication_WhenItIsDrawn_ThenTheControlsAreOutsideThePicture',
    (tester) async {
      // The progress bar, the close button and the send button drive the
      // story. Nobody wants them in the picture they post, so they sit outside
      // the boundary the picture is taken from.
      final harness = Harness();

      await tester.pumpHarness(harness, StatsStoryScreen(cards: story));

      final boundary = find.ancestor(
        of: find.byType(StoryCardView),
        matching: find.byType(RepaintBoundary),
      );
      expect(
        find.descendant(of: boundary.first, matching: find.byType(FilledButton)),
        findsNothing,
      );
      expect(
        find.descendant(of: boundary.first, matching: find.byType(IconButton)),
        findsNothing,
      );
    },
  );
}

/// Presses the send button and waits for the picture to actually be made.
///
/// `runAsync`, because rendering a boundary to an image is real work on the
/// engine and does not progress under the fake clock a widget test runs on.
/// Polled rather than delayed by a fixed amount: a three-times-scale PNG of a
/// full card is around a megabyte, and how long that takes is the machine's
/// business, not the test's.
Future<void> sendAndSettle(WidgetTester tester, Harness harness) async {
  await tester.runAsync(() async {
    await tester.tap(find.text('Save the picture'));

    for (var waited = 0; waited < 100; waited++) {
      await tester.pump();
      if (harness.storyShare.sent.isNotEmpty) break;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  });
  // The spinner is gone by now, so the snack bar's own animation can settle.
  await tester.pumpAndSettle();
}
