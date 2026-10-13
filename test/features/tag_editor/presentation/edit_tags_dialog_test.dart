import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/core/settings/in_memory_settings_store.dart';
import 'package:orpheus/features/autofill/domain/autofill_field.dart';
import 'package:orpheus/features/autofill/domain/tag_writer.dart';
import 'package:orpheus/features/library/domain/audio_file.dart';
import 'package:orpheus/features/library/domain/library_scan.dart';
import 'package:orpheus/features/library/domain/music_catalog.dart';
import 'package:orpheus/features/library/domain/music_entry.dart';
import 'package:orpheus/features/library/domain/track_metadata.dart';
import 'package:orpheus/features/tag_editor/presentation/edit_tags_dialog.dart';
import 'package:orpheus/features/tag_editor/presentation/edit_tags_launcher.dart';

import '../../../support/entries.dart';
import '../../../support/fakes.dart';
import '../../../support/pump.dart';
import '../../../support/test_container.dart';

/// Editing one track's tags by hand.
void main() {
  final png = Uint8List.fromList([
    0x89,
    0x50,
    0x4E,
    0x47,
    0x0D,
    0x0A,
    0x1A,
    0x0A,
    1,
  ]);
  final jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 2]);
  final track = entry(id: 'airbag', title: 'Airbag', artist: 'Radiohed');
  final path = track.file.path;

  Harness harnessFor({Set<AutofillField>? writable}) {
    final harness = Harness(
      library: [track],
      scanner: ScriptedScanner([
        ScanCompleted(
          catalog: MusicCatalog(entries: [track]),
          report: const ScanReport(
            tracks: 1,
            added: 0,
            updated: 1,
            removed: 0,
            reused: 0,
          ),
        ),
      ]),
      settings: InMemorySettingsStore(libraryFolders: const ['/music']),
    );
    harness.tagWriter.files[path] = FileTags(
      writable: writable ?? AutofillField.values.toSet(),
      values: const {
        AutofillField.title: 'Airbag',
        AutofillField.artist: 'Radiohed',
        AutofillField.trackNumber: 1,
        AutofillField.genre: 'Rock; Pop',
      },
      cover: png,
    );

    return harness;
  }

  Future<void> open(
    WidgetTester tester,
    Harness harness, {
    MusicEntry? of,
    Size window = desktopWindow,
  }) async {
    await tester.pumpHarness(
      harness,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => startTagEdit(context, of ?? track),
            child: const Text('open'),
          ),
        ),
      ),
      window: window,
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Finder field(AutofillField f) => find.byKey(ValueKey(f));

  String textOf(WidgetTester tester, AutofillField f) =>
      tester.widget<TextField>(field(f)).controller!.text;

  VoidCallback? saveOf(WidgetTester tester, String label) => tester
      .widget<FilledButton>(find.widgetWithText(FilledButton, label))
      .onPressed;

  testWidgets(
    'GivenAFlac_WhenTheEditorOpens_ThenItsFieldsHoldWhatTheFileSaysAndSaveIsOff',
    (tester) async {
      await open(tester, harnessFor());

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Edit tags'), findsOneWidget);
      expect(textOf(tester, AutofillField.title), 'Airbag');
      expect(textOf(tester, AutofillField.trackNumber), '1');
      expect(textOf(tester, AutofillField.genre), 'Rock; Pop');
      expect(saveOf(tester, 'Save'), isNull);
    },
  );

  testWidgets(
    'GivenTheTitleIsChanged_WhenSaved_ThenOnlyItIsWrittenAndTheEditorClosesSayingSo',
    (tester) async {
      final harness = harnessFor();
      await open(tester, harness);

      await tester.enterText(field(AutofillField.title), 'Airbag (Live)');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(harness.tagWriter.writes.single.$1, path);
      expect(harness.tagWriter.writes.single.$2, {
        AutofillField.title: 'Airbag (Live)',
      });
      expect(find.byType(EditTagsDialog), findsNothing);
      expect(find.text('Tags saved'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenATrackNumberThatIsNotAWholeNumber_WhenTyped_ThenSaveIsOffAndWhyIsShown',
    (tester) async {
      await open(tester, harnessFor());

      await tester.enterText(field(AutofillField.trackNumber), 'three');
      await tester.pump();

      expect(find.text('Enter a whole number'), findsOneWidget);
      expect(saveOf(tester, 'Save'), isNull);
    },
  );

  testWidgets(
    'GivenAFieldTheFormatCannotHold_WhenTheEditorOpens_ThenItIsOffAndNamed',
    (tester) async {
      await open(
        tester,
        harnessFor(
          writable: AutofillField.values.toSet()
            ..remove(AutofillField.albumArtist),
        ),
      );

      expect(
        tester.widget<TextField>(field(AutofillField.albumArtist)).enabled,
        isFalse,
      );
      expect(
        find.text("This kind of file can't hold: Album artist"),
        findsOneWidget,
      );
    },
  );

  testWidgets('GivenACover_WhenRemovedAndSaved_ThenTheCoverIsTakenOut', (
    tester,
  ) async {
    final harness = harnessFor();
    await open(tester, harness);

    await tester.tap(find.text('Remove'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(harness.tagWriter.writes.single.$2, {AutofillField.cover: null});
  });

  testWidgets('GivenTheOwnerPicksAJpeg_WhenSaved_ThenItIsWrittenAsTheCover', (
    tester,
  ) async {
    final harness = harnessFor();
    harness.coverPicker.next = jpeg;
    await open(tester, harness);

    await tester.tap(find.text('Choose image…'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(harness.tagWriter.writes.single.$2, {AutofillField.cover: jpeg});
  });

  testWidgets(
    'GivenTheOwnerPicksAGif_WhenChosen_ThenTheCoverIsUnchangedAndWhyIsShown',
    (tester) async {
      final harness = harnessFor();
      harness.coverPicker.next = Uint8List.fromList('GIF89a'.codeUnits);
      await open(tester, harness);

      await tester.tap(find.text('Choose image…'));
      await tester.pump();

      expect(find.text('Choose a JPEG or PNG image'), findsOneWidget);
      expect(saveOf(tester, 'Save'), isNull);
    },
  );

  testWidgets('GivenAnOggFile_WhenTheEditorOpens_ThenItSaysItCannotChangeIt', (
    tester,
  ) async {
    final ogg = MusicEntry(
      file: AudioFile(
        path: '/library/song.ogg',
        sizeInBytes: 1,
        modifiedAt: DateTime.utc(2026),
      ),
      metadata: TrackMetadata.empty,
    );

    await open(tester, harnessFor(), of: ogg);

    expect(
      find.text('Orpheus can only change the tags of MP3 and FLAC files.'),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, 'Save'), findsNothing);
    expect(find.text('Close'), findsOneWidget);
  });

  testWidgets(
    'GivenTheFileIsInUse_WhenSaved_ThenTheReasonIsShownAndTheEditKept',
    (tester) async {
      final harness = harnessFor();
      harness.tagWriter.refusals[path] = WriteOutcome.inUse;
      await open(tester, harness);

      await tester.enterText(field(AutofillField.title), 'Airbag (Live)');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(
        find.text('In use by playback — try again once it has moved on'),
        findsOneWidget,
      );
      expect(textOf(tester, AutofillField.title), 'Airbag (Live)');
      expect(saveOf(tester, 'Try again'), isNotNull);
    },
  );

  testWidgets(
    'GivenTheFileChangedSinceRead_WhenReloadIsPressed_ThenTheFieldsShowWhatItNowSays',
    (tester) async {
      final harness = harnessFor();
      harness.tagWriter.refusals[path] = WriteOutcome.changedSinceRead;
      await open(tester, harness);
      await tester.enterText(field(AutofillField.title), 'Mine');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(saveOf(tester, 'Save'), isNull);
      harness.tagWriter.refusals.remove(path);
      harness.tagWriter.files[path] = FileTags(
        writable: AutofillField.values.toSet(),
        values: const {AutofillField.title: 'Airbag (Remastered)'},
      );
      await tester.tap(find.text('Reload'));
      await tester.pumpAndSettle();

      expect(textOf(tester, AutofillField.title), 'Airbag (Remastered)');
    },
  );

  testWidgets('GivenAPhoneWindow_WhenTheEditorOpens_ThenItFillsTheScreen', (
    tester,
  ) async {
    await open(tester, harnessFor(), window: phoneWindow);

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Edit tags'), findsOneWidget);
    expect(textOf(tester, AutofillField.title), 'Airbag');
  });
}
