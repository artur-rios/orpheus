# Autofill the tags of many songs at once — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Autofill any set of songs — a selection, an artist, a genre, a playlist, the whole library — from
MusicBrainz, writing confident matches unreviewed and keeping doubtful ones for the existing review screen.

**Architecture:** Two pure domain files split a batch into records and lone tracks (`batch_plan.dart`) and judge each
match (`confidence.dart`). A kept-alive `BatchAutofillController` walks the plan one unit at a time through the same
`MetadataSource`, matching functions, `TagWriter` and `rescanSoon` as UC-34, sharing UC-34's release fetching through
a small extracted helper. A launcher, a batch screen, a shell indicator and new menu items make up the presentation.

**Tech Stack:** Flutter 3.47.2, Riverpod `Notifier`, `flutter_test`, ARB localisations (en, pt).

**Spec:** `docs/superpowers/specs/2026-10-20-batch-autofill-design.md` (read it first; this plan does not repeat its
rules, it names where each one is built).

## Global Constraints

- Branch `feature/uc-44-batch-autofill` from `develop`; PR into `develop` titled `UC-44 — Autofill many songs at once`.
- Layering per CONTRIBUTING.md: `domain` has no Flutter and no IO; outward things only from `core/di/providers.dart`.
- Tests named Given-When-Then, one behaviour each, mirroring `lib/` under `test/`, using `test/support` (`Harness`,
  `ScriptedMetadataSource`, `FakeTagWriter`, `FakeLibraryAccess`, `ScriptedScanner`, `entry()`). Nothing reaches the
  network or a real file.
- Every new string in **both** `app_en.arb` and `app_pt.arb`, with an `@key` description and the same placeholders;
  Portuguese plurals as `test/core/l10n/portuguese_plurals_test.dart` expects. Regenerate with `flutter gen-l10n`.
- No colour literals outside `lib/core/theme/`. The autofill icon is `Icons.auto_fix_high_outlined`, the action label
  the existing `autofillAction` ("Autofill tags…").
- At most one MusicBrainz request a second: every lookup goes through `metadataSourceProvider`'s one instance.
- Only MP3 and FLAC are written (`canWriteTagsTo`); a chosen field **replaces** an existing value.
- UC-34 (album menu, song menu, `AutofillController`, `AutofillScreen`) keeps its behaviour: its existing tests pass
  **unchanged**.
- Verification for every task: `flutter analyze` clean, `dart format --set-exit-if-changed lib test`, the task's tests
  green; the whole `flutter test` green before the PR.
- Commits: lowercase Conventional Commits, ≤50-char subject, imperative, body at 72 where a why is needed, ending
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. **The connection drops mid-batch** (laptop sleeps, Wi-Fi goes): the batch pauses after three unreachable units
   instead of marking the rest of the library failed, and *Try again* resumes at that unit without rewriting anything
   already written. (Task 4 `…ThreeUnreachableInARow…`, `…ResumeAfterPause…`.)
2. **The owner closes the batch screen and keeps listening**: the run goes on, writes continue, the playing song is
   written last in its record, and the indicator stays in the app bar. (Task 4 `…NoScreenWatching…`, Task 6
   indicator tests.)
3. **Three songs of an album picked in a genre or selection**: the lookup ranks against the whole album (not a
   3-track single), and a change to album or album artist makes it doubtful rather than splitting the album. (Task 2
   `…PartialRecordCarriesTheWholeAlbum…`, Task 3 `…WouldSplitTheAlbum…`, Task 1 `…MatchAgainst…`.)
4. **A compilation** (album artist *Various Artists*, a different artist per track) is one record, and confident when
   MusicBrainz credits the release to *Various Artists*. (Task 2 `…CompilationIsOneRecord…`, Task 3
   `…CompilationMatches…`.)
5. **Untagged folders**: songs with no album tag in different folders never merge into one record, and a folder of one
   is a lone track. (Task 2 `…BlankAlbumsByFolder…`.)

---

### Task 0: Branch and the design documents

- [ ] **Step 1:** `git switch -c feature/uc-44-batch-autofill develop`
- [ ] **Step 2: Commit** the spec and this plan:

```bash
git add docs/superpowers/specs/2026-10-20-batch-autofill-design.md docs/superpowers/plans/2026-10-20-batch-autofill.md
git commit -m "docs: design autofill of many songs at once"
```

