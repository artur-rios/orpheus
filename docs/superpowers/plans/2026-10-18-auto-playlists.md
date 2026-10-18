# Auto playlists — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** *Favourites lately* and *All-time favourites*, computed from a play history that now records dated plays,
shown read-only in an *Auto playlists* section of the Playlists tab, hidden by a preference.

**Architecture:** The play history gains per-track dated plays (90 days), a version-2 document migrated from v1 and
never overwritten when unreadable, and a provider that publishes it as plays are recorded. A pure domain computes the
two lists; a derived provider combines history, catalog, clock and preference; the step-4 tab and playlist view gain
the section and a read-only mode.

**Tech Stack:** Flutter 3.47, Riverpod 3, `flutter_test`, ARB (en, pt).

**Spec:** `docs/superpowers/specs/2026-10-18-auto-playlists-design.md`

## Global Constraints

- Layering per CONTRIBUTING.md: `domain` has no Flutter and no IO; providers only in `core/di/providers.dart`; tests
  use `Harness` and the `test/support` fakes.
- Tests named Given-When-Then, one behaviour each, mirroring `lib/` under `test/`.
- Strings in both `app_en.arb` and `app_pt.arb` with `@key` descriptions and the same placeholders; keys prefixed
  `autoPlaylist…`; `flutter gen-l10n`.
- No colour literals outside `lib/core/theme/`.
- **The owner's play history is never reset or overwritten unread:** v1 migrates with counts kept; garbage or a newer
  version is kept aside as `play-history.json.bad-<yyyyMMddTHHmmss>`; a failed set-aside means no writes this run.
- The statistics' numbers are unchanged for the same history.
- Auto playlists are never written to `playlists.json`, and can't be reordered, removed from, renamed, re-covered or
  deleted.
- Formatting: new files `dart format`-clean; edited files keep their surrounding style (never run the formatter
  tree-wide).
