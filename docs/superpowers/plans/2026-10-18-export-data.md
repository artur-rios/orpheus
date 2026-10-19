# Export the owner's data to JSON — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** *Preferences → Your data → Export my data…* writes one documented, versioned JSON file with the library,
playlists, auto playlists, play history and statistics.

**Architecture:** A pure builder turns the sources into an ordered `Map` (the document); a controller waits for the
sources, notes unreadable ones as problems, encodes off the UI isolate and saves through the existing `FileSaver`; a
Preferences section offers it. The schema is documented in `docs/data-export.md`.

**Tech Stack:** Flutter 3.47, Riverpod 3, `dart:convert`, `dart:isolate` (`Isolate.run`), `flutter_test`, ARB (en, pt).

**Spec:** `docs/superpowers/specs/2026-10-18-export-data-design.md`

## Global Constraints

- Layering per CONTRIBUTING.md: `domain` has no Flutter and no IO; providers in `core/di/providers.dart`; tests use
  `Harness` and the `test/support` fakes (`FakeFileSaver`, `FakePlaylistStore`, the history fakes).
- Tests named Given-When-Then, one behaviour each, mirroring `lib/` under `test/`.
- Strings in both ARB files with `@key` descriptions and the same placeholders; keys prefixed `dataExport…`.
- The export **only reads** the owner's data and writes only the file they chose.
- JSON: UTF-8, two-space indentation, keys in the documented order, times ISO-8601 UTC, durations whole ms, absent tags
  `null` (never omitted). `format: "orpheus-data"`, `formatVersion: 1`.
- Song fields are exactly what `TrackMetadata` holds: `path`, `title`, `artist`, `albumArtist`, `album`,
  `trackNumber`, `trackTotal`, `discNumber`, `year`, `genres`, `durationMs` (no disc total — the catalog has none).
- Auto playlists are exported whatever the preference; names in English (`Favourites lately`, `All-time favourites`),
  `kind` `lately` / `allTime`.
- Formatting: new files `dart format`-clean; edited files keep their surrounding style.
- Commits: lowercase Conventional Commits, ≤50-char subject, body at 72, trailer naming the model that wrote it.

## Review Focus

1. **A large library** (20 000 songs) does not freeze the UI while exporting. (Task 2.)
2. **An unreadable playlists store or history** shows in `problems` and in the snackbar, never as a silently empty
   section. (Task 1, Task 2.)
3. **Missing playlist entries and history rows not in the library** carry `songId: null` and keep their path and
   saved details. (Task 1.)
4. **Non-ASCII tags and Windows paths** survive the round trip `jsonDecode(utf8.decode(bytes))`. (Task 1.)
5. **Tapping Export while the library is still loading** waits, then exports the full library. (Task 2.)

---

### Task 1: Building the export document

**Files:** create `lib/features/data_export/domain/data_export.dart`; tests under `test/features/data_export/domain/`.

**Produces:**
```dart
class ExportProblem { const ExportProblem(this.section, this.message); final String section, message; }
class ExportSources {
  final List<MusicEntry> songs;            // the catalog, in library song order (songsIn)
  final List<Playlist> playlists;
  final PlayHistory history;
  final DateTime now;                       // exportedAt, and the auto playlists' "now"
  final String? orpheusVersion;
  final List<ExportProblem> problems;
}
Map<String, Object?> buildDataExport(ExportSources sources); // the ordered document (LinkedHashMap) per spec §3
Uint8List encodeDataExport(Map<String, Object?> document);   // UTF-8, two-space indented, trailing newline
```
Rules: songs `s1…` in the given order; artists via `artistsIn`, albums via `albumsIn` (album `year` when all its songs
agree, else null), each listing song ids in their grouping's order; playlists with `hasCustomCover` = `coverId != null`
and entries `{path, songId|null, title, artist, album, durationMs}`; autoPlaylists from `favouritesLately` /
`allTimeFavourites` (with `fallback` on lately); playHistory every track `{path, songId|null, plays, lastPlayedAt,
recentPlays}`; statistics from `musicStatsFrom(history, catalog)` with default `rankingLength` → `{totalPlays,
distinctTracks, untaggedTracks, topTracks, topArtists, topAlbums, topGenres}` each `[{name, plays, share|null}]`;
`problems` `[{section, message}]`.

- [ ] **Step 1: Write the failing tests:** a golden test — a fixture of 4 songs (one untagged, one with a non-ASCII
  title and a Windows path), 2 playlists (one entry missing from the library, one custom cover), a history (one row
  not in the library, recent plays), fixed `now` and version → `encodeDataExport(buildDataExport(...))` equals a golden
  string in the test exactly; plus focused tests: absent tags are present as `null`; top-level key order; album year
  null when songs disagree; auto playlists present with the preference irrelevant (domain has no preference) and the
  fallback flag; statistics equal `musicStatsFrom`'s numbers; problems carried through; `jsonDecode(utf8.decode(...))`
  round-trips the non-ASCII title and the path.
- [ ] **Step 2–4:** FAIL → implement → PASS; analyze clean.
- [ ] **Step 5: Commit** `feat: build the data export document`.