---

### Task 1: Share UC-34's release fetching; `matchAgainst` and `onWritten`

Refactor plus two optional inputs, so the batch and the review of a doubtful record use the same steps.

**Files:**
- Create: `lib/features/autofill/application/release_fetch.dart`
- Modify: `lib/features/autofill/application/autofill_controller.dart` (`start`, `_lookUp`, `_propose`,
  `_writeChosen`)
- Modify: `lib/features/autofill/presentation/autofill_screen.dart` (constructor, the `start` call, a listener)
- Test: `test/features/autofill/application/release_fetch_test.dart`,
  `test/features/autofill/application/autofill_controller_test.dart` (new tests only),
  `test/features/autofill/presentation/autofill_screen_test.dart` (new test only)

**Interfaces:**
- Produces:
  ```dart
  class FetchedRelease {
    const FetchedRelease({required this.detail, this.fallbackGenres = const [], this.cover, this.coverUnavailable = false});
    final ReleaseDetail detail; final List<Genre> fallbackGenres; final Uint8List? cover; final bool coverUnavailable;
  }
  /// release(id); release-group genres when genre is chosen and the release has none (a failure → none, logged);
  /// the front cover when cover is chosen (a failure → coverUnavailable). Throws MetadataSourceException only for
  /// release(id) itself.
  Future<FetchedRelease> fetchRelease(MetadataSource source, String releaseId, Set<AutofillField> fields);
  /// [proposals] with the one for [playingPath] moved last.
  List<FileProposal> playingLast(List<FileProposal> proposals, String? playingPath);
  ```
  - `AutofillController.start(entries, fields, {required kind, List<MusicEntry>? matchAgainst})` — with
    `matchAgainst`, the record query is `releaseQueryFor(matchAgainst)`, `rankCandidates(fileCount:
    matchAgainst.length)`, and `assignTracks(matchAgainst, detail)` restricted to keys in `entries` before
    `proposalsFor`. Omitted, everything as today.
  - `AutofillScreen({required entries, required fields, required kind, this.matchAgainst, this.onWritten})` with
    `final void Function()? onWritten;` — called once when the controller reaches `finished` with at least one
    `WriteOutcome.written`.

- [ ] **Step 1: Write the failing tests**
  - `release_fetch_test.dart`: `GivenGenreChosenAndReleaseWithout_WhenFetched_ThenGroupGenresAreTheFallback`;
    `GivenGroupGenresFail_WhenFetched_ThenNoFallbackAndNoThrow`; `GivenCoverChosenAndDownloadFails_WhenFetched_ThenCoverUnavailable`;
    `GivenCoverNotChosen_WhenFetched_ThenNoCoverFetched` (`metadata.coversFetched` empty);
    `GivenThePlayingFileFirst_WhenPlayingLast_ThenItIsLast`.
  - `autofill_controller_test.dart`: `GivenMatchAgainstTheWholeAlbum_WhenStarted_ThenRankedByItsSizeAndProposedOnlyForTheEntries`
    — library album of 12 entries, `entries` = 3 of them, candidates a 3-track single and the 12-track album (both
    official, same title): `state.release!.release.id` is the album's, `state.proposals.length == 3`,
    `metadata.releaseQueries.single.album` is the album's.
  - `autofill_screen_test.dart`: `GivenOnWritten_WhenTheWriteFinishesWithAFileWritten_ThenItIsCalledOnce`.
- [ ] **Step 2: Run** `flutter test test/features/autofill` — the new tests FAIL (missing symbols).
- [ ] **Step 3: Implement** `release_fetch.dart`, then make `AutofillController._propose` call `fetchRelease` (one
  `ref.mounted` check after it) and `_writeChosen` call `playingLast`; add `matchAgainst` (kept in a field beside
  `_entries`) and the screen's `matchAgainst` / `onWritten` (a `ref.listenManual` in `initState`, firing on the
  transition into `finished`).
- [ ] **Step 4: Run** `flutter test test/features/autofill` — all PASS, existing tests untouched.
- [ ] **Step 5: Commit** — `refactor: share autofill release fetching`

---

### Task 2: Splitting a batch into records and lone tracks

**Files:**
- Create: `lib/features/autofill/domain/batch_plan.dart`
- Test: `test/features/autofill/domain/batch_plan_test.dart`

