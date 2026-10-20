import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/core/di/providers.dart';
import 'package:orpheus/core/settings/in_memory_settings_store.dart';
import 'package:orpheus/features/autofill/application/autofill_controller.dart';
import 'package:orpheus/features/autofill/application/batch_autofill_controller.dart';
import 'package:orpheus/features/autofill/domain/autofill_field.dart';
import 'package:orpheus/features/autofill/domain/batch_plan.dart';
import 'package:orpheus/features/autofill/domain/confidence.dart';
import 'package:orpheus/features/autofill/domain/metadata_source.dart';
import 'package:orpheus/features/autofill/domain/release.dart';
import 'package:orpheus/features/autofill/domain/tag_writer.dart';
import 'package:orpheus/features/library/domain/audio_file.dart';
import 'package:orpheus/features/library/domain/library_access.dart';
import 'package:orpheus/features/library/domain/library_scan.dart';
import 'package:orpheus/features/library/domain/music_catalog.dart';
import 'package:orpheus/features/library/domain/music_entry.dart';
import 'package:orpheus/features/library/domain/music_grouping.dart';
import 'package:orpheus/features/library/domain/track_metadata.dart';

import '../../../support/entries.dart';
import '../../../support/fake_autofill.dart';
import '../../../support/fakes.dart';
import '../../../support/test_container.dart';

