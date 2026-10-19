# Export the owner's data to JSON — design

Status: draft for review · 2026-10-18 · branch `feature/export-data` · use case UC-41

## 1. Intent

Step 6 of the owner's library work, added by the owner during step 4. The owner saves everything Orpheus knows about
their music to one JSON file, to keep as a backup, to analyse in any tool they like, or to import somewhere else.
Restoring from that file into Orpheus is **step 7** (agreed): playlists and play history brought back, songs matched by
path and then by tags, merge or replace. This step designs the file so step 7 can read it.

Success: *Preferences → Your data → Export my data…*, choose where, and a readable, documented, versioned JSON file is
there with the library, playlists, auto playlists, play history and statistics; opening it in a text editor, `jq`, a
spreadsheet import or Python makes sense without reading Orpheus's code.

Decisions taken with the owner:

| Question | Decision |
| --- | --- |
| Uses | Backup to restore into Orpheus (step 7), analysis in other tools, import elsewhere. |
| Scope | Export only now; restore is step 7. |
| Where | A *Your data* section in Preferences: *Export my data…* → the save-file dialog, suggested name `orpheus-data-<yyyy-MM-dd>.json` → *Exported* with the location (or *Exported* where the platform gives no path). |
| Songs | Every song in the library: file path, title, artist, album artist, album, track and disc numbers and totals where known, year, genres, length. |
| Artists, albums | Grouped as Orpheus shows them, each listing its songs by reference. |
| Playlists | Name, order, whether it has a custom cover, and each entry with the details saved when it was added. |
| Auto playlists | As they are at that moment, marked automatic. |
| Play history | Each song's play count, last-played time and dated plays. |
| Statistics | Totals and the top tracks, artists, albums and genres, as the statistics screen shows them. |
| About the file | A format version, the Orpheus version, when it was made. |
| Not included | Cover images, audio, preferences. |

## 2. Goals, non-goals, anti-goals

- **Goals:** the decisions above; a schema stable enough to version, documented in the repository; a file a restore
  can match songs from on another machine.
- **Non-goals:** restore/import (step 7); CSV or other formats; choosing which sections to export; exporting covers or
  preferences; scheduled or automatic exports.
- **Anti-goals:** the export changes any of the owner's data or files (it only reads, and writes the one file they
  chose); an export that is silently partial (a section missing because its store is unreadable must be said, not
  omitted); a schema that only Orpheus's code can explain.

## 3. The file

UTF-8 JSON, pretty-printed with two-space indentation *(my call: people will open it)*, keys in a fixed order, times as
ISO-8601 UTC strings, durations as whole milliseconds. Documented in `docs/data-export.md` (new) with every field, its
type and whether it may be absent, and an example. Top level:

```json
{
  "format": "orpheus-data",
  "formatVersion": 1,
  "exportedAt": "2026-10-18T22:30:00.000Z",
  "orpheusVersion": "1.5.0",            // null when unknown
  "songs": [ … ],
  "artists": [ … ],
  "albums": [ … ],
  "playlists": [ … ],
  "autoPlaylists": [ … ],
  "playHistory": [ … ],
  "statistics": { … },
  "problems": [ … ]                       // sections that could not be read, see below
}
```

- **songs** — one per catalog entry, in the library's song order: `id` (a reference used only inside this file —
  `s1`, `s2`, … in song order *(my call)*; a restore matches songs by `path` and tags, never by `id`), `path`, `title`, `artist`, `albumArtist`, `album`,
  `trackNumber`, `trackTotal`, `discNumber`, `discTotal`, `year`, `genres` (array), `durationMs`. Absent tags are
  `null`, never omitted *(my call: stable columns for tools)*. Fields the catalog does not hold (e.g. totals, if
  `TrackMetadata` lacks them) are left out of the schema rather than always null — the builder checks `TrackMetadata`
  and documents exactly what is there.
- **artists** — as the Artists list groups them (`artistsIn`): `name` (null for the untagged group), `songs` (song ids,
  album then track order).
- **albums** — as the Albums list groups them (`albumsIn`): `title` (null for untitled), `albumArtist`, `year` (when all
  its songs agree, else null), `songs` (song ids, track order).