**Interfaces:**
- Consumes: `MusicEntry`, `normalised` (`matching.dart`), `canWriteTagsTo`, `AutofillField`.
- Produces:
  ```dart
  enum BatchUnitKind { record, track }
  class BatchUnit {
    const BatchUnit({required this.kind, required this.songs, required this.matchAgainst});
    final BatchUnitKind kind;
    final List<MusicEntry> songs;        // the batch's writable songs of this unit, disc/track order
    final List<MusicEntry> matchAgainst; // every library song of the unit (writable or not); [song] for a track
    bool get partial;                    // matchAgainst has a song not in songs (by path), unwritable ones excepted
    String get key;                      // stable id: normalised album artist + album, or 'folder:<dir>', or 'track:<path>'
  }
  class BatchPlan {
    const BatchPlan({required this.units, required this.notWritable});
    final List<BatchUnit> units;         // records sorted by normalised artist then album, then tracks by path
    final List<MusicEntry> notWritable;  // batch songs canWriteTagsTo refuses
    int get songCount;                   // units' songs + notWritable
  }
  BatchPlan planBatch(List<MusicEntry> batch, List<MusicEntry> library);
  /// 2.5 s per unit, plus 1 s per unit when cover is chosen, rounded up to whole minutes, at least 1.
  int estimatedMinutes(BatchPlan plan, Set<AutofillField> fields);
  ```
  Grouping (spec §4.1): album present → key `(normalised(albumArtist ?? ''), normalised(album))`; album blank → by
  `file.directory`: two or more library songs with a blank album in that folder → a record, else a track. A unit with
  no writable batch song is dropped. Duplicated paths in `batch` count once.

- [ ] **Step 1: Write the failing tests:** `GivenTwoAlbums_WhenPlanned_ThenTwoRecordsInArtistThenAlbumOrder`;
  `GivenSpellingsDifferingOnlyInCaseAndAccents_WhenPlanned_ThenOneRecord` (`Sigur Rós`/`sigur ros`);
  `GivenCompilationIsOneRecord_WhenPlanned_ThenOneRecordUnderVariousArtists` (album artist `Various Artists`, four
  track artists); `GivenBlankAlbumsByFolder_WhenPlanned_ThenEachFolderIsItsOwnRecordAndAFolderOfOneIsATrack`
  (directories `/music/a` ×3, `/music/b` ×3, `/music/c` ×1 → 2 records, 1 track);
  `GivenPartialRecordCarriesTheWholeAlbum_WhenPlanned_ThenMatchAgainstHoldsTwelveAndSongsThree` (`partial` true);
  `GivenOggSongs_WhenPlanned_ThenCountedNotWritableAndTheirAllOggRecordDropped`;
  `GivenAWholeWritableAlbum_WhenPlanned_ThenNotPartial`; `GivenTheSameSongTwice_WhenPlanned_ThenCountedOnce`;
  `Given288UnitsWithoutCover_WhenEstimated_Then12Minutes`; `Given288UnitsWithCover_WhenEstimated_Then17Minutes`.
- [ ] **Step 2: Run** `flutter test test/features/autofill/domain/batch_plan_test.dart` — FAIL.
- [ ] **Step 3: Implement** `batch_plan.dart`.
- [ ] **Step 4: Run** — PASS.
- [ ] **Step 5: Commit** — `feat: split an autofill batch into records`

---

### Task 3: Confident or doubtful

**Files:**
- Create: `lib/features/autofill/domain/confidence.dart`
- Test: `test/features/autofill/domain/confidence_test.dart`

**Interfaces:**
- Consumes: `BatchUnit` (Task 2), `ReleaseQuery`, `ReleaseDetail`, `ReleaseTrack`, `RecordingMatch`,
  `RecordingAppearance`, `FileProposal`, `ProposalBlock`, `normalised`.
