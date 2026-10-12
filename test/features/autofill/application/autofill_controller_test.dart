import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/core/di/providers.dart';
import 'package:orpheus/core/settings/in_memory_settings_store.dart';
import 'package:orpheus/features/autofill/application/autofill_controller.dart';
import 'package:orpheus/features/autofill/domain/autofill_field.dart';
import 'package:orpheus/features/autofill/domain/metadata_source.dart';
import 'package:orpheus/features/autofill/domain/release.dart';
import 'package:orpheus/features/autofill/domain/tag_writer.dart';
import 'package:orpheus/features/library/domain/library_access.dart';
import 'package:orpheus/features/library/domain/library_scan.dart';
import 'package:orpheus/features/library/domain/music_catalog.dart';
import 'package:orpheus/features/library/domain/music_grouping.dart';

import '../../../support/entries.dart';
import '../../../support/fakes.dart';
import '../../../support/test_container.dart';

/// Search, review, write, rescan — with every edge doubled.
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

  ScriptedScanner completingScanner() => ScriptedScanner([
    ScanCompleted(
      catalog: MusicCatalog(entries: albumArtistsAcross(record)),
      report: const ScanReport(tracks: 2, added: 0, updated: 2, removed: 0, reused: 0),
    ),
  ]);

  AutofillController controllerOf(Harness harness) {
    // Kept alive for the test, as the review screen keeps it alive.
    harness.container.listen(autofillControllerProvider, (_, _) {});

    return harness.read(autofillControllerProvider.notifier);
  }

  AutofillState stateOf(Harness harness) => harness.read(autofillControllerProvider);

  test('GivenARecord_WhenAnAutofillStarts_ThenTheBestReleaseIsChosenAndOnlyRealChangesAreProposed', () async {
    final harness = harnessFor();

    await controllerOf(harness).start(record, {AutofillField.artist}, kind: AutofillKind.record);

    final state = stateOf(harness);
    expect(state.stage, AutofillStage.reviewing);
    expect(state.release?.release.id, 'rel-1');
    expect(harness.metadata.lookedUp, ['rel-1']);
    expect(state.acceptedCount, 2);
    expect(state.filesWithChanges, 2);
    expect(state.query, 'OK Computer Radiohed');
  });

  test('GivenTheOwnerPicksAnotherRelease_WhenItIsChosen_ThenItIsFetchedAndTheProposalsRebuilt', () async {
    final harness = harnessFor();
    final controller = controllerOf(harness);
    await controller.start(record, {AutofillField.album}, kind: AutofillKind.record);
    expect(stateOf(harness).acceptedCount, 0);

    await controller.chooseRelease('rel-2');

    expect(stateOf(harness).release?.release.id, 'rel-2');
    expect(stateOf(harness).acceptedCount, 2);
  });

  test('GivenTheOwnerUnticksAChange_WhenTheyWrite_ThenOnlyTheTickedOnesAreWrittenAndTheLibraryRescanned', () async {
    final harness = harnessFor();
    final controller = controllerOf(harness);
    await controller.start(record, {AutofillField.artist}, kind: AutofillKind.record);
    controller.toggle(record.first.file.path, AutofillField.artist);

    await controller.write();

    expect(harness.tagWriter.writes, hasLength(1));
    expect(harness.tagWriter.writes.single.$1, record[1].file.path);
    expect(harness.tagWriter.writes.single.$2, {AutofillField.artist: 'Radiohead'});
    expect(stateOf(harness).stage, AutofillStage.finished);
    expect(stateOf(harness).outcomes[record[1].file.path], WriteOutcome.written);
  });

  test('GivenNoNetwork_WhenAnAutofillStarts_ThenItFailsAsUnreachable', () async {
    final harness = harnessFor();
    harness.metadata.failure = MetadataSourceFailure.unreachable;

    await controllerOf(harness).start(record, {AutofillField.artist}, kind: AutofillKind.record);

    expect(stateOf(harness).stage, AutofillStage.failed);
    expect(stateOf(harness).failure, MetadataSourceFailure.unreachable);
  });

  test('GivenNothingIsFound_WhenAnAutofillStarts_ThenItReviewsNothingWithTheQueryEditable', () async {
    final harness = harnessFor();
    harness.metadata.candidates = const [];

    await controllerOf(harness).start(record, {AutofillField.artist}, kind: AutofillKind.record);

    expect(stateOf(harness).stage, AutofillStage.reviewing);
    expect(stateOf(harness).release, isNull);
    expect(stateOf(harness).candidates, isEmpty);
  });

  test('GivenTheOwnersOwnWords_WhenTheySearchAgain_ThenTheirWordsAreSent', () async {
    final harness = harnessFor();
    final controller = controllerOf(harness);
    await controller.start(record, {AutofillField.artist}, kind: AutofillKind.record);

    await controller.search('radiohead ok computer');

    expect(harness.metadata.releaseQueries.last.text, 'radiohead ok computer');
  });

  test('GivenTheOwnerRefusesWriteAccess_WhenTheyWrite_ThenNothingIsWrittenAndTheRefusalIsShown', () async {
    final access = FakeLibraryAccess()..writeDecision = LibraryAccessDecision.denied;
    final harness = harnessFor(access: access);
    final controller = controllerOf(harness);
    await controller.start(record, {AutofillField.artist}, kind: AutofillKind.record);

    await controller.write();

    expect(harness.tagWriter.writes, isEmpty);
    expect(stateOf(harness).stage, AutofillStage.reviewing);
    expect(stateOf(harness).refusal, LibraryAccessDecision.denied);
  });

  test('GivenOneFileIsRefused_WhenWritten_ThenTheOthersAreWrittenAndItCanBeRetried', () async {
    final harness = harnessFor();
    harness.tagWriter.refusals[record.first.file.path] = WriteOutcome.inUse;
    final controller = controllerOf(harness);
    await controller.start(record, {AutofillField.artist}, kind: AutofillKind.record);

    await controller.write();
    expect(stateOf(harness).outcomes[record.first.file.path], WriteOutcome.inUse);
    expect(stateOf(harness).outcomes[record[1].file.path], WriteOutcome.written);

    harness.tagWriter.refusals.clear();
    await controller.retry();

    expect(stateOf(harness).outcomes[record.first.file.path], WriteOutcome.written);
    expect(harness.tagWriter.writes, hasLength(2));
  });

  test('GivenTheCoverIsChosen_WhenTheReleaseHasOne_ThenItIsFetchedOnceAndProposedForEveryFile', () async {
    final harness = harnessFor();
    harness.metadata.covers = {'rel-1': Uint8List.fromList([9, 9])};

    await controllerOf(harness).start(record, {AutofillField.cover}, kind: AutofillKind.record);

    expect(harness.metadata.coversFetched, ['rel-1']);
    expect(stateOf(harness).acceptedCount, 2);
  });

  test('GivenTheCoverWillNotDownload_WhenProposed_ThenTheOtherChangesStandAndTheOwnerIsTold', () async {
    final harness = harnessFor();
    final controller = controllerOf(harness);
    harness.metadata.covers = const {};

    await controller.start(record, {AutofillField.cover, AutofillField.artist}, kind: AutofillKind.record);

    expect(stateOf(harness).coverMissing, isTrue);
    expect(stateOf(harness).acceptedCount, 2);
  });

  test('GivenTheOwnerClosesTheScreenMidLookup_WhenTheAnswerArrives_ThenNothingThrows', () async {
    // Review focus: an auto-disposed controller must not write state after
    // it is gone.
    final harness = harnessFor();
    final held = Completer<void>();
    harness.metadata.hold = held.future;
    final subscription = harness.container.listen(autofillControllerProvider, (_, _) {});
    final controller = harness.read(autofillControllerProvider.notifier);

    final started = controller.start(record, {AutofillField.artist}, kind: AutofillKind.record);
    subscription.close();
    await pumpEventQueue();
    expect(harness.container.exists(autofillControllerProvider), isFalse);
    held.complete();

    await expectLater(started, completes);
  });

  test('GivenTheOwnerClosesTheScreenMidRelease_WhenTheAnswerArrives_ThenNothingThrows', () async {
    final harness = harnessFor();
    final subscription = harness.container.listen(autofillControllerProvider, (_, _) {});
    final controller = harness.read(autofillControllerProvider.notifier);
    await controller.start(record, {AutofillField.artist}, kind: AutofillKind.record);
    final held = Completer<void>();
    harness.metadata.hold = held.future;

    final chosen = controller.chooseRelease('rel-2');
    await pumpEventQueue();
    subscription.close();
    await pumpEventQueue();
    expect(harness.container.exists(autofillControllerProvider), isFalse);
    held.complete();

    await expectLater(chosen, completes);
  });

  test('GivenTheOwnerClosesTheScreenMidWrite_WhenTheWriteArrives_ThenEveryConfirmedFileIsWrittenAndTheLibraryRescanned', () async {
    final scanner = completingScanner();
    final harness = harnessFor(scanner: scanner);
    final subscription = harness.container.listen(autofillControllerProvider, (_, _) {});
    final controller = harness.read(autofillControllerProvider.notifier);
    await controller.start(record, {AutofillField.artist}, kind: AutofillKind.record);
    final held = Completer<void>();
    harness.tagWriter.hold = held.future;

    final writing = controller.write();
    await pumpEventQueue();
    subscription.close();
    await pumpEventQueue();
    expect(harness.container.exists(autofillControllerProvider), isFalse);
    held.complete();

    await expectLater(writing, completes);
    await pumpEventQueue();
    expect(harness.tagWriter.writes.map((w) => w.$1), [record[0].file.path, record[1].file.path]);
    expect(scanner.requests, hasLength(1));
  });

  test('GivenATrackIsPlaying_WhenTheOwnerWrites_ThenItIsWrittenLast', () async {
    final harness = harnessFor();
    final controller = controllerOf(harness);
    await controller.start(record, {AutofillField.artist}, kind: AutofillKind.record);
    await harness.read(audioPlaybackControllerProvider.notifier).playTrack(record.first.file);

    await controller.write();

    expect(harness.tagWriter.writes.map((w) => w.$1), [record[1].file.path, record[0].file.path]);
  });

  test('GivenEveryWriteIsRefused_WhenTheyFinish_ThenNoRescanIsRequested', () async {
    final scanner = completingScanner();
    final harness = harnessFor(scanner: scanner);
    for (final e in record) {
      harness.tagWriter.refusals[e.file.path] = WriteOutcome.inUse;
    }
    final controller = controllerOf(harness);
    await controller.start(record, {AutofillField.artist}, kind: AutofillKind.record);

    await controller.write();
    await pumpEventQueue();

    expect(stateOf(harness).stage, AutofillStage.finished);
    expect(harness.tagWriter.writes, isEmpty);
    expect(scanner.requests, isEmpty);
  });

  test('GivenTheOwnerCancels_WhenTheFileBeingWrittenFinishes_ThenTheRestAreLeftAndTheLibraryIsRescanned', () async {
    final scanner = completingScanner();
    final harness = harnessFor(scanner: scanner);
    final controller = controllerOf(harness);
    await controller.start(record, {AutofillField.artist}, kind: AutofillKind.record);
    final held = Completer<void>();
    harness.tagWriter.hold = held.future;

    final writing = controller.write();
    await pumpEventQueue();
    controller.cancel();
    held.complete();
    await writing;
    await pumpEventQueue();

    expect(harness.tagWriter.writes, hasLength(1));
    expect(stateOf(harness).stage, AutofillStage.finished);
    expect(scanner.requests, hasLength(1));
  });

  test('GivenAChoiceOfFields_WhenAnAutofillStarts_ThenItIsRememberedForTheNextOne', () async {
    final harness = harnessFor();

    await controllerOf(harness).start(record, {AutofillField.genre, AutofillField.cover}, kind: AutofillKind.record);

    expect(
      AutofillField.decode(harness.settings.getString(AutofillController.fieldsSettingsKey)),
      {AutofillField.genre, AutofillField.cover},
    );
  });

  test('GivenWritesFinish_WhenTheyDo_ThenTheLibraryIsRescanned', () async {
    final scanner = ScriptedScanner([
      ScanCompleted(
        catalog: MusicCatalog(entries: albumArtistsAcross(record)),
        report: const ScanReport(tracks: 2, added: 0, updated: 2, removed: 0, reused: 0),
      ),
    ]);
    final harness = harnessFor(scanner: scanner);
    final controller = controllerOf(harness);
    await controller.start(record, {AutofillField.artist}, kind: AutofillKind.record);

    await controller.write();
    await Future<void>.delayed(Duration.zero);

    expect(scanner.requests, hasLength(1));
  });
}