- **playlists** — the owner's, as stored: `id`, `name`, `createdAt`, `modifiedAt`, `hasCustomCover`, `entries` (each:
  `path`, `songId` (the song's id in this file, or null when the song is not in the library — a missing entry),
  `title`, `artist`, `album`, `durationMs` from the entry's saved details). Entry ids are internal and not exported.
- **autoPlaylists** — `kind` (`lately` / `allTime` — the key a restore or a tool should use), `name` (the English names
  `Favourites lately` / `All-time favourites`, never localised *(my call)*), `fallback` (lately only), `songs` (song ids, in order). Included **whatever the *Show auto playlists*
  preference says** *(my call: the preference hides them on screen; it does not decide what the owner's data is)*.
- **playHistory** — every track in the history, including ones not in the library: `path`, `songId` (or null),
  `plays`, `lastPlayedAt`, `recentPlays` (array of times within the last 90 days).
- **statistics** — exactly what the statistics screen shows, from `musicStatsFrom` with its default `rankingLength`:
  `totalPlays`, `distinctTracks`, `untaggedTracks`, and `topTracks`, `topArtists`, `topAlbums`, `topGenres`, each a list
  of `{name, plays, share}` in the screen's order; `share` may be `null` (as `RankedPlays.share`) and is documented as
  nullable. No `songId` here *(my call: `RankedPlays` carries no path and the full per-song numbers are in
  `playHistory`; the statistics section is the screen's summary, not the raw data)*.
- **problems** — empty normally. A problem is reported when a source **could not be read at all**: the playlists
  controller is in error (its store could not be read or set aside), or the play recorder could not read its history
  this run (it exposes this as a new read-only `readFailed` flag — the only change to the stats feature *(my call)*).
  A document that was set aside and replaced by a fresh one is not a problem — the store did its job and the `.bad-`
  copy is on disk. Then the section is an empty array/object **and** a problem entry says which and why (`{"section":
  "playlists", "message": "…"}`); the export still completes and the snackbar says *Exported, but some data could not
  be read* *(my call: a partial backup the owner knows about beats none)*.

## 4. Behaviour

- **Export my data…** reads the current catalog, playlists, history and preference-independent auto playlists, builds
  the document, and offers it to the save-file dialog (`fileSaverProvider`, `safeFileName`). Cancel → nothing.
- While **any** source — the library, the playlists or the play history — is still loading, the export waits for all
  three (a progress indicator on the button) rather than exporting an empty section *(my call)*. If the library failed to load, the export is refused with a message — there
  is nothing meaningful to back up without songs.
- Large libraries: building the document must not freeze the UI for a 20 000-song library — the encoding runs off the
  UI isolate (`Isolate.run` or `compute`) *(my call)*.
- Success: *Exported to <path>* or *Exported*; failure to write: *Couldn't export your data*.

## 5. Architecture

```
lib/features/data_export/
  domain/data_export.dart        pure: build the export document (a Map) from catalog, playlists, autos, history, stats, meta
  application/data_export_controller.dart  gather sources, run the build off the UI isolate, save through FileSaver
  presentation/export_data_tile.dart       the Preferences section's tile and its messages
docs/data-export.md              the schema, documented for people and tools
```

Providers: `dataExportControllerProvider` in `core/di/providers.dart`. Reads `musicLibraryControllerProvider`,
`playlistsControllerProvider`, `playHistoryProvider`, the auto playlist domain functions (computed regardless of the
preference), `musicStatsFrom`, `runningVersionProvider`, `clockProvider`, `fileSaverProvider`.

## 6. Documents

- **Vision:** **F-23 Export my data**; §6 Out of scope keeps "importing" until step 7.
- **SRS:** `FR-DX-01…` (what is exported; the documented, versioned schema; the export only reads and writes the chosen
  file; unreadable sources are reported in the file and on screen; it waits for the library; it does not freeze the
  UI); NFR-03 gains: exporting the owner's data writes only the file they chose; traceability.
- **Use cases:** **UC-41: Export my data** (alternative flows: cancelled; library loading; library failed; a source
  unreadable; write failed), traceability; UC-29 (preferences) names the new section.
- **docs/data-export.md** linked from README and the docs site.
- README bullet + roadmap row + status line `UC-01 to UC-41`; docs site overview; CHANGELOG `Added`.

## 7. Testing

- Domain: a small catalog/playlists/history fixture → the exact document (golden JSON in the test): field order, nulls,
  ids and references, artists/albums grouping, missing playlist entries (`songId: null`), history rows not in the
  library, auto playlists with the fallback flag, statistics equal to `musicStatsFrom`, `problems` empty; with an
  unreadable playlists source → empty `playlists` and one problem.
- Controller: waits for a loading library; refuses a failed library; saves the bytes with the suggested name; cancel;
  write failure; the build runs through the off-isolate helper (inject it for tests).
- Widget: the Preferences section shows *Export my data…*; tap → saver called; snackbars for success, partial,
  failure; disabled while exporting.
- A schema test: the golden document's keys match those listed in `docs/data-export.md` (parse the doc's field table)
  — *builder's choice whether worth it; at least a test that the documented top-level keys equal the built ones*.
- `flutter analyze`, `flutter test`; new files `dart format`-clean.

## 8. Left to the builder

Exact widget layout; string key names (`dataExport…`); whether statistics include `share` for every ranking (as
`RankedPlays` has it); how the off-isolate step is injected for tests.