- Produces:
  ```dart
  enum DoubtReason { noMatch, notOfficial, differentAlbum, differentArtist, unmatchedSongs, differentSongs, wouldSplitAlbum, uncertainTrack }
  sealed class Confidence { const Confidence(); }
  final class Confident extends Confidence { const Confident(); }
  final class Doubtful extends Confidence { const Doubtful(this.reason, {this.count = 0}); final DoubtReason reason; final int count; }
  /// Spec §4.3, rules 1–5, checked in that order; the first that fails is the reason.
  Confidence recordConfidence(BatchUnit unit, {required ReleaseQuery query, required ReleaseDetail? release,
      required Map<MusicEntry, ReleaseTrack?> assignment, required List<FileProposal> proposals});
  /// Spec §4.3, lone track: title, artist, length ≤ 3 s, official, primary type album, not a compilation.
  Confidence trackConfidence(MusicEntry song, {required RecordingMatch? match, required RecordingAppearance? appearance});
  ```
  Rule 4 runs over the unit's `songs` whose proposal is not blocked `unwritableFormat`/`unsafeTags`: unassigned →
  `unmatchedSongs(count)`; untitled, title not equal once normalised, or a present track/disc number (missing disc =
  1) that differs → `differentSongs(count)`. Rule 5 (`unit.partial` and any change to `album`/`albumArtist`) →
  `wouldSplitAlbum`. `release == null` → `noMatch`. `query.artist == null` → `differentArtist`.

- [ ] **Step 1: Write the failing tests:** `GivenEverythingMatches_WhenJudged_ThenConfident`; one test per reason,
  each changing one thing from the confident case (`…PromotionRelease…ThenNotOfficial`,
  `…RemasteredTitle…ThenDifferentAlbum`, `…NoArtistAnywhere…ThenDifferentArtist`,
  `…OneSongUnassigned…ThenUnmatchedSongsCount1`, `…UntitledSong…ThenDifferentSongs`,
  `…TrackNumberDiffers…ThenDifferentSongs`, `…WouldSplitTheAlbum…ThenWouldSplitAlbum`, `…NoRelease…ThenNoMatch`);
  `GivenCaseAccentsAndPunctuationDiffer_WhenJudged_ThenConfident` (`ok computer` vs `OK Computer`, `Don’t`/`Don't`);
  `GivenCompilationMatches_WhenJudged_ThenConfident`; `GivenAnUnsafeTagsSong_WhenJudged_ThenTheRestDecide`;
  `GivenPartialRecordChangingOnlyYear_WhenJudged_ThenConfident`; lone track:
  `GivenExactTrackOnOfficialAlbum_WhenJudged_ThenConfident`, `…LengthOff4s…ThenUncertainTrack`,
  `…UnknownLength…ThenUncertainTrack`, `…OnlyOnASingle…ThenUncertainTrack`, `…OnACompilation…ThenUncertainTrack`.
- [ ] **Step 2: Run** `flutter test test/features/autofill/domain/confidence_test.dart` — FAIL.
- [ ] **Step 3: Implement** `confidence.dart`.
- [ ] **Step 4: Run** — PASS.
- [ ] **Step 5: Commit** — `feat: judge autofill matches confident or not`

---

### Task 4: The batch controller

**Files:**
- Create: `lib/features/autofill/application/batch_autofill_controller.dart`
- Modify: `lib/core/di/providers.dart` (provider), `test/support/fake_autofill.dart` (per-query answers)
- Test: `test/features/autofill/application/batch_autofill_controller_test.dart`

**Interfaces:**
- Consumes: Tasks 1–3; `metadataSourceProvider`, `tagWriterProvider`, `libraryAccessControllerProvider`,
  `scanControllerProvider`, `audioPlaybackControllerProvider`, `settingsStoreProvider`, `clockProvider`.
