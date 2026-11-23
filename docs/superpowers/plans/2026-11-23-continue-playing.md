# Keep playing, and a shuffle that follows the browser — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A *When the queue ends* preference (Stop / Same artist / Same genre / Whole library) that appends one random
track at a time when a queue runs out, and a Music toolbar shuffle that shuffles the artist or album being viewed.

**Architecture:** A pure domain enum and pool function decide *which* tracks may follow; the playback controller draws
one, appends it and opens it at the three places a queue can run out (a track ending, the last track failing, *next*
on the last track). The preference lives in `PreferencesController` (stored through `SettingsStore.getString`, as the
repeat mode is) and travels in the backup. The toolbar shuffle is derived in `MusicBrowser` from the
`MusicBrowseState` it shows, reusing `playArtist` / `playAlbum` as the row buttons do.

**Tech Stack:** Flutter 3.50.0, Riverpod 3, `flutter_test`, ARB (en, pt) with generated `AppLocalizations`.

**Spec:** `docs/superpowers/specs/2026-11-23-continue-playing-design.md`

## Global Constraints

- Tests named Given-When-Then, one behaviour each, mirroring `lib/` under `test/`, built on `Harness`
  (`test/support/test_container.dart`) and `entry(...)` (`test/support/entries.dart`); randomness only through
  `shuffleRandomProvider` (the harness seeds it).
- **Running tests:** orpheus' tests cannot run on this host (native build needs GTK/Xi). Use one long-lived container
  of the `linux` check's image (`yggdrasil.yml`), with the repository, `~/sdk/flutter` and `~/.pub-cache` mounted at
  their host paths and `ci/apt-packages.sh`'s `ensure_packages clang cmake ninja-build pkg-config libgtk-3-dev` run
  once; then `docker exec … flutter test <files>`. Stop and remove the container at the end. `flutter analyze` runs on
  the host. The final gate is `ci-check linux` (≈20 min) and then Jenkins.
- Strings in both `lib/core/l10n/app_en.arb` and `app_pt.arb`, each with an `@key` description; regenerate with
  `flutter gen-l10n` and commit the generated files.
- New files `dart format`-clean; edited files keep their surrounding comment style (comments say *why*).
- Commits: lowercase Conventional Commits, subject ≤ 50 chars, body at 72 saying why, ending with the
  `Claude-Session:` trailer. No Co-Authored-By.
- Default is **Stop**: a fresh install and an old backup both behave exactly as today.

## Review Focus

1. **A queue whose last track will not open** (missing or undecodable) with continuation on must not loop forever:
   skipped files never re-enter the pool. (Task 3, test `…EveryCandidateIsMissing…`.)
2. **Repeat all / repeat one with continuation on** keep their meaning; nothing is appended. (Task 3.)
3. **A small artist already fully in the queue** continues with a track already heard, never the seed itself; an
   artist of one track stops. (Task 1.)
4. **A seed no longer in the library** (file removed since the queue was built) continues from the whole library
   rather than stopping. (Task 1.)
5. **The Music toolbar inside an empty drilled level** (an artist whose files were all removed by a rescan) offers a
   disabled shuffle, not one that plays everything. (Task 4.)

---

### Task 1: The continuation rule

**Files:**
- Create: `lib/features/playback/domain/queue_continuation.dart`
- Test: `test/features/playback/domain/queue_continuation_test.dart`

**Interfaces:**
- Produces:
  ```dart
  enum QueueContinuation { stop, sameArtist, sameGenre, library;
    static QueueContinuation fromName(String? name); }   // unknown/null → stop
  const String queueContinuationSettingsKey = 'queueContinuation';
  /// The tracks that may follow [seed]; empty means stop.
  List<MusicEntry> continuationPool({
    required QueueContinuation mode,
    required String? seedPath,          // the track the queue ended on
    required List<MusicEntry> library,
    required Set<String> queuedPaths,   // every path in the queue
    required Set<String> skippedPaths,  // queue.skipped
  });
  ```

Rules (from the spec): seed entry = `library` entry whose `file.path == seedPath`; none → treat as `library` mode.
`sameArtist`: name = `seed.artist ?? seed.albumArtist`; match candidates whose `artist == name || albumArtist == name`
(exact, as `artistOf` compares); name `null` → `library`. `sameGenre`: match candidates sharing any
`genreKey(genre)` with the seed; seed with no genres → `library`. Then: drop `skippedPaths` always; drop `queuedPaths`;
if that leaves nothing, allow `queuedPaths` again except `seedPath`. `stop` → `[]`.