---

### Task 2: Exporting from Preferences

**Files:** create `lib/features/data_export/application/data_export_controller.dart`,
`lib/features/data_export/presentation/export_data_tile.dart`; modify `lib/core/di/providers.dart`,
`lib/features/stats/application/play_recorder.dart` (a public read-only `bool get readFailed`),
`lib/features/shell/presentation/preferences_dialog.dart` (a *Your data* section with the tile), both ARB files; tests.

**Produces:**
```dart
enum DataExportOutcome { saved, savedWithProblems, cancelled, libraryFailed, failed }
class DataExportResult { final DataExportOutcome outcome; final String? path; }
final dataExportControllerProvider = NotifierProvider<DataExportController, bool /* exporting */>(...);
class DataExportController extends Notifier<bool> { Future<DataExportResult> export(); }
final dataExportEncoderProvider = Provider<Future<Uint8List> Function(ExportSources)>(...); // default: Isolate.run(() => encodeDataExport(buildDataExport(s))); tests override with a direct call
```
Behaviour (spec §4): one export at a time (`state` true while running); await `musicLibraryControllerProvider.future`
(failed → `libraryFailed`), `playlistsControllerProvider.future` (error → empty playlists + problem
`playlists`), `playHistoryProvider.future` plus `playRecorderProvider.readFailed` (→ empty history + problem
`playHistory`); build `ExportSources` with `clockProvider()` and `runningVersionProvider`; encode via
`dataExportEncoderProvider`; `fileSaverProvider.save(suggestedName: 'orpheus-data-<yyyy-MM-dd>.json', bytes:)` (local
date) → null = `cancelled`; throw = `failed`; else `saved` / `savedWithProblems` with the path.

Tile: *Your data* heading; *Export my data…* (`ListTile` or button) with a progress indicator while exporting and
disabled then; snackbars: *Exported to <path>* / *Exported* (no path) / *Exported, but some data could not be read* /
*Couldn't export your data* / *Your library couldn't be read, so there's nothing to export*; cancel → nothing.

- [ ] **Step 1: Write the failing tests:** controller — waits for a loading library then exports all songs; library
  failed → `libraryFailed`, saver not called; playlists in error → `savedWithProblems` and the document's `problems`
  names `playlists`; history read failed → `savedWithProblems`; saver gets the suggested name with the clock's date
  and bytes that decode to the document; cancel → `cancelled`; saver throws → `failed`; a second export while one runs
  is ignored; the default encoder runs `buildDataExport` off the UI isolate (assert it via an injected runner, not a
  real isolate). Widget — the Preferences dialog shows *Your data* and *Export my data…*; tap → saved snackbar with the
  path; partial, failed and library-failed snackbars; disabled while exporting; recorder `readFailed` true after a
  failed read, false otherwise.
- [ ] **Step 2–4:** FAIL → strings + gen-l10n → implement → PASS (also `test/features/stats`,
  `test/features/shell`); analyze clean.
- [ ] **Step 5: Commit** `feat: export the owner's data from preferences`.

---

### Task 3: The schema document and the requirement documents

**Files:** create `docs/data-export.md`; modify Vision, SRS, Use Case Specification, README, docs site overview (and
a link from the site), CHANGELOG; a test `test/features/data_export/schema_doc_test.dart`.

- [ ] **Step 1:** `docs/data-export.md`: purpose (backup, analysis, import elsewhere; restore comes in a later
  version), the top-level keys in order, a field table per section (name, type, nullable, meaning), how references work
  (`songId` → `songs[].id`, file-local; match by path and tags), the `problems` array, versioning rules, and a short
  example document.
- [ ] **Step 2: Write the failing test** `GivenTheSchemaDocument_WhenItsTopLevelKeysAreRead_ThenTheyMatchTheBuiltDocument`
  (parse the top-level key list from a fenced block or table in `docs/data-export.md`, compare with
  `buildDataExport(...)`'s keys in order). Run → FAIL until the doc lists them; then PASS.
- [ ] **Step 3:** Vision **F-23 Export my data**; SRS `FR-DX-01…` (what is exported; documented, versioned schema; reads
  only, writes the chosen file; unreadable sources reported; waits for sources; UI never frozen) and NFR-03; UC-41
  *Export my data* with alternative flows (cancelled; library loading; library failed; a source unreadable; write
  failed) and traceability; UC-29 names the *Your data* section; README bullet linking `docs/data-export.md`, roadmap
  row (no issue), status line `UC-01 to UC-41`; docs site overview row; CHANGELOG `[Unreleased]` `Added`. Follow
  step 5's docs commit (`git log --oneline --grep "describe auto playlists"`).
- [ ] **Step 4: Commit** `docs: describe exporting the owner's data`.

---

### Task 4: Verify and open the pull request

- [ ] `git fetch`; rebase onto `origin/develop` if it moved.
- [ ] `flutter analyze` → "No issues found!"; `flutter test` → "All tests passed!"; new files format-clean.
- [ ] Push `feature/export-data`; PR into `develop` titled `feat: export my data to json`, body as PR #62's, ending
  `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.
