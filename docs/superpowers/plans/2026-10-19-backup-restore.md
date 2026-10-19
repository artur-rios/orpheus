# Back up and restore Orpheus — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A full backup ZIP (step 6's JSON + playlist covers + preferences) beside the JSON export, and restore from
either file with per-part Merge / Skip / Replace (default Merge), after confirming the music folders.

**Architecture:** Pure domain pieces build/validate the backup and compute a restore plan (song matching and the three
choices per part); a ZIP codec over `package:archive`; a backup controller like step 6's export controller; a restore
controller that reads a picked file, runs the folders stage (apply + scan), builds the plan and applies it part by
part through new single-write hooks on the playlists controller and the play recorder; a *Your data* section and a
two-stage restore screen.

**Tech Stack:** Flutter 3.47, Riverpod 3, `package:archive` 4.2.0 (made direct), `dart:convert`, `Isolate.run`,
`flutter_test`, ARB (en, pt).

**Spec:** `docs/superpowers/specs/2026-10-19-backup-restore-design.md`

## Global Constraints

- Layering per CONTRIBUTING.md; providers in `core/di/providers.dart`; tests use `Harness` and `test/support` fakes.
- Tests named Given-When-Then, one behaviour each, mirroring `lib/` under `test/`.
- Strings in both ARB files with `@key` descriptions and the same placeholders; keys prefixed `backup…` / `restore…`.
- Restore never touches music files or folders except through stage 1's explicit folder choice; never writes a part
  whose store could not be read (playlists `AsyncError`, recorder `readFailed`); each part is written whole or not at
  all (one store write per part; covers best-effort after the playlists write).
- Nothing is written before the owner presses *Continue* (stage 1) or *Restore* (stage 2); *Cancel* in stage 2 leaves
  the folders as stage 1 set them, and says so.
- Defaults: every part *Merge*. Parts named in data.json's `problems` are disabled.
- Backup format: `backup.json` (`format: "orpheus-backup"`, `formatVersion: 1`), `data.json` (step 6's document),
  `preferences.json`, `covers/<playlistId>`; file name `orpheus-backup-<yyyy-MM-dd>.zip`.
- Formatting: new files `dart format`-clean; edited files keep their surrounding style.
- Commits: lowercase Conventional Commits, ≤50-char subject, body at 72, trailer naming the model that wrote it.

## Review Focus

1. **Restoring onto a device that already has data with the defaults loses nothing** (playlists, plays, settings).
   (Task 2, Task 4.)
2. **A new device with the music under a different folder** matches songs after stage 1 (prefix rewrite, then tags).
   (Task 2, Task 4.)
3. **A backup made while a store was unreadable** cannot wipe real data with Replace. (Task 2, Task 5.)
4. **A corrupt, foreign or newer file** is refused with a message and writes nothing. (Task 1, Task 4.)
5. **A failure part-way** leaves every part whole or untouched, and the summary says which. (Task 4.)

---

### Task 1: The backup file

**Files:** create `lib/features/data_export/domain/backup.dart`, `lib/features/data_export/data/zip_backup_codec.dart`;
modify `pubspec.yaml` (`archive: ^4.2.0` as a direct dependency; run `flutter pub get`, commit pubspec.lock if it
changes); tests under `test/features/data_export/`.

**Produces:**
```dart
class PreferencesSnapshot { /* themeMode, locale, opensPlayerOnPlay, rescansAtStartup, fetchesLyricsOnline,
  checksForUpdatesOnStartup, showsAutoPlaylists, volume, libraryFolders */ Map<String, Object?> toJson(); static PreferencesSnapshot fromJson(Map<String, Object?>); }
class BackupContents { final Map<String, Object?> data; final PreferencesSnapshot? preferences; final Map<String, Uint8List> covers; final DateTime? createdAt; final bool isFullBackup; }
sealed class BackupReadFailure { notABackup, newerVersion(int) }   // as a sealed class or enum + value
Map<String, Object?> backupManifest({required DateTime createdAt, String? orpheusVersion, required List<String> contents});
Uint8List encodeBackupZip({required Map<String, Object?> data, required PreferencesSnapshot preferences, required Map<String, Uint8List> covers, required DateTime createdAt, String? orpheusVersion}); // uses encodeDataExport for data.json
BackupContents readBackup(Uint8List bytes); // ZIP or data JSON; throws a BackupReadFailure
```
- [ ] **Step 1: Write the failing tests:** manifest fields; preferences JSON round trip (null locale, volume);
  ZIP round trip (data, preferences, two covers); a data JSON alone reads with `isFullBackup` false and no
  preferences/covers; refused: random bytes, a ZIP without `backup.json`, a wrong `format`, a newer
  `formatVersion` (backup and data), a ZIP missing `data.json`.
- [ ] **Step 2–4:** FAIL → implement → PASS; analyze clean.
- [ ] **Step 5: Commit** `feat: write and read an orpheus backup`.

---

### Task 2: The restore plan

**Files:** create `lib/features/data_export/domain/restore_plan.dart`; tests.

**Produces:**
```dart
enum RestoreChoice { merge, skip, replace }
class SongMatcher { SongMatcher(List<MusicEntry> library, {String? oldFolder, String? newFolder}); String? match(Map<String, Object?> backupSong); } // path (after prefix rewrite) → tags (title/artist/album case-insensitive trimmed, length ±2 s, exactly one) → null
class PlaylistsOutcome { final List<Playlist> playlists; final Map<String, Uint8List> coversToWrite; final int added, merged, replaced; }
PlaylistsOutcome restorePlaylists(List<Playlist> current, BackupContents backup, SongMatcher matcher, RestoreChoice choice, {required String Function() newId, required DateTime now});
class HistoryOutcome { final PlayHistory history; final int songs, notInLibrary; }
HistoryOutcome restoreHistory(PlayHistory current, BackupContents backup, SongMatcher matcher, RestoreChoice choice, DateTime now);
PreferencesSnapshot? restorePreferences(PreferencesSnapshot current, PreferencesSnapshot defaults, PreferencesSnapshot? backup, RestoreChoice choice); // libraryFolders always kept as current
Set<String> unreadableParts(BackupContents backup); // from data.json problems: 'playlists', 'playHistory'
```
Rules exactly as spec §4's table (playlists by name — most recently modified when several; append entries whose
matched path the target lacks; covers only where none; new ids for every added playlist; history max plays / later
last-played / union of dated plays trimmed to 90 days; preferences Merge = backup value where current equals the
default).

