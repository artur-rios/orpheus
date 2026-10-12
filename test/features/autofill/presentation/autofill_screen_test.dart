import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/core/settings/in_memory_settings_store.dart';
import 'package:orpheus/features/autofill/application/autofill_controller.dart';
import 'package:orpheus/features/autofill/domain/autofill_field.dart';
import 'package:orpheus/features/autofill/domain/metadata_source.dart';
import 'package:orpheus/features/autofill/domain/release.dart';
import 'package:orpheus/features/autofill/domain/tag_writer.dart';
import 'package:orpheus/features/autofill/presentation/autofill_screen.dart';
import 'package:orpheus/features/library/domain/audio_file.dart';
import 'package:orpheus/features/library/domain/library_access.dart';
import 'package:orpheus/features/library/domain/library_scan.dart';
import 'package:orpheus/features/library/domain/music_catalog.dart';
import 'package:orpheus/features/library/domain/music_entry.dart';
import 'package:orpheus/features/library/domain/music_grouping.dart';
import 'package:orpheus/features/library/domain/track_metadata.dart';

import '../../../support/entries.dart';
import '../../../support/fakes.dart';
import '../../../support/pump.dart';
import '../../../support/test_container.dart';

/// The review screen: what the owner sees, ticks and confirms.
void main() {
  final record = [
    entry(id: 'ok1', title: 'Airbag', artist: 'Radiohed', album: 'OK Computer', track: 1),
    entry(id: 'ok2', title: 'Paranoid Android', artist: 'Radiohed', album: 'OK Computer', track: 2),
  ];

  const candidate = ReleaseCandidate(
    id: 'rel-1',
    title: 'OK Computer',
    artistCredit: [ArtistCredit(name: 'Radiohead')],
    trackCount: 2,
    status: 'Official',
    date: '1997',
  );
  const other = ReleaseCandidate(
    id: 'rel-2',
    title: 'OK Computer (Remastered)',
    artistCredit: [ArtistCredit(name: 'Radiohead')],
    trackCount: 2,
    status: 'Official',
    date: '2009',
  );

  ReleaseDetail detailOf(ReleaseCandidate release) => ReleaseDetail(
    release: release,
    tracks: const [
      ReleaseTrack(disc: 1, position: 1, title: 'Airbag', artistCredit: [ArtistCredit(name: 'Radiohead')]),
      ReleaseTrack(disc: 1, position: 2, title: 'Paranoid Android', artistCredit: [ArtistCredit(name: 'Radiohead')]),
    ],
  );

  Harness harnessFor({FakeLibraryAccess? access, ScriptedScanner? scanner}) {
    final harness = Harness(
      library: record,
      access: access,
      // Never the real scanner: a write rescans, and the rescan must not walk
      // the disk wherever the test is not about it.
      scanner:
          scanner ??
          ScriptedScanner([
            ScanCompleted(
              catalog: MusicCatalog(entries: albumArtistsAcross(record)),
              report: const ScanReport(tracks: 2, added: 0, updated: 0, removed: 0, reused: 2),
            ),
          ]),
      settings: InMemorySettingsStore(libraryFolders: const ['/music']),
    );
    harness.metadata
      ..candidates = const [candidate, other]
      ..releases = {'rel-1': detailOf(candidate), 'rel-2': detailOf(other)};
    for (final e in record) {
      harness.tagWriter.files[e.file.path] = FileTags(
        writable: AutofillField.values.toSet(),
        values: {AutofillField.title: e.title, AutofillField.artist: 'Radiohed', AutofillField.album: 'OK Computer'},
      );
    }

    // A write starts a rescan and does not wait for it, so it may still be
    // running when the test's last line is. Let it finish before the container
    // goes (teardowns run last-registered first).
    addTearDown(pumpEventQueue);

    return harness;
  }

  Future<void> openScreen(WidgetTester tester, Harness harness, Set<AutofillField> fields) async {
    await tester.pumpHarness(
      harness,
      AutofillScreen(entries: record, fields: fields, kind: AutofillKind.record),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('GivenAMatch_WhenTheScreenShows_ThenEachChangeReadsOldToNewAndTheButtonCountsThem', (tester) async {
    final harness = harnessFor();

    await openScreen(tester, harness, {AutofillField.artist});

    expect(find.text('OK Computer'), findsWidgets);
    expect(find.text('Radiohed'), findsNWidgets(2));
    expect(find.text('Radiohead'), findsWidgets);
    expect(find.text('Write 2 changes to 2 files'), findsOneWidget);
  });

  testWidgets('GivenTheOwnerUnticksAChange_WhenTheyDo_ThenTheButtonCountsOneFewer', (tester) async {
    final harness = harnessFor();
    await openScreen(tester, harness, {AutofillField.artist});

    await tester.tap(find.byType(CheckboxListTile).first);
    await tester.pump();

    expect(find.text('Write 1 change to 1 file'), findsOneWidget);
  });

  testWidgets('GivenTwoFiles_WhenOneCardsTickAllIsToggled_ThenOnlyThatCardsChangesFollowAndTheButtonCounts', (tester) async {
    final harness = harnessFor();
    // Two changes a file: the artist, and an album artist the files lack.
    await openScreen(tester, harness, {AutofillField.artist, AutofillField.albumArtist});
    expect(find.text('Write 4 changes to 2 files'), findsOneWidget);
    final first = find.byKey(ValueKey('autofill-file-toggle-${record.first.file.path}'));
    final second = find.byKey(ValueKey('autofill-file-toggle-${record[1].file.path}'));
    bool? ticked(Finder toggle) => tester.widget<Checkbox>(toggle).value;
    List<bool?> changesOf(int card) => [
      for (final tile in tester.widgetList<CheckboxListTile>(
        find.descendant(of: find.byType(Card).at(card + 1), matching: find.byType(CheckboxListTile)),
      ))
        tile.value,
    ];

    await tester.tap(first);
    await tester.pump();

    expect(find.text('Write 2 changes to 1 file'), findsOneWidget);
    expect(ticked(first), isFalse);
    expect(changesOf(0), [false, false]);
    expect(ticked(second), isTrue);
    expect(changesOf(1), [true, true]);

    // One change ticked again: the card is partly ticked, and its toggle
    // ticks the rest.
    await tester.tap(find.descendant(of: find.byType(Card).at(1), matching: find.byType(CheckboxListTile)).first);
    await tester.pump();
    expect(ticked(first), isNull);
    expect(find.text('Write 3 changes to 2 files'), findsOneWidget);

    await tester.tap(first);
    await tester.pump();

    expect(ticked(first), isTrue);
    expect(changesOf(0), [true, true]);
    expect(find.text('Write 4 changes to 2 files'), findsOneWidget);
  });

  testWidgets('GivenEveryChangeUnticked_WhenTheScreenShows_ThenWritingIsDisabled', (tester) async {
    final harness = harnessFor();
    await openScreen(tester, harness, {AutofillField.artist});

    await tester.tap(find.text('Untick all'));
    await tester.pump();

    final button = tester.widget<FilledButton>(find.ancestor(of: find.textContaining('Write'), matching: find.byType(FilledButton)));
    expect(button.onPressed, isNull);
  });

  testWidgets('GivenAKindOfFileOrpheusCannotWrite_WhenTheScreenShows_ThenItSaysSo', (tester) async {
    final harness = harnessFor();
    final ogg = MusicEntry(
      file: AudioFile(path: '/library/song.ogg', sizeInBytes: 1024, modifiedAt: DateTime.utc(2026)),
      metadata: const TrackMetadata(title: 'Paranoid Android', artist: 'Radiohed', album: 'OK Computer', track: 2),
    );

    await tester.pumpHarness(
      harness,
      AutofillScreen(entries: [record.first, ogg], fields: const {AutofillField.artist}, kind: AutofillKind.record),
    );
    await tester.pumpAndSettle();

    expect(find.text("Orpheus can't change this kind of file"), findsOneWidget);
    expect(find.text("Orpheus can't safely change this file's tags"), findsNothing);
  });

  testWidgets('GivenAnUnwritableFile_WhenTheScreenShows_ThenItIsNamedWithTheReasonAndHasNoCheckbox', (tester) async {
    final harness = harnessFor();
    // A FLAC, which Orpheus writes, whose tags it cannot change safely.
    harness.tagWriter.files[record.first.file.path] = FileTags.unwritable;

    await openScreen(tester, harness, {AutofillField.artist});

    expect(find.text("Orpheus can't safely change this file's tags"), findsOneWidget);
    expect(find.text("Orpheus can't change this kind of file"), findsNothing);
    expect(find.byType(CheckboxListTile), findsNWidgets(1));
    expect(find.byKey(ValueKey('autofill-file-toggle-${record.first.file.path}')), findsNothing);
  });

  testWidgets('GivenTheCoverDownloadFails_WhenTheScreenShows_ThenItSaysItCouldNotBeDownloadedNotThatThereIsNone', (tester) async {
    final harness = harnessFor();
    harness.metadata.coverFailure = MetadataSourceFailure.unreachable;

    await openScreen(tester, harness, {AutofillField.cover, AutofillField.artist});

    expect(find.text('The cover could not be downloaded from the Cover Art Archive.'), findsOneWidget);
    expect(find.text('This release has no cover on the Cover Art Archive.'), findsNothing);
    expect(find.text('Write 2 changes to 2 files'), findsOneWidget);
  });

  testWidgets('GivenTheReleaseHasNoCover_WhenTheScreenShows_ThenItSaysThereIsNone', (tester) async {
    final harness = harnessFor();

    await openScreen(tester, harness, {AutofillField.cover, AutofillField.artist});

    expect(find.text('This release has no cover on the Cover Art Archive.'), findsOneWidget);
    expect(find.text('The cover could not be downloaded from the Cover Art Archive.'), findsNothing);
  });

  testWidgets('GivenTheOwnerWrites_WhenItFinishes_ThenTheSummarySaysHowManyAndNamesTheRefused', (tester) async {
    final harness = harnessFor();
    harness.tagWriter.refusals[record.first.file.path] = WriteOutcome.inUse;
    await openScreen(tester, harness, {AutofillField.artist});

    await tester.tap(find.text('Write 2 changes to 2 files'));
    await tester.pumpAndSettle();

    expect(find.text('1 file updated.'), findsOneWidget);
    expect(find.textContaining('In use by playback'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('GivenAFlacWhoseTagIsRefused_WhenWritten_ThenTheSummarySaysItsTagsCannotBeChangedSafely', (tester) async {
    final harness = harnessFor();
    harness.tagWriter.refusals[record.first.file.path] = WriteOutcome.unsupported;
    await openScreen(tester, harness, {AutofillField.artist});

    await tester.tap(find.text('Write 2 changes to 2 files'));
    await tester.pumpAndSettle();

    expect(find.text("Orpheus can't safely change this file's tags"), findsOneWidget);
    expect(find.text("Orpheus can't change this kind of file"), findsNothing);
  });

  testWidgets('GivenMusicBrainzCannotBeReached_WhenTheScreenShows_ThenItSaysSoAndOffersToTryAgain', (tester) async {
    final harness = harnessFor();
    harness.metadata.failure = MetadataSourceFailure.unreachable;

    await openScreen(tester, harness, {AutofillField.artist});

    expect(find.text('MusicBrainz could not be reached.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('GivenOtherCandidates_WhenTheOwnerPicksOne_ThenTheProposalsFollowIt', (tester) async {
    final harness = harnessFor();
    await openScreen(tester, harness, {AutofillField.album});

    await tester.tap(find.text('Different release'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('OK Computer (Remastered)').last);
    await tester.pumpAndSettle();

    expect(harness.metadata.lookedUp.last, 'rel-2');
    expect(find.text('Write 2 changes to 2 files'), findsOneWidget);
  });

  testWidgets('GivenTheOwnerRefusesWriteAccess_WhenTheyWrite_ThenTheRefusalIsShownWithoutASettingsButton', (tester) async {
    final access = FakeLibraryAccess()..writeDecision = LibraryAccessDecision.denied;
    final harness = harnessFor(access: access);
    await openScreen(tester, harness, {AutofillField.artist});

    await tester.tap(find.text('Write 2 changes to 2 files'));
    await tester.pumpAndSettle();

    expect(find.textContaining('needs permission to change your music files'), findsOneWidget);
    expect(find.text('Open settings'), findsNothing);
    expect(harness.tagWriter.writes, isEmpty);
  });

  testWidgets('GivenAPermanentRefusal_WhenTheOwnerTapsOpenSettings_ThenTheSystemSettingsOpen', (tester) async {
    final access = FakeLibraryAccess()..writeDecision = LibraryAccessDecision.deniedPermanently;
    final harness = harnessFor(access: access);
    await openScreen(tester, harness, {AutofillField.artist});

    await tester.tap(find.text('Write 2 changes to 2 files'));
    await tester.pumpAndSettle();
    expect(find.text('Open settings'), findsOneWidget);
    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();

    expect(access.openedSettings, isTrue);
  });

  testWidgets('GivenAnAutoBuiltQuery_WhenTheScreenShows_ThenTheFieldHoldsIt', (tester) async {
    final harness = harnessFor();

    await openScreen(tester, harness, {AutofillField.artist});

    expect(tester.widget<TextField>(find.byType(TextField)).controller?.text, 'OK Computer Radiohed');
  });

  testWidgets('GivenTypedWords_WhenAnotherReleaseIsChosen_ThenTheTypedTextStays', (tester) async {
    final harness = harnessFor();
    await openScreen(tester, harness, {AutofillField.album});

    await tester.enterText(find.byType(TextField), 'my own words');
    await tester.tap(find.text('Different release'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('OK Computer (Remastered)').last);
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(find.byType(TextField)).controller?.text, 'my own words');
  });

  testWidgets('GivenTypedWords_WhenTheFieldIsSubmitted_ThenTheTypedWordsAreSearched', (tester) async {
    final harness = harnessFor();
    await openScreen(tester, harness, {AutofillField.artist});

    await tester.enterText(find.byType(TextField), 'kid a radiohead');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(harness.metadata.releaseQueries.last.text, 'kid a radiohead');
  });

  testWidgets('GivenTypedWords_WhenSearchAgainIsTapped_ThenTheTypedWordsAreSearched', (tester) async {
    final harness = harnessFor();
    await openScreen(tester, harness, {AutofillField.artist});

    await tester.enterText(find.byType(TextField), 'amnesiac');
    await tester.tap(find.text('Search again'));
    await tester.pumpAndSettle();

    expect(harness.metadata.releaseQueries.last.text, 'amnesiac');
  });

  testWidgets('GivenALookupThatFailed_WhenTryAgainIsTappedAndItWorks_ThenTheReviewAppearsFromTheOriginalLookup', (tester) async {
    final harness = harnessFor();
    harness.metadata.failure = MetadataSourceFailure.unreachable;
    await openScreen(tester, harness, {AutofillField.artist});
    expect(find.text('MusicBrainz could not be reached.'), findsOneWidget);

    harness.metadata.failure = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(harness.metadata.releaseQueries.last.text, isNull);
    expect(find.text('Write 2 changes to 2 files'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller?.text, 'OK Computer Radiohed');
  });

  testWidgets('GivenATypedSearchThatFailed_WhenTryAgainIsTapped_ThenTheTypedWordsAreSearchedAgainAndStay', (tester) async {
    final harness = harnessFor();
    await openScreen(tester, harness, {AutofillField.artist});

    harness.metadata.failure = MetadataSourceFailure.unreachable;
    await tester.enterText(find.byType(TextField), 'kid a radiohead');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('MusicBrainz could not be reached.'), findsOneWidget);

    harness.metadata.failure = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(harness.metadata.releaseQueries.last.text, 'kid a radiohead');
    expect(tester.widget<TextField>(find.byType(TextField)).controller?.text, 'kid a radiohead');
  });

  testWidgets('GivenALongReleaseAndTrackOnAPhone_WhenReviewedAndWritten_ThenNothingOverflows', (tester) async {
    final harness = harnessFor();
    const long = ReleaseCandidate(
      id: 'rel-1',
      title: 'OK Computer: the deluxe collectors anniversary edition with every bonus disc',
      artistCredit: [ArtistCredit(name: 'Radiohead')],
      trackCount: 2,
      date: '1997',
      country: 'XW',
      format: 'Digital Media',
      disambiguation: 'a very long note about a remaster that goes on and on and on',
    );
    harness.metadata
      ..candidates = const [long, other]
      ..releases = {
        'rel-1': const ReleaseDetail(
          release: long,
          tracks: [
            ReleaseTrack(
              disc: 1,
              position: 1,
              title: 'Airbag (a track title long enough to wrap onto several lines of a phone)',
              artistCredit: [ArtistCredit(name: 'Radiohead')],
            ),
            ReleaseTrack(disc: 1, position: 2, title: 'Paranoid Android', artistCredit: [ArtistCredit(name: 'Radiohead')]),
          ],
        ),
        'rel-2': detailOf(other),
      };

    await tester.pumpHarness(
      harness,
      AutofillScreen(entries: record, fields: const {AutofillField.title, AutofillField.album}, kind: AutofillKind.record),
      window: const Size(360, 740),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Write '), findsWidgets);
    expect(tester.takeException(), isNull);

    harness.tagWriter.refusals[record.first.file.path] = WriteOutcome.inUse;
    await tester.tap(find.textContaining('Write ').last);
    await tester.pumpAndSettle();
    expect(find.text('Close'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('GivenTheOwnerCancelsMidWrite_WhenItFinishes_ThenTheFileNeverReachedIsNamedAsNotWritten', (tester) async {
    final harness = harnessFor();
    await openScreen(tester, harness, {AutofillField.artist});
    final held = Completer<void>();
    harness.tagWriter.hold = held.future;

    await tester.tap(find.text('Write 2 changes to 2 files'));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('Cancel'));
    held.complete();
    await tester.pumpAndSettle();

    expect(find.text('1 file updated.'), findsOneWidget);
    expect(find.text('Not written — cancelled first'), findsOneWidget);
    expect(find.text(record[1].file.name), findsOneWidget);
  });
}