- Commits: lowercase Conventional Commits, ≤50-char subject, body at 72, ending
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. **A real v1 `play-history.json`** (the owner's) reads with every count and last-played kept, and the next record
   writes v2 with them intact. (Task 1.)
2. **The statistics screen** shows the same numbers for a migrated history. (Task 1.)
3. **The 30-day and 90-day windows** at their edges (exactly 30/90 days ago; plays in the future from clock skew).
   (Task 1, Task 2.)
4. **Fewer than 10 recent songs** → fallback with the note; **no song at all** → empty state only. (Task 2, Task 3.)
5. **Preference off** hides the section and closes an open auto playlist; the history keeps recording. (Task 3.)

---

### Task 1: Dated plays in the play history

**Files:** modify `lib/features/stats/domain/play_history.dart`, `lib/features/stats/data/json_play_history_store.dart`,
`lib/features/stats/application/play_recorder.dart`, `lib/core/di/providers.dart`; tests under `test/features/stats/`.

**Produces:**
```dart
class TrackPlays { …; final List<DateTime> recent; } // UTC, oldest first, within 90 days
const Duration recentPlaysKept = Duration(days: 90);
PlayHistory recording(String path, DateTime at);      // also appends `at` to that track's recent
PlayHistory trimmedTo(DateTime now);                  // drops recent older than now - 90 days, every track
final playHistoryProvider = ...;                      // the current PlayHistory, updated after each record (AsyncNotifier or StreamProvider — implementer's choice; document it)
```
Store: version 2 with `recent` as ISO-8601 UTC strings per track; reading v1 migrates (`recent` empty); every read and
write trims; garbage or a version other than 1/2 → set aside like `JsonPlaylistStore` (copy its approach), return
empty; a failed set-aside throws. `PlayRecorder`: when `read` throws, keep an empty history in memory, log, and make
`record` write nothing for the rest of the run (playback never interrupted); `musicStatsControllerProvider` keeps
reading as today.

- [ ] **Step 1: Write the failing tests:** record appends a dated play; trim drops older than 90 days on every track
  and keeps exactly-90-days; v1 fixture (counts and last-played for 3 tracks) migrates with all kept and `recent`
  empty; the next record writes version 2 with those counts; round trip v2; garbage and version 3 kept aside (the
  `.bad-` file holds the bytes); a failed set-aside makes the recorder write nothing while `record` still completes;
  `MusicStats` from a migrated v1 history equals `MusicStats` from the same v1 history read by the old rules (pin the
  numbers); `playHistoryProvider` updates after a record.
- [ ] **Step 2–4:** FAIL → implement → PASS (also `test/features/stats`); analyze clean.
- [ ] **Step 5: Commit** `feat: record when each song was played`.

---

### Task 2: Computing the auto playlists

**Files:** create `lib/features/playlists/domain/auto_playlists.dart`; modify `providers.dart`,
`lib/features/shell/application/preferences_controller.dart` (a `showsAutoPlaylists` field, default true, persisted
like the others); tests.

**Produces:**
```dart
const String autoLatelyId = 'auto:lately', autoAllTimeId = 'auto:all-time';
class AutoList { final List<MusicEntry> songs; final bool isFallback; }
AutoList favouritesLately(PlayHistory history, Map<String, MusicEntry> catalogByPath, DateTime now);
List<MusicEntry> allTimeFavourites(PlayHistory history, Map<String, MusicEntry> catalogByPath);
final autoPlaylistsProvider = Provider<AsyncValue<List<Playlist>>>(...); // [] when the preference is off; loading while history or catalog load; synthesised Playlists (ids above, localisable names passed in by the view or resolved via a name key), entry id = path, snapshot from the catalog, fixed modifiedAt
```
Rules (spec §3): lately = present songs with ≥1 recent play in the last 30 days (relative to `now`), by recent count
desc then lastPlayedAt desc, 50 max — when at least 10 such songs; else fallback = present songs with lastPlayedAt in
the last 30 days by plays desc then lastPlayedAt desc, 50 max, `isFallback` true; none qualify → empty with
`isFallback` false. All-time = present songs with plays ≥ 1 by plays desc then lastPlayedAt desc, 50 max.

- [ ] **Step 1: Write the failing tests:** each rule and edge: exactly 30 days, 9 vs 10 recent songs, ties, 50 cap,
  missing songs excluded, empty, all-time ordering and cap; the provider: off → empty list, recomputes after a play is
  recorded, recomputes after the catalog changes; preference persists and defaults to on.
- [ ] **Step 2–4:** FAIL → implement → PASS; analyze clean.
- [ ] **Step 5: Commit** `feat: work out the auto playlists`.

---

### Task 3: Auto playlists in the tab

**Files:** modify `lib/features/playlists/presentation/playlists_view.dart`, `playlist_view.dart`,
`playlist_track_list.dart`, `playlist_menu.dart`, `lib/features/playlists/application/playlists_controller.dart`
(export taking a `Playlist` value), `lib/core/di/providers.dart` (`openPlaylistProvider` resolves `auto:` ids from
`autoPlaylistsProvider`), `lib/features/shell/presentation/preferences_dialog.dart` (the switch); strings; tests.

Behaviour (spec §3 "In the tab", "Inside an auto playlist", "Representation", "Preference"): the section
(*Auto playlists*, then *Your playlists*) independent of the playlists' own load state; loading row while the catalog
loads; hidden on catalog error; inline *Your playlists* empty state when the owner has none. Auto rows/tiles with the
mosaic; menu *Add to playlist…* (all songs via `startAddToPlaylist`) and *Export to .m3u…* (default name the localised
playlist name). Inside: read-only mode of the playlist view — no drag handles, no *Remove from playlist*, no rename /
cover / delete; selection by path with *Add to playlist…* and *Edit tags…*; fallback note under the header; the two
empty states. Turning the preference off hides the section and an open auto playlist reads as closed.

- [ ] **Step 1: Write the failing tests:** section shown with both lists, hidden when off; shown when `playlists.json`
  is unreadable (above the error) and with no playlists (inline empty state); loading row; open → Play, Shuffle;
  read-only (no handles, no remove, menu without rename/cover/delete); selection *Add to playlist…* and *Edit tags…*;
  fallback note; empty states; menu *Add to playlist…* adds all songs; export uses the name; the Preferences switch
  persists; switching off while an auto playlist is open closes it; Back from an auto playlist closes it.
- [ ] **Step 2–4:** FAIL → strings + gen-l10n → implement → PASS (also `test/features/playlists`); analyze clean.
- [ ] **Step 5: Commit** `feat: show auto playlists in their tab`.

---

### Task 4: Documents

Per spec §6: Vision **F-22**; SRS `FR-PS-14…` (two lists, rules, read-only, updating, preference) and `FR-ST-*` (dated
plays for 90 days, v2 with migration, unreadable kept aside, no write after a failed set-aside), traceability;
**UC-40: Play the auto playlists** with alternative flows (fallback, empty, preference off, missing songs); UC-28 gains
the switch; Operations data table (history v2, `.bad-` copy); README bullet, roadmap row (no issue) and status line
`UC-01 to UC-40`; docs site; CHANGELOG `[Unreleased]` `Added` and `Changed` (history format, migrated, never reset).
Follow step 4's docs commits (`git log --oneline --grep "describe playlists"`).

- [ ] **Step 1:** write them. **Step 2: Commit** `docs: describe auto playlists`.

---

### Task 5: Verify and open the pull request

- [ ] Once PR #61 is merged: `git fetch`, `git rebase origin/develop`.
- [ ] `flutter analyze` → "No issues found!"; `flutter test` → "All tests passed!"; new files format-clean.
- [ ] Push `feature/auto-playlists`; PR into `develop` titled `feat: auto playlists`, body as PR #61's, ending
  `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.