- Produces:
  ```dart
  enum BatchStage { idle, running, paused, finished }
  enum UnitOutcomeKind { updated, alreadyRight, doubtful, notFound, unreachable, failed, notLookedUp }
  class UnitOutcome {
    final BatchUnit unit; final UnitOutcomeKind kind; final Doubtful? doubt; final ReleaseCandidate? release;
    final List<FileProposal> proposals;        // what was (or would be) written
    final Map<String, WriteOutcome> writes;    // by path
    final bool reviewed;
  }
  class BatchAutofillState {
    final BatchStage stage; final BatchPlan? plan; final Set<AutofillField> fields;
    final int done;                            // units finished
    final List<UnitOutcome> outcomes;          // in plan order
    final LibraryAccessDecision? refusal; final bool stoppedEarly; final bool seen;
    int get updated; int get needYou;          // doubtful && !reviewed
    int get alreadyRight; int get notFound; int get skipped; // skipped = plan.notWritable.length + failed units
    bool get showsIndicator;                   // running || paused || (finished && (!seen || needYou > 0))
  }
  class BatchAutofillController extends Notifier<BatchAutofillState> {
    /// Running or paused → false, nothing changed. Saves fields as the remembered choice, asks ensureWritable once;
    /// refused → state.refusal, stage idle, false. Otherwise replaces any finished batch, starts the run without
    /// awaiting it and answers true.
    Future<bool> start(BatchPlan plan, Set<AutofillField> fields);
    void stop();                 // after the unit being written; the rest → notLookedUp; stoppedEarly
    Future<void> resume();       // from paused, at the unit that paused it
    Future<void> retryFailed();  // rewrites inUse/failed files of finished units
    void markReviewed(BatchUnit unit);
    void markSeen();
    void clear();                // back to idle
    @visibleForTesting Future<void> get settled; // completes when the run loop is not running
  }
  final batchAutofillControllerProvider = NotifierProvider<BatchAutofillController, BatchAutofillState>(BatchAutofillController.new); // not auto-disposed
  ```
  Per unit (spec §4.2): `inspect` each song (a throw → `FileTags.unwritable`); record → `searchReleases(
  releaseQueryFor(unit.matchAgainst))`, `rankCandidates(fileCount: matchAgainst.length)`, empty → `notFound`;
  `fetchRelease(best)`; `assignTracks(matchAgainst, detail)` restricted to `songs`; `proposalsFor`;
  `recordConfidence`. Track → `searchRecordings(recordingQueryFor(song))`, `rankAppearances`, the match owning the
  best appearance, assign by recording id else `assignTracks`, `trackConfidence`. Confident with no accepted change
  → `alreadyRight`; confident → write each proposal with changes in `playingLast` order (`expected: entry.file`) →
  `updated` (any write not `written` is kept in `writes` for the summary). `unreachable`/`rateLimited` → re-queued once
  after the next unit, then `unreachable`; the third consecutive one → `paused` at that unit. `malformed` → `failed`.
  `rescanSoon()` when something was written and the last ask was ≥ 60 s ago by `clockProvider`, and once when the run
  ends or stops if anything was written since.
  - `ScriptedMetadataSource` gains `List<ReleaseCandidate> Function(ReleaseQuery)? candidatesFor` and
    `List<RecordingMatch> Function(RecordingQuery)? recordingsFor`, used when set; a `failures` queue
    (`List<MetadataSourceFailure?>`) consumed one per search, for the unreachable tests. Existing fields keep working.

- [ ] **Step 1: Write the failing tests** (with `pumpEventQueue` / `settled`):
  `GivenAConfidentAndADoubtfulRecord_WhenRun_ThenOnlyTheConfidentIsWritten`;
  `GivenNothingWouldChange_WhenRun_ThenAlreadyRightAndNoWrite`; `GivenNoCandidates_WhenRun_ThenNotFound`;
  `GivenAPartialRecord_WhenRun_ThenOnlyItsBatchSongsAreWritten`;
  `GivenAccessRefused_WhenStarted_ThenNothingIsLookedUpAndRefusalIsKept`;
  `GivenStop_WhenAUnitIsBeingWritten_ThenItFinishesAndTheRestAreNotLookedUp`;
  `GivenOneUnreachable_WhenRun_ThenRetriedAfterTheNextUnit`;
  `GivenThreeUnreachableInARow_WhenRun_ThenPausedAtTheThird`;
  `GivenResumeAfterPause_WhenRun_ThenContinuesAndRewritesNothingWritten` (`tagWriter.writes` has no path twice);
  `GivenNoScreenWatching_WhenRun_ThenItStillFinishes` (only `container.read`, no listener);
  `GivenThePlayingSongInARecord_WhenWritten_ThenItIsLast`;
  `GivenWritesOverTwoMinutes_WhenRun_ThenRescanAskedOncePerMinuteAndAtTheEnd` (a stepping clock; count scans in
  `ScriptedScanner`);
  `GivenAnInUseFile_WhenRetryFailed_ThenOnlyItIsWrittenAgain`;
  `GivenADoubtfulUnit_WhenMarkedReviewed_ThenNeedYouDrops`;
  `GivenFinishedUnseen_WhenMarkedSeenWithNothingDoubtful_ThenIndicatorHides`;
  `GivenFieldsChosen_WhenStarted_ThenTheyAreRemembered` (`autofillFields` setting);
  `GivenALoneTrackOnTheOfficialAlbum_WhenRun_ThenWritten`;
  `GivenARunningBatch_WhenStartedAgain_ThenFalseAndTheRunIsUntouched`.
