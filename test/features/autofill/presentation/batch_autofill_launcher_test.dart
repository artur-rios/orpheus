import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/core/di/providers.dart';
import 'package:orpheus/features/autofill/application/autofill_controller.dart';
import 'package:orpheus/features/autofill/application/batch_autofill_controller.dart';
import 'package:orpheus/features/autofill/domain/autofill_field.dart';
import 'package:orpheus/features/autofill/domain/batch_plan.dart';
import 'package:orpheus/features/autofill/presentation/autofill_screen.dart';
import 'package:orpheus/features/autofill/presentation/batch_autofill_launcher.dart';
import 'package:orpheus/features/autofill/presentation/batch_autofill_screen.dart';
import 'package:orpheus/features/library/domain/library_access.dart';
import 'package:orpheus/features/library/domain/music_entry.dart';

import '../../../support/batch_autofill_fixtures.dart';
import '../../../support/fakes.dart';
import '../../../support/pump.dart';
import '../../../support/test_container.dart';

/// Starting a batch: the field dialog, the confirmation, and where it leads.
void main() {
  Future<void> open(
    WidgetTester tester,
    Harness harness,
    List<MusicEntry> entries,
  ) async {
    // The library is read where the shell would have it loaded already.
    await harness.read(musicLibraryControllerProvider.future);
    await tester.pumpHarness(
      harness,
      Scaffold(
        body: Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () =>
                unawaited(startBatchAutofill(context, ref, entries)),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  /// Answers the field dialog with the defaults, and the confirmation with
  /// [confirm].
  Future<void> answer(WidgetTester tester, {bool confirm = true}) async {
    await tester.tap(find.text('Find'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(confirm ? 'Start' : 'Cancel'));
    await tester.pumpAndSettle();
  }

  BatchAutofillState stateOf(Harness harness) =>
      harness.read(batchAutofillControllerProvider);

  testWidgets('GivenOneSong_WhenStarted_ThenTheLoneTrackReviewOpens', (
    tester,
  ) async {
    final library = albumOf('Alpha');
    final harness = batchHarness(library);

    await open(tester, harness, [library.first]);
    await tester.tap(find.text('Find'));
    await tester.pumpAndSettle();

    final screen = tester.widget<AutofillScreen>(find.byType(AutofillScreen));
    expect(screen.kind, AutofillKind.track);
    expect(screen.entries, [library.first]);
    expect(find.byType(BatchAutofillScreen), findsNothing);
  });

  testWidgets('GivenNoSong_WhenStarted_ThenNothingAsksAnything', (
    tester,
  ) async {
    final harness = batchHarness(albumOf('Alpha'));

    await open(tester, harness, const []);

    expect(find.byType(Dialog), findsNothing);
    expect(find.byType(AutofillScreen), findsNothing);
  });

  testWidgets('GivenABatch_WhenConfirmed_ThenTheRunStartsAndTheScreenOpens', (
    tester,
  ) async {
    final library = [...albumOf('Alpha'), ...albumOf('Beta')];
    final harness = batchHarness(library);

    await open(tester, harness, library);
    await answer(tester);

    expect(find.byType(BatchAutofillScreen), findsOneWidget);
    await harness.read(batchAutofillControllerProvider.notifier).settled;
    expect(stateOf(harness).plan?.units, hasLength(2));
    expect(stateOf(harness).fields, AutofillField.defaults);
    expect(harness.metadata.releaseQueries, isNotEmpty);
  });

  testWidgets(
    'GivenTheConfirmation_WhenShown_ThenItNamesSongsRecordsMinutesAndSkipped',
    (tester) async {
      final library = [
        ...albumOf('Alpha', count: 3),
        oggSong('First'),
        oggSong('Second'),
      ];
      final harness = batchHarness(library);

      await open(tester, harness, library);
      await tester.tap(find.text('Find'));
      await tester.pumpAndSettle();

      expect(find.text('Autofill 5 songs?'), findsOneWidget);
      expect(find.textContaining('1 record, about 1 minute'), findsOneWidget);
      expect(find.textContaining("2 songs can't be changed"), findsOneWidget);
      expect(find.text('Start'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenTheConfirmationCancelled_WhenStarted_ThenNothingIsLookedUp',
    (tester) async {
      final library = [...albumOf('Alpha'), ...albumOf('Beta')];
      final harness = batchHarness(library);

      await open(tester, harness, library);
      await answer(tester, confirm: false);

      expect(harness.metadata.releaseQueries, isEmpty);
      expect(stateOf(harness).stage, BatchStage.idle);
      expect(find.byType(BatchAutofillScreen), findsNothing);
    },
  );

  testWidgets(
    'GivenTheFieldsDialogCancelled_WhenStarted_ThenNothingIsAskedAfterIt',
    (tester) async {
      final library = [...albumOf('Alpha'), ...albumOf('Beta')];
      final harness = batchHarness(library);

      await open(tester, harness, library);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(stateOf(harness).stage, BatchStage.idle);
    },
  );

  testWidgets(
    'GivenARunningBatch_WhenAnotherIsStarted_ThenTheRunningOneOpens',
    (tester) async {
      final library = [...albumOf('Alpha'), ...albumOf('Beta')];
      final harness = batchHarness(library);
      final gate = Completer<void>();
      harness.metadata.hold = gate.future;
      addTearDown(() => gate.isCompleted ? null : gate.complete());
      final controller = harness.read(batchAutofillControllerProvider.notifier);
      await controller.start(planBatch(library, library), const {
        AutofillField.artist,
      });

      await open(tester, harness, library);

      expect(find.byType(BatchAutofillScreen), findsOneWidget);
      expect(find.text('Fill which tags?'), findsNothing);
      gate.complete();
      await controller.settled;
    },
  );

  testWidgets(
    'GivenAFinishedBatchWithDoubtful_WhenAnotherIsStarted_ThenItAsksAndKeepsTheOldOnNo',
    (tester) async {
      final library = [...albumOf('Alpha'), ...albumOf('Beta')];
      final harness = batchHarness(
        library,
        releases: {
          'Alpha': releaseOf('Alpha'),
          'Beta': releaseOf('Beta', status: 'Bootleg'),
        },
      );
      final controller = harness.read(batchAutofillControllerProvider.notifier);
      await controller.start(planBatch(library, library), const {
        AutofillField.artist,
      });
      await controller.settled;
      expect(stateOf(harness).needYou, 1);

      await open(tester, harness, library);

      expect(find.text('Start a new autofill?'), findsOneWidget);
      expect(
        find.text('The record waiting for you will be forgotten.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Fill which tags?'), findsNothing);
      expect(stateOf(harness).needYou, 1);
      expect(stateOf(harness).stage, BatchStage.finished);
    },
  );

  testWidgets(
    'GivenAFinishedBatchWithDoubtful_WhenReplacementIsConfirmed_ThenTheFieldsAreAsked',
    (tester) async {
      final library = [...albumOf('Alpha'), ...albumOf('Beta')];
      final harness = batchHarness(
        library,
        releases: {
          'Alpha': releaseOf('Alpha'),
          'Beta': releaseOf('Beta', status: 'Bootleg'),
        },
      );
      final controller = harness.read(batchAutofillControllerProvider.notifier);
      await controller.start(planBatch(library, library), const {
        AutofillField.artist,
      });
      await controller.settled;

      await open(tester, harness, library);
      await tester.tap(find.text('Start new'));
      await tester.pumpAndSettle();

      expect(find.text('Fill which tags?'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenWriteAccessRefused_WhenConfirmed_ThenASnackBarSaysSoAndNoScreenOpens',
    (tester) async {
      final library = [...albumOf('Alpha'), ...albumOf('Beta')];
      final access = FakeLibraryAccess()
        ..writeDecision = LibraryAccessDecision.denied;
      final harness = batchHarness(library, access: access);

      await open(tester, harness, library);
      await answer(tester);

      expect(find.byType(BatchAutofillScreen), findsNothing);
      expect(
        find.text(
          'Orpheus needs permission to change your music files. '
          'Nothing was written.',
        ),
        findsOneWidget,
      );
      expect(find.text('Open settings'), findsNothing);
      expect(harness.metadata.releaseQueries, isEmpty);
    },
  );

  testWidgets(
    'GivenWriteAccessRefusedForGood_WhenConfirmed_ThenTheSnackBarOffersSettings',
    (tester) async {
      final library = [...albumOf('Alpha'), ...albumOf('Beta')];
      final access = FakeLibraryAccess()
        ..writeDecision = LibraryAccessDecision.deniedPermanently;
      final harness = batchHarness(library, access: access);

      await open(tester, harness, library);
      await answer(tester);
      await tester.tap(find.text('Open settings'));
      await tester.pumpAndSettle();

      expect(access.openedSettings, isTrue);
    },
  );
}
