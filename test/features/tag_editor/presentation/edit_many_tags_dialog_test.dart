import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/core/settings/in_memory_settings_store.dart';
import 'package:orpheus/features/autofill/domain/autofill_field.dart';
import 'package:orpheus/features/autofill/domain/tag_writer.dart';
import 'package:orpheus/features/library/domain/audio_file.dart';
import 'package:orpheus/features/library/domain/library_access.dart';
import 'package:orpheus/features/library/domain/library_scan.dart';
import 'package:orpheus/features/library/domain/music_catalog.dart';
import 'package:orpheus/features/library/domain/music_entry.dart';
import 'package:orpheus/features/library/domain/track_metadata.dart';
import 'package:orpheus/features/tag_editor/presentation/edit_many_tags_dialog.dart';
import 'package:orpheus/features/tag_editor/presentation/edit_tags_launcher.dart';

import '../../../support/entries.dart';
import '../../../support/fakes.dart';
import '../../../support/pump.dart';
import '../../../support/test_container.dart';

/// Editing what several tracks share in one form.
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
  final airbag = entry(id: 'airbag', title: 'Airbag', album: 'OK Computer');
  final paranoid = entry(
    id: 'paranoid',
    title: 'Paranoid Android',
    album: 'OK Computer',
  );
  final subterranean = entry(
    id: 'subterranean',
    title: 'Subterranean Homesick Alien',
    album: 'OK Computer',
  );
  final tracks = [airbag, paranoid, subterranean];
  final ogg = MusicEntry(
    file: AudioFile(
      path: '/library/song.ogg',
      sizeInBytes: 1,
      modifiedAt: DateTime.utc(2026),
    ),
    metadata: const TrackMetadata(title: 'Lucky'),
  );

  FileTags tagsOf({
    Map<AutofillField, Object?> values = const {},
    Uint8List? cover,
  }) => FileTags(
    writable: AutofillField.values.toSet(),
    values: {
      AutofillField.artist: 'Radiohead',
      AutofillField.album: 'OK Computer',
      AutofillField.year: 1997,
      ...values,
    },
    cover: cover,
  );

  Harness harnessFor() {
    final harness = Harness(
      library: tracks,
      // Never the real scanner: a save rescans.
      scanner: ScriptedScanner([
        ScanCompleted(
          catalog: MusicCatalog(entries: tracks),
          report: const ScanReport(
            tracks: 3,
            added: 0,
            updated: 3,
            removed: 0,
            reused: 0,
          ),
        ),
      ]),
      settings: InMemorySettingsStore(libraryFolders: const ['/music']),
    );
    for (final track in tracks) {
      harness.tagWriter.files[track.file.path] = tagsOf();
    }

    return harness;
  }

  Future<void> open(
    WidgetTester tester,
    Harness harness, {
    List<MusicEntry>? of,
  }) async {
    await tester.pumpHarness(
      harness,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                startManyTagEdit(context, of ?? tracks, label: 'OK Computer'),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Finder field(AutofillField f) => find.byKey(ValueKey(f));

  TextField textFieldOf(WidgetTester tester, AutofillField f) =>
      tester.widget<TextField>(field(f));

  VoidCallback? saveOf(WidgetTester tester) => tester
      .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
      .onPressed;

  Future<void> typeAGenreAndSave(WidgetTester tester) async {
    await tester.enterText(field(AutofillField.genre), 'Alternative');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
  }

  testWidgets(
    'GivenThreeSongsOfOneAlbum_WhenOpened_ThenTheAlbumIsFilledAndTitleAndTrackNumberAreAbsent',
    (tester) async {
      await open(tester, harnessFor());

      expect(find.byType(EditManyTagsDialog), findsOneWidget);
      expect(find.text('OK Computer · 3 songs'), findsOneWidget);
      expect(
        find.descendant(
          of: field(AutofillField.album),
          matching: find.text('OK Computer'),
        ),
        findsOneWidget,
      );
      expect(field(AutofillField.title), findsNothing);
      expect(field(AutofillField.trackNumber), findsNothing);
      expect(find.widgetWithText(TextField, 'Title'), findsNothing);
      expect(find.widgetWithText(TextField, 'Track number'), findsNothing);
      expect(
        find.text('Title and track number are edited one song at a time.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('GivenDifferentYears_WhenOpened_ThenTheYearShowsTheMixedHint', (
    tester,
  ) async {
    final harness = harnessFor();
    harness.tagWriter.files[paranoid.file.path] = tagsOf(
      values: const {AutofillField.year: 1998},
    );
    await open(tester, harness);

    final year = textFieldOf(tester, AutofillField.year);
    expect(year.controller!.text, isEmpty);
    expect(
      year.decoration!.hintText,
      "Mixed — leave blank to keep each song's own",
    );
  });

  testWidgets('GivenNothingChanged_WhenOpened_ThenSaveIsDisabled', (
    tester,
  ) async {
    await open(tester, harnessFor());

    expect(saveOf(tester), isNull);
  });

  testWidgets('GivenAGenreTyped_ThenSaveIsEnabled', (tester) async {
    await open(tester, harnessFor());

    await tester.enterText(field(AutofillField.genre), 'Alternative');
    await tester.pump();

    expect(saveOf(tester), isNotNull);
  });

  testWidgets(
    'GivenTheSameNumberRetypedWithALeadingZero_ThenSaveStaysDisabled',
    (tester) async {
      final harness = harnessFor();
      for (final track in tracks) {
        harness.tagWriter.files[track.file.path] = tagsOf(
          values: const {AutofillField.discNumber: 1},
        );
      }
      await open(tester, harness);

      await tester.enterText(field(AutofillField.discNumber), '01');
      await tester.pump();

      expect(saveOf(tester), isNull);
    },
  );

  testWidgets(
    'GivenTheDiscNumberClearedUnderASharedTotal_WhenTyped_ThenSaveIsDisabledAndTheFieldSaysWhy',
    (tester) async {
      final harness = harnessFor();
      for (final track in tracks) {
        harness.tagWriter.files[track.file.path] = tagsOf(
          values: const {
            AutofillField.discNumber: 1,
            AutofillField.discTotal: 2,
          },
        );
      }
      await open(tester, harness);

      await tester.enterText(field(AutofillField.discNumber), '');
      await tester.pump();

      expect(saveOf(tester), isNull);
      expect(
        textFieldOf(tester, AutofillField.discNumber).decoration!.errorText,
        'Enter a number, or clear the total',
      );
    },
  );

  testWidgets('GivenAYearOf0_WhenTyped_ThenSaveIsDisabledAndTheFieldSaysWhy', (
    tester,
  ) async {
    await open(tester, harnessFor());

    await tester.enterText(field(AutofillField.year), '0');
    await tester.pump();

    expect(saveOf(tester), isNull);
    expect(
      textFieldOf(tester, AutofillField.year).decoration!.errorText,
      'Enter a year from 1 to 9999',
    );
  });

  testWidgets('GivenAnOggAmongThem_WhenOpened_ThenOneSongIsSaidToBeLeftAlone', (
    tester,
  ) async {
    await open(tester, harnessFor(), of: [...tracks, ogg]);

    expect(
      find.text("1 song can't be changed and will be left alone"),
      findsOneWidget,
    );

    await tester.tap(
      find.text("1 song can't be changed and will be left alone"),
    );
    await tester.pumpAndSettle();

    expect(find.text('Lucky'), findsOneWidget);
    expect(find.text('Not an MP3 or FLAC file'), findsOneWidget);
  });

  testWidgets('GivenDifferentCovers_WhenOpened_ThenDifferentCoversIsShown', (
    tester,
  ) async {
    final harness = harnessFor();
    harness.tagWriter.files[airbag.file.path] = tagsOf(cover: jpeg);
    await open(tester, harness);

    expect(find.text('Different covers'), findsOneWidget);
    expect(find.byIcon(Icons.filter_none), findsOneWidget);
  });

  testWidgets('GivenAPngPicked_WhenSaved_ThenEveryFileGetsTheCover', (
    tester,
  ) async {
    final harness = harnessFor();
    harness.coverPicker.next = png;
    await open(tester, harness);

    await tester.tap(find.text('Choose image…'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(harness.tagWriter.writes, hasLength(3));
    expect(
      {for (final (path, _) in harness.tagWriter.writes) path},
      {for (final track in tracks) track.file.path},
    );
    for (final (_, values) in harness.tagWriter.writes) {
      expect(values, {AutofillField.cover: png});
    }
  });

  testWidgets(
    'GivenOneFileInUse_WhenSaved_ThenTheResultListsItAndOffersTryAgain',
    (tester) async {
      final harness = harnessFor();
      harness.tagWriter.refusals[paranoid.file.path] = WriteOutcome.inUse;
      await open(tester, harness);

      await typeAGenreAndSave(tester);
      await tester.pumpAndSettle();

      expect(find.text("Saved to 2 songs. 1 couldn't be changed:"), findsOne);
      expect(find.text('Paranoid Android'), findsOneWidget);
      expect(
        find.text('In use by playback — try again once it has moved on'),
        findsOneWidget,
      );
      expect(find.widgetWithText(FilledButton, 'Try again'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Save'), findsNothing);
      expect(textFieldOf(tester, AutofillField.genre).readOnly, isTrue);
    },
  );

  testWidgets(
    'GivenEveryFileWrittenButOneLeftItsTotal_WhenSaved_ThenTheNoteIsShownWithCloseOnly',
    (tester) async {
      final harness = harnessFor();
      for (final track in [airbag, paranoid]) {
        harness.tagWriter.files[track.file.path] = tagsOf(
          values: const {AutofillField.trackNumber: 1},
        );
      }
      await open(tester, harness);

      await tester.enterText(field(AutofillField.trackTotal), '12');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(EditManyTagsDialog),
          matching: find.text('Tags saved to 2 songs'),
        ),
        findsOneWidget,
      );
      expect(find.text('Subterranean Homesick Alien'), findsOneWidget);
      expect(
        find.text('Its track total was left as it was: it has no track number'),
        findsOneWidget,
      );
      expect(find.text('Try again'), findsNothing);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      expect(find.byType(EditManyTagsDialog), findsNothing);
      expect(find.text('Tags saved to 2 songs'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenWriteAccessRefusedForGood_WhenSaved_ThenTheFormSaysSoAndOffersTheSettings',
    (tester) async {
      final harness = harnessFor();
      harness.access.writeDecision = LibraryAccessDecision.deniedPermanently;
      await open(tester, harness);

      await typeAGenreAndSave(tester);
      await tester.pumpAndSettle();

      expect(harness.tagWriter.writes, isEmpty);
      expect(
        find.text(
          'Orpheus needs permission to change your music files. '
          'Nothing was written.',
        ),
        findsOneWidget,
      );
      expect(saveOf(tester), isNotNull);

      await tester.tap(find.text('Open settings'));
      await tester.pump();

      expect(harness.access.openedSettings, isTrue);
    },
  );

  testWidgets('GivenAWriteInFlight_WhenBackIsPressed_ThenTheDialogStays', (
    tester,
  ) async {
    final harness = harnessFor();
    final hold = Completer<void>();
    harness.tagWriter.hold = hold.future;
    await open(tester, harness);

    await typeAGenreAndSave(tester);
    await tester.pump();
    await tester.binding.handlePopRoute();
    // Long enough for a dialog that did close to be gone; not settled, as the
    // progress indicator spins for as long as the write is held.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(EditManyTagsDialog), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Cancel'))
          .onPressed,
      isNull,
    );

    hold.complete();
    await tester.pumpAndSettle();
  });

  testWidgets(
    'GivenAllWritten_WhenSaved_ThenTheDialogClosesAndSaysTagsSavedTo3Songs',
    (tester) async {
      final harness = harnessFor();
      await open(tester, harness);

      await typeAGenreAndSave(tester);
      await tester.pumpAndSettle();

      expect(harness.tagWriter.writes, hasLength(3));
      expect(find.byType(EditManyTagsDialog), findsNothing);
      expect(find.text('Tags saved to 3 songs'), findsOneWidget);
    },
  );
}