- [ ] **Step 2: Run** `flutter test test/features/autofill/application/batch_autofill_controller_test.dart` — FAIL.
- [ ] **Step 3: Implement** the controller, the provider (doc comment: kept alive because a batch outlives its
  screen), and the fake's additions.
- [ ] **Step 4: Run** `flutter test test/features/autofill` — PASS.
- [ ] **Step 5: Commit** — `feat: run an autofill over many records`

---

### Task 5: Starting a batch and the batch screen

**Files:**
- Create: `lib/features/autofill/presentation/batch_autofill_launcher.dart`,
  `lib/features/autofill/presentation/batch_autofill_screen.dart`,
  `lib/features/autofill/presentation/doubt_reason_names.dart`
- Modify: `lib/core/l10n/app_en.arb`, `lib/core/l10n/app_pt.arb` (then `flutter gen-l10n`)
- Test: `test/features/autofill/presentation/batch_autofill_launcher_test.dart`,
  `test/features/autofill/presentation/batch_autofill_screen_test.dart`

**Interfaces:**
- Consumes: Task 4; `startAutofill`, `AutofillFieldsDialog.ask`, `AutofillScreen` (Task 1), `ConfirmationDialog.ask`,
  `musicLibraryControllerProvider` (`.value?.entries`).
- Produces: `Future<void> startBatchAutofill(BuildContext context, WidgetRef ref, List<MusicEntry> entries)`;
  `BatchAutofillScreen` with `static Future<void> show(BuildContext context)`; `String doubtReasonName(Doubtful d,
  AppLocalizations l10n)`.

`startBatchAutofill`, in order: empty → nothing; one song → `startAutofill(kind: AutofillKind.track)`; a batch
running or paused → `BatchAutofillScreen.show`; finished with `needYou > 0` → `ConfirmationDialog` (replace) and on
no, nothing; the field dialog (remembered choice, `anyWritable`); `planBatch(entries, library)`; the confirmation;
`start`; on `true`, `BatchAutofillScreen.show`. The screen calls `markSeen()` once a finished state is shown; each
*Need you* row pushes `AutofillScreen(entries: unit.songs, matchAgainst: unit.matchAgainst, fields: state.fields,
kind: unit.kind == record ? AutofillKind.record : AutofillKind.track, onWritten: () => markReviewed(unit))`; reviewed
rows show a check and stay listed. Refusal reuses `autofillAccessRefused` / `autofillOpenSettings`.

English copy (ICU plurals where a count is shown; descriptions in `@` entries):

| Key | en |
| --- | --- |
| `autofillBatchConfirmTitle` | `Autofill {songs} songs?` |
| `autofillBatchConfirmBody` | `{records} records, about {minutes} minutes. Records that clearly match MusicBrainz are written without asking, replacing their current tags; the others are kept for you to check.` |
| `autofillBatchConfirmSkipped` | `{count} songs can't be changed and will be skipped.` (appended to the body when > 0) |
| `autofillBatchStart` | `Start` |
| `autofillBatchReplaceTitle` / `…Body` / `…Confirm` | `Start a new autofill?` / `The {count} records waiting for you will be forgotten.` / `Start new` |
| `autofillBatchTitle` | `Autofill` |
| `autofillBatchProgress` | `Looking up {done} of {total} records` |
| `autofillBatchUpdated` / `NeedYou` / `AlreadyRight` / `NotFound` / `Skipped` | `{count} updated` / `{count} need you` / `{count} already right` / `{count} not found` / `{count} skipped` |
| `autofillBatchStop` / `autofillBatchClearList` | `Stop` / `Clear list` |
| `autofillBatchClearTitle` / `…Body` / `…Confirm` | `Clear the list?` / `The records waiting for you are forgotten. Nothing is written.` / `Clear` |
| `autofillBatchPaused` | `MusicBrainz could not be reached. The autofill is paused.` |
| `autofillBatchSummary` | `{updated} records updated, {needYou} need you` |
| `autofillBatchSectionNeedYou` / `NotFound` / `NotWritable` / `Failed` / `NotLookedUp` | `Need you` / `Not found` / `Can't be changed` / `Could not be written or looked up` / `Not looked up` |
| `autofillDoubt…` (one per `DoubtReason`) | `No match` / `Not an official release` / `Different album name` / `Different artist` / `{count} songs unmatched` / `{count} songs differ` / `Would split the album` / `Not a clear match` |
| `autofillBatchIndicatorRunning` / `Paused` / `NeedYou` / `Done` | `Autofilling {done}/{total}` / `Autofill paused` / `{count} need you` / `Autofill done` |

