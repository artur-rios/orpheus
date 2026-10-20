import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/core/di/providers.dart';
import 'package:orpheus/features/autofill/application/batch_autofill_controller.dart';
import 'package:orpheus/features/autofill/domain/autofill_field.dart';
import 'package:orpheus/features/autofill/domain/batch_plan.dart';
import 'package:orpheus/features/autofill/domain/metadata_source.dart';
import 'package:orpheus/features/autofill/domain/tag_writer.dart';
import 'package:orpheus/features/autofill/presentation/autofill_screen.dart';
import 'package:orpheus/features/autofill/presentation/batch_autofill_screen.dart';
import 'package:orpheus/features/library/domain/library_access.dart';
import 'package:orpheus/features/library/domain/music_entry.dart';

import '../../../support/batch_autofill_fixtures.dart';
import '../../../support/fakes.dart';
import '../../../support/pump.dart';
import '../../../support/test_container.dart';

/// The batch screen: progress while it runs, the summary once it is done, and
/// the way into the records kept for the owner.
void main() {
  const artistOnly = {AutofillField.artist};

  /// Tall enough that the whole summary is built.
  const tall = Size(1000, 2400);

  Future<void> show(
    WidgetTester tester,
    Harness harness, {
    Size window = tall,
  }) =>
      tester.pumpHarness(harness, const BatchAutofillScreen(), window: window);

  BatchAutofillController controllerOf(Harness harness) =>
      harness.read(batchAutofillControllerProvider.notifier);

  BatchAutofillState stateOf(Harness harness) =>
      harness.read(batchAutofillControllerProvider);

  /// Runs [library] as a batch to its end.
  Future<void> finish(
    Harness harness,
    List<MusicEntry> library, {
    Set<AutofillField> fields = artistOnly,
  }) async {
    final controller = controllerOf(harness);
    await controller.start(planBatch(library, library), fields);
    await controller.settled;
  }

  /// A finished batch with one record of each kind: written (Alpha), kept for
  /// the owner (Beta), refused as in use (Delta), found nothing for (Gamma),
  /// and a song of a kind that cannot be written.
  Future<(Harness, List<MusicEntry>)> aFinishedBatch(
    WidgetTester tester,
  ) async {
    final library = [
      ...albumOf('Alpha'),
      ...albumOf('Beta'),
      ...albumOf('Delta'),
      ...albumOf('Gamma'),
      oggSong('Loose'),
    ];
    final harness = batchHarness(
      library,
      releases: {
        'Alpha': releaseOf('Alpha'),
        'Beta': releaseOf('Beta', status: 'Bootleg'),
        'Delta': releaseOf('Delta'),
      },
    );
    for (final song in albumOf('Delta')) {
      harness.tagWriter.refusals[song.file.path] = WriteOutcome.inUse;
    }
    await finish(harness, library);

    return (harness, library);
  }

  testWidgets('GivenARun_WhenShown_ThenProgressAndCounts', (tester) async {
    // Gamma has no tags to read, so it is done at once; Alpha waits on
    // MusicBrainz.
    final library = [...albumOf('Alpha'), ...albumOf('Gamma')];
    final harness = batchHarness(library);
    for (final song in albumOf('Alpha')) {
      harness.tagWriter.files.remove(song.file.path);
    }
    final gate = Completer<void>();
    harness.metadata.hold = gate.future;
    addTearDown(() => gate.isCompleted ? null : gate.complete());
    await controllerOf(harness).start(planBatch(library, library), artistOnly);

    await show(tester, harness);

    expect(find.text('Looking up 1 of 2 records'), findsOneWidget);
    expect(find.text('0 updated'), findsOneWidget);
    expect(find.text('0 need you'), findsOneWidget);
    expect(find.text('0 already right'), findsOneWidget);
    expect(find.text('0 not found'), findsOneWidget);
    expect(find.text('2 skipped'), findsOneWidget);
    expect(find.text('Stop'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    gate.complete();
    await controllerOf(harness).settled;
  });

  testWidgets('GivenStopTapped_WhenRunning_ThenTheControllerStops', (
    tester,
  ) async {
    final library = [...albumOf('Alpha'), ...albumOf('Beta')];
    final harness = batchHarness(library);
    final gate = Completer<void>();
    harness.metadata.hold = gate.future;
    addTearDown(() => gate.isCompleted ? null : gate.complete());
    await controllerOf(harness).start(planBatch(library, library), artistOnly);
    await show(tester, harness);

    await tester.tap(find.text('Stop'));
    gate.complete();
    await controllerOf(harness).settled;
    await tester.pumpAndSettle();

    final state = stateOf(harness);
    expect(state.stage, BatchStage.finished);
    expect(state.stoppedEarly, isTrue);
    expect(state.outcomes.map((o) => o.kind), [
      UnitOutcomeKind.updated,
      UnitOutcomeKind.notLookedUp,
    ]);
    expect(find.text('Not looked up'), findsOneWidget);
  });

  testWidgets('GivenPaused_WhenTryAgainTapped_ThenItResumes', (tester) async {
    final library = [
      ...albumOf('Alpha'),
      ...albumOf('Beta'),
      ...albumOf('Gamma'),
    ];
    final harness = batchHarness(library);
    harness.metadata.failure = MetadataSourceFailure.unreachable;
    await finish(harness, library);
    expect(stateOf(harness).stage, BatchStage.paused);

    await show(tester, harness);

    expect(
      find.text('MusicBrainz could not be reached. The autofill is paused.'),
      findsOneWidget,
    );
    expect(find.text('Stop'), findsOneWidget);

    harness.metadata.failure = null;
    await tester.tap(find.text('Try again'));
    await controllerOf(harness).settled;
    await tester.pumpAndSettle();

    expect(stateOf(harness).stage, BatchStage.finished);
    expect(stateOf(harness).updated, 3);
    expect(find.textContaining('is paused'), findsNothing);
  });

  testWidgets('GivenFinished_WhenShown_ThenSummaryAndSectionsWithReasons', (
    tester,
  ) async {
    final (harness, _) = await aFinishedBatch(tester);

    await show(tester, harness);

    expect(find.text('1 record updated, 1 needs you'), findsOneWidget);
    expect(find.text('1 updated'), findsOneWidget);
    expect(find.text('1 needs you'), findsOneWidget);
    expect(find.text('1 not found'), findsOneWidget);
    // Delta's two songs and the ogg, and Delta's own failure.
    expect(find.text('Need you'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Beta'), findsOneWidget);
    expect(find.text('Not an official release'), findsOneWidget);
    expect(find.text('Not found'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Gamma'), findsOneWidget);
    expect(find.text("Can't be changed"), findsOneWidget);
    expect(find.text('Loose.ogg'), findsOneWidget);
    expect(find.text("Orpheus can't change this kind of file"), findsOneWidget);
    expect(find.text('Could not be written or looked up'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Delta'), findsOneWidget);
    expect(find.text('zzz-Delta-1.flac'), findsOneWidget);
    expect(
      find.text('In use by playback — try again once it has moved on'),
      findsNWidgets(2),
    );
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Clear list'), findsOneWidget);
    expect(find.text('Not looked up'), findsNothing);
  });

  testWidgets('GivenAPhone_WhenAFinishedBatchIsShown_ThenNothingOverflows', (
    tester,
  ) async {
    final (harness, _) = await aFinishedBatch(tester);

    await show(tester, harness, window: phoneWindow);
    await tester.scrollUntilVisible(
      find.text('Could not be written or looked up'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'GivenThousandsOfSongsThatCantBeChanged_WhenSummarised_ThenOnlyTheRowsInViewAreBuilt',
    (tester) async {
      final loose = [for (var i = 0; i < 3000; i++) oggSong('Loose$i')];
      final library = [...albumOf('Alpha'), ...loose];
      final harness = batchHarness(library);
      await finish(harness, library);
      expect(stateOf(harness).notWritableSongs, hasLength(3000));

      await show(tester, harness, window: phoneWindow);

      expect(find.text("Can't be changed"), findsOneWidget);
      expect(find.text('Loose0.ogg'), findsOneWidget);
      expect(find.text('Loose2999.ogg', skipOffstage: false), findsNothing);
      expect(
        find.byType(ListTile, skipOffstage: false).evaluate().length,
        lessThan(100),
      );

      await tester.scrollUntilVisible(
        find.text('Loose2999.ogg'),
        20000,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('Loose2999.ogg'), findsOneWidget);
      expect(find.text('Loose0.ogg', skipOffstage: false), findsNothing);
    },
  );

  testWidgets('GivenAFinishedBatch_WhenShown_ThenItIsMarkedSeen', (
    tester,
  ) async {
    final (harness, _) = await aFinishedBatch(tester);
    expect(stateOf(harness).seen, isFalse);

    await show(tester, harness);

    expect(stateOf(harness).seen, isTrue);
  });

  testWidgets('GivenABatchEndingWhileShown_WhenItEnds_ThenItIsMarkedSeen', (
    tester,
  ) async {
    final library = [...albumOf('Alpha'), ...albumOf('Beta')];
    final harness = batchHarness(library);
    final gate = Completer<void>();
    harness.metadata.hold = gate.future;
    addTearDown(() => gate.isCompleted ? null : gate.complete());
    await controllerOf(harness).start(planBatch(library, library), artistOnly);

    await show(tester, harness);
    expect(stateOf(harness).seen, isFalse);
    gate.complete();
    await controllerOf(harness).settled;
    await tester.pumpAndSettle();

    expect(stateOf(harness).stage, BatchStage.finished);
    expect(stateOf(harness).seen, isTrue);
  });

  testWidgets(
    'GivenACoverThatCouldNotBeDownloaded_WhenSummarised_ThenItsRowSaysSo',
    (tester) async {
      final library = albumOf('Alpha');
      final harness = batchHarness(library);
      harness.metadata.coverFailure = MetadataSourceFailure.unreachable;
      await finish(
        harness,
        library,
        fields: {AutofillField.artist, AutofillField.cover},
      );
      expect(stateOf(harness).outcomes.single.kind, UnitOutcomeKind.updated);

      await show(tester, harness);

      expect(find.widgetWithText(ListTile, 'Alpha'), findsOneWidget);
      expect(
        find.text(
          'The cover could not be downloaded from the Cover Art Archive.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'GivenADoubtfulRow_WhenTappedAndTheReviewWrites_ThenTheRowIsMarkedReviewed',
    (tester) async {
      final (harness, library) = await aFinishedBatch(tester);
      await show(tester, harness);

      await tester.tap(find.widgetWithText(ListTile, 'Beta'));
      await tester.pumpAndSettle();

      final review = tester.widget<AutofillScreen>(find.byType(AutofillScreen));
      expect(review.entries, [
        for (final song in library)
          if (song.album == 'Beta') song,
      ]);
      expect(review.fields, artistOnly);
      expect(review.matchAgainst, review.entries);

      await tester.tap(find.textContaining('Write 2 changes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      final beta = stateOf(harness).outcomes
          .singleWhere((o) => o.kind == UnitOutcomeKind.doubtful);
      expect(beta.reviewed, isTrue);
      expect(stateOf(harness).needYou, 0);
      // It stays listed, now with a check.
      expect(find.widgetWithText(ListTile, 'Beta'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    },
  );

  testWidgets(
    'GivenADoubtfulRow_WhenTappedAndTheReviewIsLeft_ThenItStillNeedsYou',
    (tester) async {
      final (harness, _) = await aFinishedBatch(tester);
      await show(tester, harness);

      await tester.tap(find.widgetWithText(ListTile, 'Beta'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(stateOf(harness).needYou, 1);
      expect(find.byIcon(Icons.check_circle_outline), findsNothing);
    },
  );

  testWidgets('GivenClearList_WhenConfirmed_ThenTheBatchIsCleared', (
    tester,
  ) async {
    final (harness, _) = await aFinishedBatch(tester);
    await show(tester, harness);

    await tester.tap(find.text('Clear list'));
    await tester.pumpAndSettle();
    expect(find.text('Clear the list?'), findsOneWidget);
    expect(stateOf(harness).stage, BatchStage.finished);
    await tester.tap(find.widgetWithText(FilledButton, 'Clear'));
    await tester.pumpAndSettle();

    expect(stateOf(harness).stage, BatchStage.idle);
    expect(stateOf(harness).outcomes, isEmpty);
  });

  testWidgets('GivenClearList_WhenCancelled_ThenTheBatchStays', (tester) async {
    final (harness, _) = await aFinishedBatch(tester);
    await show(tester, harness);

    await tester.tap(find.text('Clear list'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(stateOf(harness).stage, BatchStage.finished);
    expect(stateOf(harness).needYou, 1);
  });

  testWidgets('GivenTheRefusal_WhenShown_ThenTheAccessMessage', (tester) async {
    final library = albumOf('Alpha');
    final access = FakeLibraryAccess()
      ..writeDecision = LibraryAccessDecision.denied;
    final harness = batchHarness(library, access: access);
    expect(
      await controllerOf(harness)
          .start(planBatch(library, library), artistOnly),
      isFalse,
    );

    await show(tester, harness);

    expect(
      find.text(
        'Orpheus needs permission to change your music files. '
        'Nothing was written.',
      ),
      findsOneWidget,
    );
    expect(find.text('Open settings'), findsNothing);
  });

  testWidgets('GivenAPermanentRefusal_WhenShown_ThenSettingsAreOffered', (
    tester,
  ) async {
    final library = albumOf('Alpha');
    final access = FakeLibraryAccess()
      ..writeDecision = LibraryAccessDecision.deniedPermanently;
    final harness = batchHarness(library, access: access);
    await controllerOf(harness).start(planBatch(library, library), artistOnly);

    await show(tester, harness);
    await tester.tap(find.text('Open settings'));
    await tester.pump();

    expect(access.openedSettings, isTrue);
  });

  testWidgets(
    'GivenAnInUseFileInTheSummary_WhenTryAgainTapped_ThenRetryFailedRuns',
    (tester) async {
      final (harness, library) = await aFinishedBatch(tester);
      await show(tester, harness);
      harness.tagWriter.refusals.clear();

      await tester.tap(find.text('Try again'));
      await controllerOf(harness).settled;
      await tester.pumpAndSettle();

      final delta = stateOf(harness).outcomes
          .singleWhere((o) => o.unit.songs.first.album == 'Delta');
      expect(delta.kind, UnitOutcomeKind.updated);
      expect(
        harness.tagWriter.writes.map((w) => w.$1),
        containsAll([
          for (final song in library)
            if (song.album == 'Delta') song.file.path,
        ]),
      );
      expect(find.text('Try again'), findsNothing);
      expect(find.text('2 records updated, 1 needs you'), findsOneWidget);
    },
  );
}
