import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/core/settings/in_memory_settings_store.dart';
import 'package:orpheus/features/autofill/application/autofill_controller.dart';
import 'package:orpheus/features/autofill/domain/autofill_field.dart';
import 'package:orpheus/features/autofill/domain/metadata_source.dart';
import 'package:orpheus/features/autofill/domain/release.dart';
import 'package:orpheus/features/autofill/domain/tag_writer.dart';
import 'package:orpheus/features/autofill/presentation/autofill_screen.dart';
import 'package:orpheus/features/library/domain/library_scan.dart';
import 'package:orpheus/features/library/domain/music_catalog.dart';
import 'package:orpheus/features/library/domain/music_grouping.dart';

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

    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();

    expect(find.text('Write 1 change to 1 file'), findsOneWidget);
  });

  testWidgets('GivenEveryChangeUnticked_WhenTheScreenShows_ThenWritingIsDisabled', (tester) async {
    final harness = harnessFor();
    await openScreen(tester, harness, {AutofillField.artist});

    await tester.tap(find.text('Untick all'));
    await tester.pump();

    final button = tester.widget<FilledButton>(find.ancestor(of: find.textContaining('Write'), matching: find.byType(FilledButton)));
    expect(button.onPressed, isNull);
  });

  testWidgets('GivenAnUnwritableFile_WhenTheScreenShows_ThenItIsNamedWithTheReasonAndHasNoCheckbox', (tester) async {
    final harness = harnessFor();
    harness.tagWriter.files[record.first.file.path] = FileTags.unwritable;

    await openScreen(tester, harness, {AutofillField.artist});

    expect(find.text("Orpheus can't change this kind of file"), findsOneWidget);
    expect(find.byType(Checkbox), findsNWidgets(1));
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
}