Existing keys reused: `autofillTryAgain`, `autofillClose`, `autofillCancel`, the `autofillOutcome…` reasons.

- [ ] **Step 1: Write the failing widget tests:**
  launcher — `GivenOneSong_WhenStarted_ThenTheLoneTrackReviewOpens`;
  `GivenABatch_WhenConfirmed_ThenTheRunStartsAndTheScreenOpens`;
  `GivenTheConfirmation_WhenShown_ThenItNamesSongsRecordsMinutesAndSkipped` (`Autofill 5 songs?`, `about 1 minute`,
  `2 songs can't be changed`);
  `GivenTheConfirmationCancelled_WhenStarted_ThenNothingIsLookedUp`;
  `GivenARunningBatch_WhenAnotherIsStarted_ThenTheRunningOneOpens`;
  `GivenAFinishedBatchWithDoubtful_WhenAnotherIsStarted_ThenItAsksAndKeepsTheOldOnNo`;
  screen — `GivenARun_WhenShown_ThenProgressAndCounts`; `GivenStopTapped_WhenRunning_ThenTheControllerStops`;
  `GivenPaused_WhenTryAgainTapped_ThenItResumes`;
  `GivenFinished_WhenShown_ThenSummaryAndSectionsWithReasons`;
  `GivenADoubtfulRow_WhenTappedAndTheReviewWrites_ThenTheRowIsMarkedReviewed`;
  `GivenClearList_WhenConfirmed_ThenTheBatchIsCleared`; `GivenTheRefusal_WhenShown_ThenTheAccessMessage`;
  `GivenAnInUseFileInTheSummary_WhenTryAgainTapped_ThenRetryFailedRuns`.
- [ ] **Step 2: Run** `flutter test test/features/autofill/presentation` — FAIL.
- [ ] **Step 3: Implement** the strings (en + pt), the launcher, the screen and `doubtReasonName`.
- [ ] **Step 4: Run** `flutter test test/features/autofill test/core/l10n` — PASS (catalog parity and plural guards
  included).
- [ ] **Step 5: Commit** — `feat: start and follow a batch autofill`

---

### Task 6: The shell indicator

**Files:**
- Create: `lib/features/autofill/presentation/batch_autofill_indicator.dart`
- Modify: `lib/features/shell/presentation/shell_screen.dart` (`_ShellAppBar.actions`, before the stats button)
- Test: `test/features/autofill/presentation/batch_autofill_indicator_test.dart`

**Interfaces:**
- Consumes: `batchAutofillControllerProvider`, `BatchAutofillState.showsIndicator`, `BatchAutofillScreen.show`,
  `Breakpoint.from(context).usesBottomNavigation`.
- Produces: `class BatchAutofillIndicator extends ConsumerWidget` — nothing (`SizedBox.shrink()`) unless
  `showsIndicator`; on a phone an `IconButton` with the autofill icon in a `Badge` (label: `done/total` running,
  `needYou` finished) and the indicator text as tooltip; wider, a `TextButton.icon` with the indicator text. Taps
  open `BatchAutofillScreen`.

- [ ] **Step 1: Write the failing tests:** `GivenNoBatch_WhenShellShown_ThenNoIndicator`;
  `GivenARunningBatch_WhenShellShown_ThenAutofillingDoneOfTotal`; `GivenPaused_WhenShown_ThenAutofillPaused`;
  `GivenFinishedWithDoubtfulAndSeen_WhenShown_ThenNeedYouCount`;
  `GivenFinishedSeenNothingDoubtful_WhenShown_ThenNoIndicator`; `GivenTheIndicator_WhenTapped_ThenTheBatchScreenOpens`;
  `GivenAPhone_WhenRunning_ThenAnIconWithABadge`.