- [ ] **Step 1: Write the failing tests:** matcher (path, rewritten prefix, tags with spaces/case, length 1.9 s vs
  2.1 s, two tag matches → null, unmatched); playlists × {merge, skip, replace} (same name, new name, several same
  name, cover rules, new ids, entries appended without duplicates, unmatched entries keep the backup path and saved
  details); history × each choice (max, later, union, trim, songs only in the backup, notInLibrary count);
  preferences × each choice (default-equality rule, null locale on replace, folders untouched); `unreadableParts`.
- [ ] **Step 2–4:** FAIL → implement → PASS; analyze clean.
- [ ] **Step 5: Commit** `feat: work out what a restore changes`.

---

### Task 3: Backing up from Preferences

**Files:** create `lib/features/data_export/application/backup_controller.dart`,
`lib/features/data_export/presentation/your_data_section.dart` (replaces the step-6 tile's place in
`preferences_dialog.dart`; the JSON export tile keeps its behaviour and moves into the section);
`lib/features/data_export/presentation/about_exports_dialog.dart`; modify `providers.dart`, the Preferences dialog,
ARB files; tests.

**Behaviour:** *Your data*: *Export my data (JSON)…* with its one-line explanation; *Back up Orpheus (ZIP)…* with its
explanation; *About these exports* opens the spec §3 table; (Task 5 adds *Restore from a backup…*). The backup
controller gathers what the export controller gathers (reuse its source-gathering — extract a shared helper rather
than copy), plus the playlist covers (`playlistCoverStoreProvider.read` for each custom cover) and a
`PreferencesSnapshot` from `preferencesControllerProvider` + `settingsStoreProvider.libraryFolders` + volume, builds
the ZIP off the UI isolate, saves `orpheus-backup-<date>.zip` through `fileSaverProvider`; outcomes and their status
line as the JSON tile's (*Backed up to …*, *Backed up, but some data could not be read*, *Couldn't back up Orpheus*,
library failed).

- [ ] **Step 1: Write the failing tests:** controller — the ZIP holds data, preferences and the custom covers; problems
  → partial outcome; suggested name; cancel; failure; one at a time. Widgets — the section shows both exports with
  their explanations and the About entry; About shows the table rows; each backup outcome's status inside the dialog;
  the JSON export still behaves as before (its existing tests pass unchanged or are moved, not weakened).
- [ ] **Step 2–4:** FAIL → strings → implement → PASS (also `test/features/data_export`, `test/features/shell`);
  analyze clean.
- [ ] **Step 5: Commit** `feat: back up orpheus to a zip`.

---

### Task 4: Restoring