- [ ] **Step 1: Write the failing tests** — one per rule:
  - `GivenStop_WhenThePoolIsAsked_ThenItIsEmpty`
  - `GivenSameArtist_WhenTheSeedHasAnArtist_ThenOnlyTracksByThemAreOffered` (Radiohead seed; Miles Davis absent)
  - `GivenSameArtist_WhenACompilationTrackIsTheSeed_ThenThePerformerIsFollowed` (seed `artist: 'Björk'`,
    `albumArtist: 'Various Artists'`; a Björk album track is in the pool, another Various Artists track is not)
  - `GivenSameArtist_WhenTheSeedNamesNoArtist_ThenTheWholeLibraryIsOffered`
  - `GivenSameGenre_WhenTheSeedHasTwoGenres_ThenTracksSharingEitherAreOffered` (seed `['Rock','Pop']`; `'rock'`
    track in, `'Jazz'` track out — keys compared through `genreKey`)
  - `GivenSameGenre_WhenTheSeedHasNoGenre_ThenTheWholeLibraryIsOffered`
  - `GivenTheSeedIsNotInTheLibrary_WhenThePoolIsAsked_ThenTheWholeLibraryIsOffered`
  - `GivenTracksAlreadyQueued_WhenOthersMatch_ThenTheQueuedOnesAreLeftOut`
  - `GivenEveryMatchIsQueued_WhenThePoolIsAsked_ThenTheyAreOfferedAgainExceptTheSeed`
  - `GivenAnArtistOfOneTrack_WhenItEnds_ThenThePoolIsEmpty`
  - `GivenASkippedTrack_WhenEverythingElseIsQueued_ThenItIsNeverOffered`
  - `GivenAStoredName_WhenItIsRead_ThenTheModeIsRestored` / `GivenAnUnknownName_WhenItIsRead_ThenItIsStop`
- [ ] **Step 2: Run them; expect compile failure** (`flutter test test/features/playback/domain/queue_continuation_test.dart`
  in the test container).
- [ ] **Step 3: Implement `queue_continuation.dart`** per the rules above (pure; imports `music_entry.dart`,
  `genres.dart`).
- [ ] **Step 4: Run them; expect PASS.**
- [ ] **Step 5: Commit** `feat: decide what may follow an ended queue`.

### Task 2: The preference, its strings and the backup

**Files:**
- Modify: `lib/features/shell/application/preferences_controller.dart`, `lib/features/shell/presentation/preferences_dialog.dart`
  (a `DropdownButtonFormField<QueueContinuation>` under *Playback*, after `settingsOpensPlayerOnPlay`),
  `lib/core/l10n/app_en.arb`, `app_pt.arb` (+ generated),
  `lib/features/data_export/domain/backup.dart`, `lib/features/data_export/application/backup_controller.dart:~74`,
  `lib/features/data_export/domain/restore_plan.dart:~536-560`, `lib/features/data_export/application/restore_controller.dart:~985`
- Test: `test/features/shell/application/preferences_controller_test.dart`,
  `test/features/shell/presentation/preferences_dialog_test.dart`, `test/features/data_export/domain/backup_test.dart`,
  `test/features/data_export/domain/restore_plan_test.dart`, `test/features/data_export/application/restore_controller_test.dart`

**Interfaces:**
- Consumes: Task 1's enum and key.
- Produces: `PreferencesState.continuation` (`QueueContinuation`, read in `build()` as
  `QueueContinuation.fromName(settings.getString(queueContinuationSettingsKey))`);
  `Future<void> PreferencesController.setContinuation(QueueContinuation mode)` (through `_write`, `setString(key, mode.name)`);
  `PreferencesSnapshot.queueContinuation` (`String`, **optional** named parameter defaulting to `'stop'`, so existing
  constructions compile; JSON key `'queueContinuation'`; missing or non-string → `'stop'`; in `==`/`hashCode`).

Strings (keys and copy fixed here):

| Key | en | pt |
|-----|----|----|
| `settingsQueueContinuation` | When the queue ends | Quando a fila terminar |
| `queueContinuationStop` | Stop | Parar |
| `queueContinuationSameArtist` | Play more by the same artist | Tocar mais do mesmo artista |
| `queueContinuationSameGenre` | Play more of the same genre | Tocar mais do mesmo gênero |
| `queueContinuationLibrary` | Play anything from the library | Tocar qualquer música da biblioteca |