- [ ] **Step 2: Run** — FAIL. **Step 3: Implement.** **Step 4: Run** `flutter test test/features/autofill
  test/features/shell` — PASS.
- [ ] **Step 5: Commit** — `feat: show a running autofill in the app bar`

---

### Task 7: Entry points

**Files:**
- Modify: `lib/features/playback/presentation/music_rows.dart` (`MusicGroupMenu`: artist item; the selection bar's
  `actions` in the song list), `lib/features/playlists/presentation/playlist_track_list.dart` (its selection bar),
  `lib/features/playlists/presentation/playlist_menu.dart` (auto and own items),
  `lib/features/playback/presentation/genres_view.dart` (genre row menu),
  `lib/features/playback/presentation/music_browser.dart` (`onAutofill` → a ⋮ in `_Controls`),
  `lib/features/playback/presentation/music_library_view.dart` (passes the whole library)
- Test: the matching files under `test/features/playback/presentation/` and `test/features/playlists/presentation/`

**Interfaces:**
- Consumes: `startBatchAutofill` (Task 5).
- Produces: `MusicBrowser({..., VoidCallback? onAutofill})`; `GenreMenu` (in `genres_view.dart`, private is fine)
  opened by a trailing ⋮ `IconButton`, right-click and long press, as `MusicGroupMenu` is.

Songs per entry point (spec §4.5): artist — `_gathered` (already the library's tracks of the artist); album item
unchanged (UC-34); genre — `genre.tracks`; playlist — `[for (e in playlist.entries) ?byPath[e.path]]` as `_addAll`
does; selection bar — `_pickedEntries()`, selection kept; controls bar — the Music tab's library entries, and inside an
open genre its tracks (what its `onShuffle` plays).

- [ ] **Step 1: Write the failing tests:** `GivenAnArtistRow_WhenMenuOpened_ThenAutofillTagsIsOffered` and tapping it
  shows the batch confirmation; `GivenAnAlbumRow_WhenAutofillTapped_ThenTheRecordReviewOpensAsBefore`;
  `GivenAGenreRow_WhenRightClicked_ThenAutofillTagsIsOffered`;
  `GivenAPlaylist_WhenMenuOpened_ThenAutofillTagsIsOffered` (own and auto);
  `GivenASelectionOfThree_WhenAutofillTapped_ThenTheBatchConfirmationOpens`;
  `GivenASelectionOfOne_WhenAutofillTapped_ThenTheLoneTrackReviewOpens`;
  `GivenTheMusicTab_WhenControlsMenuAutofillTapped_ThenTheWholeLibraryIsCounted`;
  `GivenAnOpenGenre_WhenControlsMenuAutofillTapped_ThenOnlyItsSongsAreCounted`.
- [ ] **Step 2: Run** — FAIL. **Step 3: Implement.** **Step 4: Run** `flutter test test/features/playback
  test/features/playlists` — PASS.
- [ ] **Step 5: Commit** — `feat: offer autofill on artists, genres, playlists`

---

### Task 8: Documents and the full check

**Files:**
- Modify: `docs/requirements/Vision Document.md` (C-03, F-25 — the next free number, §1.2, §6),
  `docs/requirements/System Requirements Document.md` (`FR-AF-09` … `FR-AF-11`, NFR-03, traceability),
  `docs/requirements/Use Case Specification Document.md` (UC-44 with the alternative flows of spec §6, traceability
  row), `README.md` (autofill bullet, *It changes your files only when you ask*, the backlog row `UC-44 — Autofill
  many songs at once — done`, the "UC-01 to UC-43" sentence), `docs/site/content/en/docs/overview/_index.md`,
  `CHANGELOG.md` (`### Added` under `[Unreleased]`).

Wording for C-03, `FR-AF-09` … `FR-AF-11` and NFR-03 is in spec §3; write UC-44 in the document's own voice and
layout (main flow, alternative flows `AF-01` …, postconditions).

- [ ] **Step 1:** Write the documents.
- [ ] **Step 2: Run** `flutter analyze`, `dart format --set-exit-if-changed lib test`, `flutter test` — all clean and
  green.
- [ ] **Step 3: Commit** — `docs: specify autofill of many songs`