/// A batch walked one record at a time — written where sure, kept where not,
/// paused where MusicBrainz cannot be reached — with every edge doubled.
void main() {
  const radiohead = [ArtistCredit(name: 'Radiohead')];

  /// [count] songs of the album [name], each titled as MusicBrainz titles it
  /// and numbered, in a folder of their own.
  List<MusicEntry> albumOf(String name, {int count = 2}) => [
    for (var n = 1; n <= count; n++)
      entry(
        id: '$name-$n',
        title: '$name $n',
        artist: 'Radiohead',
        albumArtist: 'Radiohead',
        album: name,
        track: n,
        directory: '/library/$name',
      ),
  ];

  /// The official release of [name] with [count] tracks, as a search answers
  /// it.
  ReleaseCandidate releaseOf(
    String name, {
    int count = 2,
    String status = 'Official',
    String? id,
  }) => ReleaseCandidate(
    id: id ?? 'rel-$name',
    title: name,
    artistCredit: radiohead,
    trackCount: count,
    status: status,
  );

  ReleaseDetail detailOf(ReleaseCandidate release, String name) =>
      ReleaseDetail(
        release: release,
        tracks: [
          for (var n = 1; n <= release.trackCount; n++)
            ReleaseTrack(
              disc: 1,
              position: n,
              title: '$name $n',
              artistCredit: radiohead,
            ),
        ],
      );

  /// What one album's songs say before the batch: an artist one letter off,
  /// which the release corrects.
  FileTags misspelt(MusicEntry song) => FileTags(
    writable: AutofillField.values.toSet(),
    values: {
      AutofillField.title: song.title,
      AutofillField.artist: 'Radiohed',
      AutofillField.album: song.album,
    },
  );

  ScriptedScanner scannerOver(List<MusicEntry> library) => ScriptedScanner([
    ScanCompleted(
      catalog: MusicCatalog(entries: albumArtistsAcross(library)),
      report: ScanReport(
        tracks: library.length,
        added: 0,
        updated: library.length,
        removed: 0,
        reused: 0,
      ),
    ),
  ]);

  /// A harness over [library], whose every album MusicBrainz knows as its
  /// official release under [releases], and whose every song is misspelt.
  Harness harnessFor(
    List<MusicEntry> library, {
    Map<String, ReleaseCandidate>? releases,
    FakeLibraryAccess? access,
    ScriptedScanner? scanner,
    FakeTagWriter? tagWriter,
    DateTime Function()? clock,
  }) {
    final harness = Harness(
      library: library,
      access: access,
      tagWriter: tagWriter,
      // Never the real scanner: a write rescans, and the rescan must not walk
      // the disk.
      scanner: scanner ?? scannerOver(library),
      settings: InMemorySettingsStore(libraryFolders: const ['/music']),
      overrides: [if (clock != null) clockProvider.overrideWithValue(clock)],
    );

    final albums = {for (final song in library) ?song.album};
    final byAlbum =
        releases ??
        {
          for (final album in albums)
            album: releaseOf(
              album,
              count: library.where((s) => s.album == album).length,
            ),
        };
    harness.metadata
      ..candidatesFor = ((query) => [?byAlbum[query.album]])
      ..releases = {
        for (final MapEntry(key: album, value: release) in byAlbum.entries)
          release.id: detailOf(release, album),
      };
    for (final song in library) {
      harness.tagWriter.files[song.file.path] = misspelt(song);
    }

    // A write starts a rescan and does not wait for it. Let it finish before
    // the container goes (teardowns run last-registered first).
    addTearDown(pumpEventQueue);

    return harness;
  }

  BatchAutofillController controllerOf(Harness harness) =>
      harness.read(batchAutofillControllerProvider.notifier);

  BatchAutofillState stateOf(Harness harness) =>
      harness.read(batchAutofillControllerProvider);

  /// Starts [plan] and waits for the run to stop, finished or paused.
  Future<void> run(
    Harness harness,
    BatchPlan plan, {
    Set<AutofillField> fields = const {AutofillField.artist},
  }) async {
    final controller = controllerOf(harness);
    expect(await controller.start(plan, fields), isTrue);
    await controller.settled;
  }

  List<String> writtenPaths(Harness harness) => [
    for (final (path, _) in harness.tagWriter.writes) path,
  ];

  List<String?> albumsSearched(Harness harness) => [
    for (final query in harness.metadata.releaseQueries) query.album,
  ];

  const artistAndCover = {AutofillField.artist, AutofillField.cover};
  final oldCover = Uint8List.fromList([9, 9, 9]);
  final newCover = Uint8List.fromList([1, 2, 3]);

  /// [tags] with [oldCover] embedded, which a chosen cover replaces.
  FileTags withOldCover(FileTags tags) =>
      FileTags(writable: tags.writable, values: tags.values, cover: oldCover);

  /// Every picture [outcome] still holds on to, old or new.
  List<Uint8List> coverBytesIn(UnitOutcome outcome) => [
    for (final proposal in outcome.proposals)
      for (final change in proposal.changes)
        for (final value in [change.before, change.after])
          if (value is Uint8List) value,
  ];

  test(
    'GivenAConfidentAndADoubtfulRecord_WhenRun_ThenOnlyTheConfidentIsWritten',
    () async {
      final alpha = albumOf('Alpha');
      final beta = albumOf('Beta');
      final library = [...alpha, ...beta];
      final harness = harnessFor(
        library,
        releases: {
          'Alpha': releaseOf('Alpha'),
          'Beta': releaseOf('Beta', status: 'Bootleg'),
        },
      );

      await run(harness, planBatch(library, library));

      final state = stateOf(harness);
      expect(state.stage, BatchStage.finished);
      expect(writtenPaths(harness), [for (final song in alpha) song.file.path]);
      expect(harness.tagWriter.writes.first.$2, {
        AutofillField.artist: 'Radiohead',
      });
      expect(state.outcomes.map((o) => o.kind), [
        UnitOutcomeKind.updated,
        UnitOutcomeKind.doubtful,
      ]);
      expect(state.outcomes[1].doubt?.reason, DoubtReason.notOfficial);
      expect(state.outcomes[1].release?.id, 'rel-Beta');
      expect(state.outcomes[1].proposals, isEmpty);
      expect(state.updated, 1);
      expect(state.needYou, 1);
      expect(state.done, 2);
    },
  );

  test('GivenNothingWouldChange_WhenRun_ThenAlreadyRightAndNoWrite', () async {
    final alpha = albumOf('Alpha');
    final harness = harnessFor(alpha);
    for (final song in alpha) {
      harness.tagWriter.files[song.file.path] = FileTags(
        writable: AutofillField.values.toSet(),
        values: {AutofillField.artist: 'Radiohead'},
      );
    }

    await run(harness, planBatch(alpha, alpha));

    expect(harness.tagWriter.writes, isEmpty);
    expect(stateOf(harness).outcomes.single.kind, UnitOutcomeKind.alreadyRight);
    expect(stateOf(harness).alreadyRight, 1);
  });

  test('GivenNoCandidates_WhenRun_ThenNotFound', () async {
    final alpha = albumOf('Alpha');
    final harness = harnessFor(alpha, releases: const {});

    await run(harness, planBatch(alpha, alpha));

    expect(harness.tagWriter.writes, isEmpty);
    expect(harness.metadata.lookedUp, isEmpty);
    expect(stateOf(harness).outcomes.single.kind, UnitOutcomeKind.notFound);
    expect(stateOf(harness).notFound, 1);
  });

  test('GivenAPartialRecord_WhenRun_ThenOnlyItsBatchSongsAreWritten', () async {
    final album = albumOf('Alpha', count: 3);
    final single = releaseOf('Alpha', id: 'single');
    final full = releaseOf('Alpha', count: 3, id: 'full');
    final harness = harnessFor(album);
    harness.metadata
      ..candidatesFor = ((_) => [single, full])
      ..releases = {
        'single': detailOf(single, 'Alpha'),
        'full': detailOf(full, 'Alpha'),
      };
    final batch = album.take(2).toList();

    await run(harness, planBatch(batch, album));

    expect(harness.metadata.lookedUp, ['full']);
    expect(writtenPaths(harness), [for (final s in batch) s.file.path]);
    expect(stateOf(harness).outcomes.single.kind, UnitOutcomeKind.updated);
  });

  test(
    'GivenAccessRefused_WhenStarted_ThenNothingIsLookedUpAndRefusalIsKept',
    () async {
      final alpha = albumOf('Alpha');
      final access = FakeLibraryAccess()
        ..writeDecision = LibraryAccessDecision.denied;
      final harness = harnessFor(alpha, access: access);
      final controller = controllerOf(harness);

      final started = await controller.start(planBatch(alpha, alpha), const {
        AutofillField.artist,
      });
      await controller.settled;

      expect(started, isFalse);
      expect(access.writeRequests, 1);
      expect(harness.metadata.releaseQueries, isEmpty);
      expect(harness.tagWriter.writes, isEmpty);
      expect(stateOf(harness).stage, BatchStage.idle);
      expect(stateOf(harness).refusal, LibraryAccessDecision.denied);
    },
  );

  test('GivenAFinishedBatchWithDoubtful_WhenAStartIsRefused_ThenItStaysWithTheRefusal', () async {
    final alpha = albumOf('Alpha');
    final beta = albumOf('Beta');
    final access = FakeLibraryAccess();
    final harness = harnessFor(
      [...alpha, ...beta],
      access: access,
      releases: {
        'Alpha': releaseOf('Alpha', status: 'Bootleg'),
        'Beta': releaseOf('Beta'),
      },
    );
    final first = planBatch(alpha, alpha);
    await run(harness, first);
    access.writeDecision = LibraryAccessDecision.deniedPermanently;

    final started = await controllerOf(harness)
        .start(planBatch(beta, beta), const {AutofillField.artist});

    final state = stateOf(harness);
    expect(started, isFalse);
    expect(state.refusal, LibraryAccessDecision.deniedPermanently);
    expect(state.stage, BatchStage.finished);
    expect(state.plan, same(first));
    expect(state.needYou, 1);
    expect(albumsSearched(harness), ['Alpha']);
  });

  test(
    'GivenStop_WhenAUnitIsBeingWritten_ThenItFinishesAndTheRestAreNotLookedUp',
    () async {
      final alpha = albumOf('Alpha');
      final library = [...alpha, ...albumOf('Beta'), ...albumOf('Gamma')];
      final harness = harnessFor(library);
      final held = Completer<void>();
      harness.tagWriter.hold = held.future;
      final controller = controllerOf(harness);

      expect(
        await controller.start(planBatch(library, library), const {
          AutofillField.artist,
        }),
        isTrue,
      );
      await pumpEventQueue();
      controller.stop();
      held.complete();
      await controller.settled;

      final state = stateOf(harness);
      expect(writtenPaths(harness), [for (final s in alpha) s.file.path]);
      expect(albumsSearched(harness), ['Alpha']);
      expect(state.stage, BatchStage.finished);
      expect(state.stoppedEarly, isTrue);
      expect(state.outcomes.map((o) => o.kind), [
        UnitOutcomeKind.updated,
        UnitOutcomeKind.notLookedUp,
        UnitOutcomeKind.notLookedUp,
      ]);
    },
  );

  test(
    'GivenARunningBatch_WhenStopped_ThenItIsStoppingUntilTheUnitInFlightEnds',
    () async {
      final library = [...albumOf('Alpha'), ...albumOf('Beta')];
      final harness = harnessFor(library);
      final held = Completer<void>();
      harness.tagWriter.hold = held.future;
      final controller = controllerOf(harness);
      expect(
        await controller.start(planBatch(library, library), const {
          AutofillField.artist,
        }),
        isTrue,
      );
      await pumpEventQueue();
      expect(stateOf(harness).stopping, isFalse);

      controller.stop();

      expect(stateOf(harness).stage, BatchStage.running);
      expect(stateOf(harness).stopping, isTrue);
      held.complete();
      await controller.settled;
      expect(stateOf(harness).stage, BatchStage.finished);
      expect(stateOf(harness).stopping, isFalse);
    },
  );

  test('GivenOneUnreachable_WhenRun_ThenRetriedAfterTheNextUnit', () async {
    final library = [
      ...albumOf('Alpha'),
      ...albumOf('Beta'),
      ...albumOf('Gamma'),
    ];
    final harness = harnessFor(library);
    harness.metadata.failures.add(MetadataSourceFailure.unreachable);

    await run(harness, planBatch(library, library));

    expect(albumsSearched(harness), ['Alpha', 'Beta', 'Alpha', 'Gamma']);
    expect(
      stateOf(harness).outcomes.map((o) => o.kind),
      everyElement(UnitOutcomeKind.updated),
    );
    expect(stateOf(harness).outcomes.map((o) => o.unit.songs.first.album), [
      'Alpha',
      'Beta',
      'Gamma',
    ]);
  });

  test(
    'GivenAUnitUnreachableTwice_WhenRun_ThenItCouldNotBeLookedUpAndTheRestRun',
    () async {
      final library = [
        ...albumOf('Alpha'),
        ...albumOf('Beta'),
        ...albumOf('Gamma'),
      ];
      final harness = harnessFor(library);
      harness.metadata.failures.addAll([
        MetadataSourceFailure.rateLimited,
        null,
        MetadataSourceFailure.unreachable,
      ]);

      await run(harness, planBatch(library, library));

      expect(albumsSearched(harness), ['Alpha', 'Beta', 'Alpha', 'Gamma']);
      expect(stateOf(harness).stage, BatchStage.finished);
      expect(stateOf(harness).outcomes.map((o) => o.kind), [
        UnitOutcomeKind.unreachable,
        UnitOutcomeKind.updated,
        UnitOutcomeKind.updated,
      ]);
    },
  );

  test('GivenThreeUnreachableInARow_WhenRun_ThenPausedAtTheThird', () async {
    final library = [
      ...albumOf('Alpha'),
      ...albumOf('Beta'),
      ...albumOf('Gamma'),
      ...albumOf('Delta'),
    ];
    final harness = harnessFor(library);
    harness.metadata.failures.addAll([
      MetadataSourceFailure.unreachable,
      MetadataSourceFailure.unreachable,
      MetadataSourceFailure.unreachable,
    ]);

    await run(harness, planBatch(library, library));

    final state = stateOf(harness);
    expect(state.stage, BatchStage.paused);
    expect(albumsSearched(harness), ['Alpha', 'Beta', 'Alpha']);
    expect(harness.tagWriter.writes, isEmpty);
    expect(state.done, 0);
    expect(state.showsIndicator, isTrue);
  });

  test(
    'GivenResumeAfterPause_WhenRun_ThenContinuesAndRewritesNothingWritten',
    () async {
      final library = [
        ...albumOf('Alpha'),
        ...albumOf('Beta'),
        ...albumOf('Delta'),
        ...albumOf('Gamma'),
      ];
      final harness = harnessFor(library);
      harness.metadata.failures.addAll([
        null,
        MetadataSourceFailure.unreachable,
        MetadataSourceFailure.unreachable,
        MetadataSourceFailure.unreachable,
      ]);
      await run(harness, planBatch(library, library));
      expect(stateOf(harness).stage, BatchStage.paused);
      expect(albumsSearched(harness), ['Alpha', 'Beta', 'Delta', 'Beta']);

      await controllerOf(harness).resume();
      await controllerOf(harness).settled;

      final state = stateOf(harness);
      expect(state.stage, BatchStage.finished);
      expect(albumsSearched(harness).skip(4), ['Beta', 'Delta', 'Gamma']);
      expect(writtenPaths(harness), hasLength(library.length));
      expect(writtenPaths(harness).toSet(), hasLength(library.length));
      expect(
        state.outcomes.map((o) => o.kind),
        everyElement(UnitOutcomeKind.updated),
      );
      expect(state.done, 4);
    },
  );

  test(
    'GivenStopWhilePaused_WhenStopped_ThenFinishedWithTheRestNotLookedUp',
    () async {
      final library = [
        ...albumOf('Alpha'),
        ...albumOf('Beta'),
        ...albumOf('Gamma'),
      ];
      final harness = harnessFor(library);
      harness.metadata.failures.addAll([
        MetadataSourceFailure.unreachable,
        MetadataSourceFailure.unreachable,
        MetadataSourceFailure.unreachable,
      ]);
      await run(harness, planBatch(library, library));

      controllerOf(harness).stop();
      await controllerOf(harness).settled;

      final state = stateOf(harness);
      expect(state.stage, BatchStage.finished);
      expect(state.stoppedEarly, isTrue);
      expect(state.outcomes.map((o) => o.kind), [
        UnitOutcomeKind.unreachable,
        UnitOutcomeKind.unreachable,
        UnitOutcomeKind.notLookedUp,
      ]);
    },
  );

  test(
    'GivenStopDuringTheThirdUnreachable_WhenItComesBack_ThenFinishedNotPaused',
    () async {
      final library = [
        ...albumOf('Alpha'),
        ...albumOf('Beta'),
        ...albumOf('Gamma'),
      ];
      final harness = harnessFor(library);
      harness.metadata.failures.addAll([
        MetadataSourceFailure.unreachable,
        MetadataSourceFailure.unreachable,
        MetadataSourceFailure.unreachable,
      ]);
      // Each lookup waits for its gate, so the test lets them through one by
      // one and stops while the third is out.
      var gate = Completer<void>();
      harness.metadata.hold = gate.future;
      final controller = controllerOf(harness);
      expect(
        await controller.start(planBatch(library, library), const {
          AutofillField.artist,
        }),
        isTrue,
      );
      await pumpEventQueue();
      for (var i = 0; i < 2; i++) {
        final open = gate;
        gate = Completer<void>();
        harness.metadata.hold = gate.future;
        open.complete();
        await pumpEventQueue();
      }
      expect(albumsSearched(harness), ['Alpha', 'Beta', 'Alpha']);

      controller.stop();
      gate.complete();
      await controller.settled;

      final state = stateOf(harness);
      expect(state.stage, BatchStage.finished);
      expect(state.stoppedEarly, isTrue);
      expect(albumsSearched(harness), hasLength(3));
      expect(state.outcomes.map((o) => o.kind), [
        UnitOutcomeKind.unreachable,
        UnitOutcomeKind.unreachable,
        UnitOutcomeKind.notLookedUp,
      ]);
    },
  );

  test('GivenNoScreenWatching_WhenRun_ThenItStillFinishes', () async {
    final library = [...albumOf('Alpha'), ...albumOf('Beta')];
    final harness = harnessFor(library);

    final started = await harness.container
        .read(batchAutofillControllerProvider.notifier)
        .start(planBatch(library, library), const {AutofillField.artist});
    // Turns of the event loop with nobody listening: an auto-disposed
    // notifier would have gone by now.
    await pumpEventQueue();
    await harness.container
        .read(batchAutofillControllerProvider.notifier)
        .settled;

    expect(started, isTrue);
    expect(writtenPaths(harness), hasLength(4));
    expect(harness.container.read(batchAutofillControllerProvider).updated, 2);
    expect(
      harness.container.read(batchAutofillControllerProvider).stage,
      BatchStage.finished,
    );
  });

  test('GivenThePlayingSongInARecord_WhenWritten_ThenItIsLast', () async {
    final alpha = albumOf('Alpha', count: 3);
    final harness = harnessFor(alpha);
    await harness
        .read(audioPlaybackControllerProvider.notifier)
        .playTrack(alpha.first.file);

    await run(harness, planBatch(alpha, alpha));

    expect(writtenPaths(harness), [
      alpha[1].file.path,
      alpha[2].file.path,
      alpha[0].file.path,
    ]);
  });

  test(
    'GivenWritesOverTwoMinutes_WhenRun_ThenRescanAskedOncePerMinuteAndAtTheEnd',
    () async {
      final library = [
        ...albumOf('Alpha', count: 1),
        ...albumOf('Beta', count: 1),
        ...albumOf('Delta', count: 1),
        ...albumOf('Gamma', count: 1),
      ];
      // Half a minute passes with every file written: the four records are
      // written at 0:30, 1:00, 1:30 and 2:00.
      final writer = FakeTagWriter();
      final scanner = scannerOver(library);
      final harness = harnessFor(
        library,
        tagWriter: writer,
        scanner: scanner,
        clock: () =>
            DateTime.utc(2026)
                .add(Duration(seconds: 30 * writer.writes.length)),
      );

      await run(harness, planBatch(library, library));
      await pumpEventQueue();

      // At 0:30 (the first write), at 1:30 (a minute on), and once at the end
      // for what 2:00 wrote.
      expect(writer.writes, hasLength(4));
      expect(scanner.requests, hasLength(3));
    },
  );

  test('GivenNothingWritten_WhenRun_ThenNoRescanIsAsked', () async {
    final alpha = albumOf('Alpha');
    final scanner = scannerOver(alpha);
    final harness = harnessFor(alpha, scanner: scanner, releases: const {});

    await run(harness, planBatch(alpha, alpha));
    await pumpEventQueue();

    expect(scanner.requests, isEmpty);
  });

  test('GivenAnInUseFile_WhenRetryFailed_ThenOnlyItIsWrittenAgain', () async {
    final alpha = albumOf('Alpha');
    final harness = harnessFor(alpha);
    final busy = alpha.first.file.path;
    harness.tagWriter.refusals[busy] = WriteOutcome.inUse;
    await run(harness, planBatch(alpha, alpha));
    expect(stateOf(harness).outcomes.single.writes, {
      busy: WriteOutcome.inUse,
      alpha[1].file.path: WriteOutcome.written,
    });

    harness.tagWriter.refusals.clear();
    final controller = controllerOf(harness);
    await controller.retryFailed();
    await controller.settled;

    expect(writtenPaths(harness), [alpha[1].file.path, busy]);
    expect(stateOf(harness).outcomes.single.writes, {
      busy: WriteOutcome.written,
      alpha[1].file.path: WriteOutcome.written,
    });
  });

  test(
    'GivenAnUpdatedUnitWithACover_WhenRun_ThenItsOutcomeHoldsNoCoverBytes',
    () async {
      final alpha = albumOf('Alpha');
      final harness = harnessFor(alpha);
      harness.metadata.covers = {'rel-Alpha': newCover};
      for (final song in alpha) {
        harness.tagWriter.files[song.file.path] = withOldCover(misspelt(song));
      }

      await run(harness, planBatch(alpha, alpha), fields: artistAndCover);

      final outcome = stateOf(harness).outcomes.single;
      expect(outcome.kind, UnitOutcomeKind.updated);
      expect(harness.tagWriter.writes.first.$2[AutofillField.cover], newCover);
      expect(coverBytesIn(outcome), isEmpty);
    },
  );

  test(
    'GivenADoubtfulUnitWithACover_WhenRun_ThenItsOutcomeHoldsNoCoverBytes',
    () async {
      final alpha = albumOf('Alpha');
      final harness = harnessFor(
        alpha,
        releases: {'Alpha': releaseOf('Alpha', status: 'Bootleg')},
      );
      harness.metadata.covers = {'rel-Alpha': newCover};
      for (final song in alpha) {
        harness.tagWriter.files[song.file.path] = withOldCover(misspelt(song));
      }

      await run(harness, planBatch(alpha, alpha), fields: artistAndCover);

      final outcome = stateOf(harness).outcomes.single;
      expect(outcome.kind, UnitOutcomeKind.doubtful);
      expect(outcome.release?.id, 'rel-Alpha');
      expect(coverBytesIn(outcome), isEmpty);
    },
  );

  test(
    'GivenABlockedSongInADoubtfulRecord_WhenRun_ThenItIsStillNotWritable',
    () async {
      final alpha = albumOf('Alpha', count: 3);
      final harness = harnessFor(
        alpha,
        releases: {'Alpha': releaseOf('Alpha', count: 3, status: 'Bootleg')},
      );
      harness.tagWriter.unreadable.add(alpha[1].file.path);

      await run(harness, planBatch(alpha, alpha));

      final state = stateOf(harness);
      expect(state.outcomes.single.kind, UnitOutcomeKind.doubtful);
      expect(state.notWritableSongs.map((s) => s.file.path), [
        alpha[1].file.path,
      ]);
    },
  );

  test(
    'GivenAnInUseFileWithACover_WhenRetryFailed_ThenItIsRewrittenWithTheCover',
    () async {
      final alpha = albumOf('Alpha');
      final harness = harnessFor(alpha);
      harness.metadata.covers = {'rel-Alpha': newCover};
      for (final song in alpha) {
        harness.tagWriter.files[song.file.path] = withOldCover(misspelt(song));
      }
      final busy = alpha.first.file.path;
      harness.tagWriter.refusals[busy] = WriteOutcome.inUse;
      await run(harness, planBatch(alpha, alpha), fields: artistAndCover);
      // Only the file to write again is kept: the written one's pictures are
      // let go.
      expect(
        stateOf(harness).outcomes.single.proposals
            .map((proposal) => proposal.entry.file.path),
        [busy],
      );

      harness.tagWriter.refusals.clear();
      await controllerOf(harness).retryFailed();

      final (path, values) = harness.tagWriter.writes.last;
      expect(path, busy);
      expect(values, {
        AutofillField.artist: 'Radiohead',
        AutofillField.cover: newCover,
      });
      final outcome = stateOf(harness).outcomes.single;
      expect(outcome.writes[busy], WriteOutcome.written);
      expect(coverBytesIn(outcome), isEmpty);
    },
  );

  test('GivenANewBatchStartedMidRetry_WhenTheRetryFinishes_ThenTheNewBatchIsUntouched', () async {
    final alpha = albumOf('Alpha');
    final beta = albumOf('Beta');
    final harness = harnessFor([...alpha, ...beta]);
    final busy = alpha.first.file.path;
    harness.tagWriter.refusals[busy] = WriteOutcome.inUse;
    await run(harness, planBatch(alpha, alpha));
    harness.tagWriter.refusals.clear();
    final held = Completer<void>();
    harness.tagWriter.hold = held.future;
    final controller = controllerOf(harness);

    final retrying = controller.retryFailed();
    await pumpEventQueue();
    expect(
      await controller.start(planBatch(beta, beta), const {
        AutofillField.artist,
      }),
      isTrue,
    );
    held.complete();
    await retrying;
    await controller.settled;

    final state = stateOf(harness);
    expect(state.outcomes.single.unit.songs.first.album, 'Beta');
    expect(state.outcomes.single.writes.keys, [
      for (final s in beta) s.file.path,
    ]);
    expect(writtenPaths(harness).where((p) => p == busy), hasLength(1));
  });

  test('GivenEveryWriteRefused_WhenRun_ThenFailedWithItsWrites', () async {
    final alpha = albumOf('Alpha');
    final harness = harnessFor(alpha);
    for (final song in alpha) {
      harness.tagWriter.refusals[song.file.path] = WriteOutcome.inUse;
    }

    await run(harness, planBatch(alpha, alpha));

    final state = stateOf(harness);
    expect(state.outcomes.single.kind, UnitOutcomeKind.failed);
    expect(state.outcomes.single.writes, {
      for (final song in alpha) song.file.path: WriteOutcome.inUse,
    });
    expect(state.updated, 0);
    expect(state.skipped, 1);
  });

  test('GivenAFailedUnit_WhenRetryFailedWritesIt_ThenItIsUpdated', () async {
    final alpha = albumOf('Alpha');
    final harness = harnessFor(alpha);
    for (final song in alpha) {
      harness.tagWriter.refusals[song.file.path] = WriteOutcome.inUse;
    }
    await run(harness, planBatch(alpha, alpha));
    harness.tagWriter.refusals.remove(alpha.first.file.path);

    await controllerOf(harness).retryFailed();

    final state = stateOf(harness);
    expect(state.outcomes.single.kind, UnitOutcomeKind.updated);
    expect(state.outcomes.single.writes, {
      alpha[0].file.path: WriteOutcome.written,
      alpha[1].file.path: WriteOutcome.inUse,
    });
    expect(state.updated, 1);
    expect(state.skipped, 0);
  });

  test(
    'GivenTheCoverWillNotDownload_WhenRun_ThenTheRestIsWrittenWithANote',
    () async {
      final alpha = albumOf('Alpha');
      final harness = harnessFor(alpha);
      harness.metadata.coverFailure = MetadataSourceFailure.unreachable;

      await run(
        harness,
        planBatch(alpha, alpha),
        fields: const {AutofillField.artist, AutofillField.cover},
      );

      final outcome = stateOf(harness).outcomes.single;
      expect(harness.metadata.coversFetched, ['rel-Alpha']);
      expect(outcome.kind, UnitOutcomeKind.updated);
      expect(outcome.coverUnavailable, isTrue);
      expect(harness.tagWriter.writes.map((w) => w.$2), [
        for (final _ in alpha) {AutofillField.artist: 'Radiohead'},
      ]);
    },
  );

  test('GivenASongBlockedInAWritableRecord_WhenRun_ThenTheRestIsWrittenAndItIsNotWritable', () async {
    final alpha = albumOf('Alpha', count: 3);
    final harness = harnessFor(alpha);
    harness.tagWriter.unreadable.add(alpha[1].file.path);

    await run(harness, planBatch(alpha, alpha));

    final state = stateOf(harness);
    expect(state.outcomes.single.kind, UnitOutcomeKind.updated);
    expect(writtenPaths(harness), [alpha[0].file.path, alpha[2].file.path]);
    expect(state.notWritableSongs.map((s) => s.file.path), [
      alpha[1].file.path,
    ]);
    expect(state.skipped, 1);
  });

  test('GivenADoubtfulUnit_WhenMarkedReviewed_ThenNeedYouDrops', () async {
    final alpha = albumOf('Alpha');
    final harness = harnessFor(
      alpha,
      releases: {'Alpha': releaseOf('Alpha', status: 'Bootleg')},
    );
    await run(harness, planBatch(alpha, alpha));
    expect(stateOf(harness).needYou, 1);

    controllerOf(harness).markReviewed(stateOf(harness).outcomes.single.unit);

    expect(stateOf(harness).needYou, 0);
    expect(stateOf(harness).outcomes.single.reviewed, isTrue);
    expect(stateOf(harness).outcomes.single.kind, UnitOutcomeKind.doubtful);
  });

  test(
    'GivenFinishedUnseen_WhenMarkedSeenWithNothingDoubtful_ThenIndicatorHides',
    () async {
      final alpha = albumOf('Alpha');
      final harness = harnessFor(alpha);
      await run(harness, planBatch(alpha, alpha));
      expect(stateOf(harness).showsIndicator, isTrue);

      controllerOf(harness).markSeen();

      expect(stateOf(harness).seen, isTrue);
      expect(stateOf(harness).showsIndicator, isFalse);
    },
  );

  test('GivenFinishedSeenWithDoubtful_WhenShown_ThenIndicatorStays', () async {
    final alpha = albumOf('Alpha');
    final harness = harnessFor(
      alpha,
      releases: {'Alpha': releaseOf('Alpha', status: 'Bootleg')},
    );
    await run(harness, planBatch(alpha, alpha));

    controllerOf(harness).markSeen();

    expect(stateOf(harness).showsIndicator, isTrue);
  });

  test('GivenAFinishedBatch_WhenCleared_ThenIdle', () async {
    final alpha = albumOf('Alpha');
    final harness = harnessFor(
      alpha,
      releases: {'Alpha': releaseOf('Alpha', status: 'Bootleg')},
    );
    await run(harness, planBatch(alpha, alpha));

    controllerOf(harness).clear();

    expect(stateOf(harness).stage, BatchStage.idle);
    expect(stateOf(harness).outcomes, isEmpty);
    expect(stateOf(harness).showsIndicator, isFalse);
  });

  test('GivenFieldsChosen_WhenStarted_ThenTheyAreRemembered', () async {
    final alpha = albumOf('Alpha');
    final harness = harnessFor(alpha);

    await run(
      harness,
      planBatch(alpha, alpha),
      fields: const {AutofillField.artist, AutofillField.year},
    );

    expect(
      AutofillField.decode(
        harness.settings.getString(AutofillController.fieldsSettingsKey),
      ),
      {AutofillField.artist, AutofillField.year},
    );
    expect(stateOf(harness).fields, {AutofillField.artist, AutofillField.year});
  });

  test('GivenALoneTrackOnTheOfficialAlbum_WhenRun_ThenWritten', () async {
    final lone = entry(
      id: 'creep',
      title: 'Creep',
      artist: 'Radiohead',
      duration: const Duration(minutes: 3, seconds: 58),
      directory: '/library/loose',
    );
    final harness = harnessFor([lone], releases: const {});
    const pablo = ReleaseCandidate(
      id: 'rel-pablo',
      title: 'Pablo Honey',
      artistCredit: radiohead,
      trackCount: 2,
      status: 'Official',
      primaryType: 'Album',
    );
    const single = ReleaseCandidate(
      id: 'rel-single',
      title: 'Creep',
      artistCredit: radiohead,
      trackCount: 1,
      status: 'Official',
      primaryType: 'Single',
    );
    harness.metadata
      ..recordingsFor = ((query) => [
        if (query.title == 'Creep')
          const RecordingMatch(
            recordingId: 'rec-creep',
            title: 'Creep',
            artistCredit: radiohead,
            length: Duration(minutes: 3, seconds: 56),
            appearances: [
              RecordingAppearance(release: single, disc: 1, position: 1),
              RecordingAppearance(release: pablo, disc: 1, position: 2),
            ],
          ),
      ])
      ..releases = {
        'rel-pablo': const ReleaseDetail(
          release: pablo,
          tracks: [
            ReleaseTrack(
              disc: 1,
              position: 1,
              title: 'You',
              artistCredit: radiohead,
              recordingId: 'rec-you',
            ),
            ReleaseTrack(
              disc: 1,
              position: 2,
              title: 'Creep',
              artistCredit: radiohead,
              recordingId: 'rec-creep',
            ),
          ],
        ),
      };

    final plan = planBatch([lone], [lone]);
    expect(plan.units.single.kind, BatchUnitKind.track);
    await run(
      harness,
      plan,
      fields: const {AutofillField.album, AutofillField.trackNumber},
    );

    expect(harness.metadata.lookedUp, ['rel-pablo']);
    expect(harness.tagWriter.writes.single.$2, {
      AutofillField.album: 'Pablo Honey',
      AutofillField.trackNumber: 2,
    });
    expect(stateOf(harness).outcomes.single.kind, UnitOutcomeKind.updated);
    expect(stateOf(harness).outcomes.single.release?.id, 'rel-pablo');
  });

  test('GivenALoneTracksRecordingOnNoTrackOfItsRelease_WhenATrackOfItsTitleIsThere_ThenDoubtfulAndNothingWritten', () async {
    final lone = entry(
      id: 'creep',
      title: 'Creep',
      artist: 'Radiohead',
      track: 2,
      duration: const Duration(minutes: 3, seconds: 58),
      directory: '/library/loose',
    );
    final harness = harnessFor([lone], releases: const {});
    const pablo = ReleaseCandidate(
      id: 'rel-pablo',
      title: 'Pablo Honey',
      artistCredit: radiohead,
      trackCount: 2,
      status: 'Official',
      primaryType: 'Album',
    );
    harness.metadata
      ..recordings = const [
        RecordingMatch(
          recordingId: 'rec-creep',
          title: 'Creep',
          artistCredit: radiohead,
          length: Duration(minutes: 3, seconds: 56),
          appearances: [
            RecordingAppearance(release: pablo, disc: 1, position: 2),
          ],
        ),
      ]
      // The release's track 2 is called Creep and numbered as the song is,
      // but it is another recording of it.
      ..releases = {
        'rel-pablo': const ReleaseDetail(
          release: pablo,
          tracks: [
            ReleaseTrack(
              disc: 1,
              position: 1,
              title: 'You',
              artistCredit: radiohead,
              recordingId: 'rec-you',
            ),
            ReleaseTrack(
              disc: 1,
              position: 2,
              title: 'Creep',
              artistCredit: radiohead,
              recordingId: 'rec-creep-acoustic',
            ),
          ],
        ),
      };

    await run(
      harness,
      planBatch([lone], [lone]),
      fields: const {AutofillField.album, AutofillField.trackNumber},
    );

    final outcome = stateOf(harness).outcomes.single;
    expect(harness.tagWriter.writes, isEmpty);
    expect(outcome.kind, UnitOutcomeKind.doubtful);
    expect(outcome.doubt?.reason, DoubtReason.uncertainTrack);
    expect(outcome.release?.id, 'rel-pablo');
  });

  test('GivenAMalformedAnswer_WhenRun_ThenFailedAndSkipped', () async {
    final library = [...albumOf('Alpha'), ...albumOf('Beta')];
    final harness = harnessFor(library);
    harness.metadata.failures.add(MetadataSourceFailure.malformed);

    await run(harness, planBatch(library, library));

    expect(albumsSearched(harness), ['Alpha', 'Beta']);
    expect(stateOf(harness).outcomes.map((o) => o.kind), [
      UnitOutcomeKind.failed,
      UnitOutcomeKind.updated,
    ]);
    expect(stateOf(harness).skipped, 1);
  });

  test('GivenEverySongOfARecordUnreadable_WhenRun_ThenNotLookedUpAndItsSongsSkipped', () async {
    final alpha = albumOf('Alpha');
    final beta = albumOf('Beta');
    final library = [...alpha, ...beta];
    final harness = harnessFor(library);
    harness.tagWriter.unreadable.addAll([for (final s in alpha) s.file.path]);
    // A format no tag is written to: counted out by the plan itself.
    final ogg = MusicEntry(
      file: AudioFile(
        path: '/library/Beta/zzz-ogg.ogg',
        sizeInBytes: 1024,
        modifiedAt: DateTime.utc(2026),
      ),
      metadata: const TrackMetadata(title: 'Ogg', album: 'Beta'),
    );

    await run(harness, planBatch([...library, ogg], library));

    expect(albumsSearched(harness), ['Beta']);
    expect(stateOf(harness).outcomes.map((o) => o.kind), [
      UnitOutcomeKind.notWritable,
      UnitOutcomeKind.updated,
    ]);
    // The two unreadable songs, and the one no tag can be written to.
    expect(stateOf(harness).skipped, 3);
  });

  test(
    'GivenARunningBatch_WhenStartedAgain_ThenFalseAndTheRunIsUntouched',
    () async {
      final alpha = albumOf('Alpha');
      final beta = albumOf('Beta');
      final harness = harnessFor([...alpha, ...beta]);
      final held = Completer<void>();
      harness.tagWriter.hold = held.future;
      final controller = controllerOf(harness);
      final first = planBatch(alpha, alpha);
      expect(
        await controller.start(first, const {AutofillField.artist}),
        isTrue,
      );
      await pumpEventQueue();

      final again = await controller.start(planBatch(beta, beta), const {
        AutofillField.genre,
      });

      expect(again, isFalse);
      expect(stateOf(harness).plan, same(first));
      expect(stateOf(harness).fields, {AutofillField.artist});
      held.complete();
      await controller.settled;
      expect(albumsSearched(harness), ['Alpha']);
      expect(stateOf(harness).stage, BatchStage.finished);
    },
  );
}