- [ ] **Step 1: Write the failing tests:**
  - `GivenNothingStored_WhenPreferencesAreRead_ThenTheQueueStops`
  - `GivenSameGenreStored_WhenPreferencesAreRead_ThenItIsSameGenre`
  - `GivenTheOwnerPicksSameArtist_WhenItIsSet_ThenItAppliesAndIsStored`
  - `GivenTheStoreRefusesTheWrite_WhenContinuationIsSet_ThenItAppliesAndIsMarkedUnsaved`
  - dialog: `GivenThePreferences_WhenTheOwnerPicksWholeLibrary_ThenItIsStored`
  - backup: round-trip of `queueContinuation: 'sameGenre'`; `GivenAnOlderBackupWithoutTheKey_WhenRead_ThenItIsStop`
  - restore plan: *Replace* takes the backup's value; *Merge* takes it only while the owner's is still `'stop'`
  - restore controller: a restored `'library'` reaches `preferencesControllerProvider`
- [ ] **Step 2: Run them; expect FAIL.**
- [ ] **Step 3: Implement**; add the ARB keys and run `flutter gen-l10n`.
- [ ] **Step 4: Run** the five test files plus `test/features/data_export/application/backup_controller_test.dart` and
  `test/core/l10n`; expect PASS. `flutter analyze` clean on the host.
- [ ] **Step 5: Commit** `feat: choose what plays when the queue ends`.

### Task 3: The player continues

**Files:**
- Modify: `lib/features/playback/application/audio_playback_controller.dart` (`next()` ~379, `_listenToEngine`'s
  `hasEnded` branch ~736, `_ranOut` ~803, `AudioPlaybackState`)
- Modify: `lib/features/shell/presentation/playback_bar.dart:~200`, `lib/features/playback/presentation/now_playing_screen.dart:~253`,
  `lib/features/playback/application/media_session_controller.dart:~161`
- Test: `test/features/playback/application/audio_playback_controller_test.dart` (new `group('when the queue ends')`),
  `test/features/playback/application/media_session_controller_test.dart`

**Interfaces:**
- Consumes: Task 1's `QueueContinuation`, `continuationPool`; Task 2's
  `preferencesControllerProvider.select((p) => p.continuation)`.
- Produces:
  ```dart
  // on AudioPlaybackState
  bool canAdvance({required QueueContinuation continuation});
  // queue.hasNext || (!queue.isEmpty && (repeat != QueueRepeat.off || continuation != QueueContinuation.stop))
  ```

Behaviour: a private `Future<bool> _continueFrom(PlaybackQueue queue, {required String? seedPath})` reads the
preference, returns `false` when it is `stop` or `state.repeat != QueueRepeat.off`; otherwise reads the library
(`_library()`), builds the pool, shuffles it with `shuffleRandomProvider`, takes the first entry whose
`trackProbeProvider.exists(path)`, and — when there is one — sets `state.queue` to the queue with it appended and
`await _openAt(newIndex)`, returning `true`. No candidate → `false` (caller ends as today). Call sites:
- `hasEnded` with no next and repeat off: `if (!await _continueFrom(queue, seedPath: queue.current?.path))` → idle.
- `_ranOut`, before stopping, only when `_queuePlayed`: seed = the last track before `queue.index` not in
  `queue.skipped` (fallback `null`).
- `next()` with no next and repeat off: `_continueFrom(state.queue, seedPath: current)`.
Queue `kind` and `label` are left unchanged. Remove the `else` that builds a fresh `AudioPlaybackState` only where a
continuation happened.