**Files:** create `lib/features/data_export/domain/file_opener.dart`, `lib/features/data_export/data/file_picker_file_opener.dart`,
`lib/features/data_export/application/restore_controller.dart`; modify `lib/features/playlists/application/playlists_controller.dart`
(`replaceAll(List<Playlist> playlists, Map<String, Uint8List> covers)` — one list write through the queue, refusing
while unreadable, then covers best-effort, returning the cover ids that failed), `lib/features/stats/application/play_recorder.dart`
(`replaceHistory(PlayHistory)` — one write, publishes to `changes`, refuses when `readFailed`), `providers.dart`
(`fileOpenerProvider`, `restoreControllerProvider`), `test/support` (`FakeFileOpener`); tests.

**Produces:**
```dart
abstract interface class FileOpener { Future<Uint8List?> open({required List<String> extensions}); }
class RestoreController extends Notifier<RestoreState> {
  Future<void> pick();                         // reads off the UI isolate → RestoreState.folders (ZIP) or .choices (JSON), or .failed(reason)
  void chooseFolders(List<String> folders);    // staged
  Future<void> continueToChoices();            // applies staged folders (LibraryFoldersController: whole set), scans, builds the matcher
  void choose(RestorePart part, RestoreChoice choice);
  Future<RestoreSummary> restore();            // applies parts in order playlists, history, preferences; each whole or untouched
  void cancel();
}
```
`RestoreState` carries the stage, the backup's counts and date, folder statuses (found/not found), per-part choices
(default merge), disabled parts (`unreadableParts` + preferences for a JSON), and Replace's counts of what it replaces.
`RestoreSummary` lists per part what was done or why it was refused, and cover failures. After restore, if the folders
changed in stage 1 the scan already ran; the auto playlists/statistics follow the new history by themselves.

- [ ] **Step 1: Write the failing tests:** pick a ZIP → folders stage with statuses; a JSON → choices stage with
  preferences disabled; not a backup / newer → failed, nothing written; chooseFolders + continue → folders set as the
  whole set and a scan requested; restore with defaults onto existing data loses nothing (playlists, plays,
  preferences); Replace replaces; Skip keeps; a part named in problems is disabled and never written; playlists store
  unreadable → that part refused, history still restored; history `readFailed` → refused; a failing cover write →
  playlist kept, cover listed; `replaceAll` and `replaceHistory` each write once; cancel in stage 2 writes nothing.
- [ ] **Step 2–4:** FAIL → implement → PASS (also `test/features/playlists`, `test/features/stats`); analyze clean.
- [ ] **Step 5: Commit** `feat: restore orpheus from a backup`.

---

### Task 5: The restore screen

**Files:** create `lib/features/data_export/presentation/restore_screen.dart`; modify `your_data_section.dart`
(*Restore from a backup…*), ARB files; tests.

**Behaviour (spec §4):** full-screen dialog; stage 1 (folders with found/not found, *Choose folders…* via the folder
picker, the note that *Continue* changes the folders now, *Continue*); stage 2 (what the file holds; three parts with
segmented *Merge / Skip / Replace*, default Merge, a one-line description per choice per part; Replace's warning with
counts; disabled parts with *not in this backup* / *not in this file*; *Restore*, *Cancel*); progress while scanning
and restoring; the summary dialog.

- [ ] **Step 1: Write the failing tests:** each stage's content; defaults Merge; Replace warning; disabled parts;
  choose folders → staged list shown; Continue → stage 2 after the scan; Restore → summary lines; refused part shown;
  a failed read shows its message; Cancel closes; the section entry opens the picker.
- [ ] **Step 2–4:** FAIL → strings → implement → PASS; analyze clean.
- [ ] **Step 5: Commit** `feat: choose what to restore`.

---

### Task 6: Documents

Per spec §6: Vision F-24 and §6; SRS `FR-BK-*`, NFR-03, traceability; UC-42 *Back up Orpheus*, UC-43 *Restore from a
backup* with alternative flows; UC-29 and UC-41 notes; `docs/data-export.md` *Backup file* section (and a schema-doc
test for `backup.json`'s keys, like step 6's); README bullet, roadmap rows (no issues), status line `UC-01 to UC-43`;
docs site; CHANGELOG `Added`. Follow step 6's docs commits (`git log --oneline --grep "exporting the owner"`).

- [ ] **Step 1:** write them (+ the schema test). **Step 2: Commit** `docs: describe backing up and restoring`.

---

### Task 7: Verify and open the pull request

- [ ] `git fetch`; rebase onto `origin/develop` if it moved.
- [ ] `flutter analyze` → "No issues found!"; `flutter test` → "All tests passed!"; new files format-clean.
- [ ] Push `feature/restore-backup`; PR into `develop` titled `feat: back up and restore orpheus`, body as PR #63's,
  ending `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.
