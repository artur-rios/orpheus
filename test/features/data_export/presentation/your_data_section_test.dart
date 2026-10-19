import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/data_export/data/zip_backup_codec.dart';
import 'package:orpheus/features/playlists/domain/file_saver.dart';
import 'package:orpheus/features/shell/presentation/preferences_dialog.dart';

import '../../../support/entries.dart';
import '../../../support/pump.dart';
import '../../../support/test_container.dart';

/// The *Your data* section of the Preferences: the two exports, what each says
/// about itself, and how a backup went.
void main() {
  final library = [entry(id: 'a', title: 'Alpha')];

  Future<Harness> open(
    WidgetTester tester, {
    bool failPlaylists = false,
    bool failLibrary = false,
  }) async {
    final harness = Harness(library: library, now: DateTime(2026, 10, 18));
    if (failPlaylists) {
      harness.playlistStore.failRead = const FileSystemException('no access');
    }
    if (failLibrary) harness.catalogs.failOnRead = true;
    await tester.pumpHarness(harness, const _OpenPreferences());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    return harness;
  }

  /// [text], as said inside the Preferences dialog rather than anywhere on
  /// the screen behind it, where its barrier would dim it.
  Finder said(String text) => find.descendant(
    of: find.byType(PreferencesDialog),
    matching: find.text(text),
  );

  Finder jsonTile() => find.widgetWithText(ListTile, 'Export my data (JSON)…');
  Finder backupTile() =>
      find.widgetWithText(ListTile, 'Back up Orpheus (ZIP)…');

  Future<void> tapBackup(WidgetTester tester) async {
    await tester.ensureVisible(backupTile());
    await tester.pumpAndSettle();
    await tester.tap(backupTile());
  }

  testWidgets(
    'GivenThePreferences_WhenTheyOpen_ThenTheSectionOffersBothExportsEachWithItsExplanation',
    (tester) async {
      await open(tester);
      await tester.ensureVisible(backupTile());

      expect(said('Your data'), findsOneWidget);
      expect(jsonTile(), findsOneWidget);
      expect(
        said(
          'For looking at your data in other tools, or importing it elsewhere.',
        ),
        findsOneWidget,
      );
      expect(backupTile(), findsOneWidget);
      expect(
        said(
          'For restoring Orpheus on this or another device: your data, '
          'playlist covers and preferences.',
        ),
        findsOneWidget,
      );
      expect(tester.widget<ListTile>(backupTile()).enabled, isTrue);
    },
  );

  testWidgets(
    'GivenThePreferences_WhenTheyOpen_ThenTheSectionOffersTheAboutEntry',
    (tester) async {
      await open(tester);
      await tester.ensureVisible(find.text('About these exports'));

      expect(said('About these exports'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenTheAboutEntry_WhenItIsTapped_ThenTheComparisonOpensOverThePreferences',
    (tester) async {
      await open(tester);
      await tester.ensureVisible(find.text('About these exports'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('About these exports'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNWidgets(2));
      expect(find.byType(Table), findsOneWidget);
    },
  );

  testWidgets(
    'GivenTheOwnerChoosesAPlace_WhenTheyBackUp_ThenTheZipIsSavedAndTheDialogNamesIt',
    (tester) async {
      final harness = await open(tester);

      await tapBackup(tester);
      await tester.pumpAndSettle();

      expect(harness.fileSaver.saved, hasLength(1));
      expect(
        harness.fileSaver.saved.single.suggestedName,
        'orpheus-backup-2026-10-18.zip',
      );
      expect(
        readBackup(harness.fileSaver.saved.single.bytes).isFullBackup,
        isTrue,
      );
      expect(said('Backed up to /exports/saved'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenAPlatformThatGivesNoPath_WhenTheyBackUp_ThenTheDialogSaysOnlyBackedUp',
    (tester) async {
      final harness = await open(tester);
      harness.fileSaver.next = const SavedFile();

      await tapBackup(tester);
      await tester.pumpAndSettle();

      expect(said('Backed up'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenAPlaylistsStoreThatCannotBeRead_WhenTheyBackUp_ThenTheDialogSaysSomeDataWasMissed',
    (tester) async {
      await open(tester, failPlaylists: true);

      await tapBackup(tester);
      await tester.pumpAndSettle();

      expect(
        said('Backed up, but some data could not be read'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Text>(said('Backed up, but some data could not be read'))
            .style
            ?.color,
        Theme.of(tester.element(backupTile())).colorScheme.error,
      );
    },
  );

  testWidgets('GivenASaverThatFails_WhenTheyBackUp_ThenTheDialogSaysItFailed', (
    tester,
  ) async {
    final harness = await open(tester);
    harness.fileSaver.failure = const FileSystemException('disk full');

    await tapBackup(tester);
    await tester.pumpAndSettle();

    expect(said("Couldn't back up Orpheus"), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets(
    'GivenALibraryThatCannotBeRead_WhenTheyBackUp_ThenTheDialogSaysThereIsNothingToBackUp',
    (tester) async {
      final harness = await open(tester, failLibrary: true);

      await tapBackup(tester);
      await tester.pumpAndSettle();

      expect(
        said("Your library couldn't be read, so there's nothing to back up"),
        findsOneWidget,
      );
      expect(harness.fileSaver.saved, isEmpty);
    },
  );

  testWidgets(
    'GivenTheOwnerCancelsTheDialog_WhenTheyBackUp_ThenNothingIsSaid',
    (tester) async {
      final harness = await open(tester);
      harness.fileSaver.next = null;

      await tapBackup(tester);
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsNothing);
      expect(said('Backed up to /exports/saved'), findsNothing);
      expect(said('Backed up'), findsNothing);
    },
  );

  testWidgets(
    'GivenAFailureIsShown_WhenAnotherBackupStarts_ThenThePreviousStatusIsClearedWhileItRuns',
    (tester) async {
      final harness = await open(tester);
      harness.fileSaver.failure = const FileSystemException('disk full');
      await tapBackup(tester);
      await tester.pumpAndSettle();
      expect(said("Couldn't back up Orpheus"), findsOneWidget);

      final gate = Completer<void>();
      harness.fileSaver
        ..failure = null
        ..gate = gate;
      await tapBackup(tester);
      await tester.pump();

      expect(said("Couldn't back up Orpheus"), findsNothing);

      gate.complete();
      await tester.pumpAndSettle();

      expect(said('Backed up to /exports/saved'), findsOneWidget);
    },
  );

  testWidgets('GivenAStatusIsShown_WhenItAppears_ThenItIsALiveRegion', (
    tester,
  ) async {
    await open(tester);

    await tapBackup(tester);
    await tester.pumpAndSettle();

    final live = find.ancestor(
      of: said('Backed up to /exports/saved'),
      matching: find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.liveRegion == true,
      ),
    );
    expect(live, findsOneWidget);
  });

  testWidgets(
    'GivenABackupIsRunning_WhenThePreferencesAreShown_ThenTheEntryIsDisabledWithAProgressIndicator',
    (tester) async {
      final harness = await open(tester);
      final gate = Completer<void>();
      harness.catalogs.readGate = gate;

      await tapBackup(tester);
      // Not settled: a progress indicator never stops.
      await tester.pump();

      expect(tester.widget<ListTile>(backupTile()).enabled, isFalse);
      expect(
        find.descendant(
          of: backupTile(),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      // The other export is its own: not held up by this one.
      expect(tester.widget<ListTile>(jsonTile()).enabled, isTrue);

      gate.complete();
      await tester.pumpAndSettle();

      expect(tester.widget<ListTile>(backupTile()).enabled, isTrue);
    },
  );

  testWidgets(
    'GivenABackupIsRunning_WhenTheEntryIsTappedAgain_ThenTheFileIsOfferedOnce',
    (tester) async {
      final harness = await open(tester);
      final gate = Completer<void>();
      harness.catalogs.readGate = gate;

      await tapBackup(tester);
      await tester.pump();
      await tester.tap(backupTile(), warnIfMissed: false);
      gate.complete();
      await tester.pumpAndSettle();

      expect(harness.fileSaver.saved, hasLength(1));
    },
  );

  testWidgets(
    'GivenABackupStatusIsShown_WhenTheJsonIsExported_ThenEachEntryKeepsItsOwnStatus',
    (tester) async {
      await open(tester);
      await tapBackup(tester);
      await tester.pumpAndSettle();

      await tester.ensureVisible(jsonTile());
      await tester.pumpAndSettle();
      await tester.tap(jsonTile());
      await tester.pumpAndSettle();

      expect(said('Backed up to /exports/saved'), findsOneWidget);
      expect(said('Exported to /exports/saved'), findsOneWidget);
    },
  );
}

/// A button that opens the preferences, so the dialog has a navigator.
class _OpenPreferences extends StatelessWidget {
  const _OpenPreferences();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Builder(
      builder: (context) => TextButton(
        onPressed: () => PreferencesDialog.show(context),
        child: const Text('open'),
      ),
    ),
  );
}