- [ ] **Step 1: Write the failing tests** (`Harness(library: …, settings: InMemorySettingsStore()..setString(queueContinuationSettingsKey, 'sameArtist'))`
  or via `preferencesControllerProvider.notifier.setContinuation`):
  - `GivenStop_WhenTheLastTrackEnds_ThenPlaybackGoesIdle` (today's behaviour, pinned)
  - `GivenSameArtist_WhenTheAlbumEnds_ThenATrackByTheArtistIsAppendedAndOpened` (OK ends → `kidA` track opened,
    queue length 4, index 3, `kind` still `album`)
  - `GivenWholeLibrary_WhenTheAppendedTrackEnds_ThenAnotherIsAppended` (queue grows to 5)
  - `GivenRepeatAll_WhenTheAlbumEnds_ThenItStartsAgainAndNothingIsAppended`
  - `GivenRepeatOne_WhenTheTrackEnds_ThenItRepeatsAndNothingIsAppended`
  - `GivenSameArtist_WhenNextIsPressedOnTheLastTrack_ThenATrackIsAppended`
  - `GivenTheLastTrackIsMissing_WhenTheQueueRunsOut_ThenItContinuesFromTheLastTrackThatPlayed` (`missingTracks`)
  - `GivenEveryCandidateIsMissing_WhenTheQueueEnds_ThenPlaybackStops`
  - `GivenAnAppendedTrackFailsToDecode_WhenItIsSkipped_ThenAnotherIsDrawnAndTheFailedOneNeverReturns`
  - `GivenContinuationOn_WhenTheLastTrackPlays_ThenCanAdvanceIsTrue` (and false under `stop`)
  - media session: `GivenContinuationOn_WhenTheLastTrackPlays_ThenTheSessionOffersNext`
- [ ] **Step 2: Run them; expect FAIL** (the `stop` test passes already).
- [ ] **Step 3: Implement** `canAdvance`, `_continueFrom` and the three call sites; switch the bar, the player and the
  media session controller to `state.canAdvance(continuation: ref.watch(preferencesControllerProvider.select((p) => p.continuation)))`.
- [ ] **Step 4: Run** the two test files plus `test/features/shell/presentation/playback_bar_test.dart` and
  `test/features/playback/presentation/now_playing_screen_test.dart`; expect PASS.
- [ ] **Step 5: Commit** `feat: keep playing after the queue ends`.

### Task 4: The toolbar shuffle follows the browser

**Files:**
- Modify: `lib/features/playback/presentation/music_browser.dart` (`_Controls` receives the derived action and tooltip),
  the doc comment on `playEverythingShuffled` in `audio_playback_controller.dart:~270`, and the comments at
  `music_library_view.dart:~42` / `genres_view.dart:~77` that describe the button.
- Test: `test/features/playback/presentation/music_browser_test.dart`, `music_library_view_test.dart`, `genres_view_test.dart`

**Interfaces:**
- Consumes: existing `AudioPlaybackController.playArtist/playAlbum(file, shuffled: true, within: musicWithinOf(context))`,
  `albumsOfArtist`, the browser's own `tracksOfAlbum` (with `fallbackLibrary`), `l10n.audioShuffleArtist` /
  `audioShuffleAlbum`.
- Produces: nothing new for other tasks. `MusicBrowser.onShuffle` / `shuffleTooltip` keep their names and now mean
  *the top level's* shuffle.

Rule: `state.inAlbum` → seed = first track of the open album (as `_List` gathers it), `playAlbum`, tooltip
`audioShuffleAlbum`; else `state.view == MusicView.artists && state.inArtist` → seed = first entry of
`albumsOfArtist(state.artist, library)`, `playArtist`, tooltip `audioShuffleArtist`; else `onShuffle` /
`shuffleTooltip`. A drilled level with no tracks → `onPressed: null`.

- [ ] **Step 1: Write the failing tests:**
  - `GivenTheArtistsView_WhenShuffleIsPressed_ThenEverythingIsShuffled` (pins today)
  - `GivenAnOpenArtist_WhenShuffleIsPressed_ThenOnlyTheirTracksAreQueued` (tooltip *Shuffle the artist*; queue kind
    `artist`, every track Radiohead)
  - `GivenAnAlbumOpenedThroughAnArtist_WhenShuffleIsPressed_ThenOnlyTheAlbumIsQueued`
  - `GivenAnAlbumOpenedFromAlbums_WhenShuffleIsPressed_ThenOnlyTheAlbumIsQueued`
  - `GivenTheSongsView_WhenShuffleIsPressed_ThenEverythingIsShuffled`
  - genres: `GivenAnArtistOpenedInAGenre_WhenShuffleIsPressed_ThenOnlyTheirTracksInTheGenreAreQueued`
  - `GivenAnOpenArtistWithNoTracksLeft_WhenTheToolbarIsShown_ThenShuffleIsDisabled`
- [ ] **Step 2: Run them; expect FAIL.**
- [ ] **Step 3: Implement** the rule in `MusicBrowser`; rewrite the three comments to match.
- [ ] **Step 4: Run** the three test files; expect PASS.
- [ ] **Step 5: Commit** `feat: shuffle what the browser is showing`.

### Task 5: Changelog, full check, pull request

- [ ] **Step 1:** `CHANGELOG.md` under `[Unreleased]`, in its style: *Added* — the *When the queue ends* preference;
  *Changed* — the Music toolbar's shuffle plays the open artist or album.
- [ ] **Step 2:** `flutter analyze` on the host; `ci-check linux`; expect exit 0. Remove the test container.
- [ ] **Step 3:** Commit `docs: note continuing playback in the changelog`; push `feature/continue-playing`; open the
  pull request into `develop` with `tea pr create` (what and why, how it was tested, nothing for the owner after
  merging; ending with the Claude Code line). Report the Jenkins status from
  `tea api repos/artur-rios/orpheus/commits/<sha>/status`. Do not merge.
