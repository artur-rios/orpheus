# Back up and restore Orpheus — design

Status: draft for review · 2026-10-19 · branch `feature/restore-backup` · use cases UC-42, UC-43

## 1. Intent

Step 7 of the owner's library work. The owner moves Orpheus's state from one device to another, or recovers it after
the data on a device was wiped. Step 6 exports the owner's data to JSON for analysis; this step adds a **full backup
ZIP** (that JSON plus playlist covers and preferences) and **restore** from either file, with a per-part choice of
**Merge**, **Skip** or **Replace**.

Success: on a new computer with the music copied over, *Restore from a backup…* → pick the ZIP → confirm the folders →
*Restore*, and the playlists (with covers), play counts, favourites and preferences are back; on the same device after
a wipe, the same; restoring onto a device that already has playlists and plays never loses anything with the default
choices.

Decisions taken with the owner:

| Question | Decision |
| --- | --- |
| Scenarios | Move Orpheus from one device to another; recover after the data on a device was wiped. |
| Formats | JSON stays the core (step 6, unchanged). A **backup ZIP** holds that JSON, the playlist covers and the preferences. |
| Choosing | *Preferences → Your data* offers ***Export my data (JSON)…*** and ***Back up Orpheus (ZIP)…***, each with a one-line explanation, and an ***About these exports*** link showing the comparison table (§3). |
| Restore | *Restore from a backup…* in the same section; accepts a backup ZIP or a data JSON. From a JSON, covers and preferences are not restored, and it says so. |
| Folders | The backup records the music folders; restore shows them, and where they don't exist on this device asks the owner to choose the right folders. |
| Choices | **Separately for playlists, play history and preferences**, each **Merge** / **Skip** / **Replace**, each defaulting to **Merge**. |

## 2. Goals, non-goals, anti-goals

- **Goals:** the decisions above on Windows, Linux and Android; nothing lost with the defaults; the owner sees what
  will happen before anything is written.
- **Non-goals:** restoring the library itself (songs come from the music files and a scan); backing up audio or the
  library's cover cache; cloud or scheduled backups; restoring a backup from a newer `formatVersion` than this release
  understands (refused with a message); partial selection inside a part (individual playlists).
- **Anti-goals:** a restore that half-applies and leaves the owner's data inconsistent; Replace without the owner
  seeing what it replaces; a restore that writes over a file Orpheus could not read (the step 4/5 rule); any change to
  the owner's music files or folders.

## 3. The two exports

The *About these exports* text and the Preferences explanations say exactly this:

| | Export my data (JSON) | Back up Orpheus (ZIP) |
| --- | --- | --- |
| For | Looking at your data in other tools, importing elsewhere | Restoring Orpheus on this or another device |
| Songs, artists, albums (as a list) | ✓ | ✓ |
| Playlists | ✓ | ✓ |
| Auto playlists (as they are now) | ✓ | ✓ |
| Play history and statistics | ✓ | ✓ |
| Playlist cover pictures | — | ✓ |
| Preferences (incl. music folders) | — | ✓ |
| Your music files | — | — |

**The ZIP** (`orpheus-backup-<yyyy-MM-dd>.zip`, built off the UI isolate like the JSON):

```
backup.json            {"format": "orpheus-backup", "formatVersion": 1, "createdAt", "orpheusVersion",
                        "contents": ["data.json", "preferences.json", "covers/…"]}
data.json              exactly step 6's export document
preferences.json       {"themeMode", "locale", "opensPlayerOnPlay", "rescansAtStartup", "fetchesLyricsOnline",
                        "checksForUpdatesOnStartup", "showsAutoPlaylists", "volume", "libraryFolders": [...]}
covers/<playlistId>    each playlist's custom cover bytes (JPEG/PNG), named by the id in data.json's playlists
```

Not included: `skippedUpdateVersion` (device-local) *(my call)*. Documented in `docs/data-export.md` (a new *Backup
file* section).

## 4. Restore

**Reading.** *Restore from a backup…* opens a file picker for `.zip` or `.json`. A ZIP must contain a `backup.json`
with `format: "orpheus-backup"` and a supported `formatVersion`, and a `data.json` with `format: "orpheus-data"` and a
supported `formatVersion`; a JSON must be the latter. Anything else → *This isn't an Orpheus backup* and nothing
happens. A newer version → *This backup is from a newer Orpheus — update first*. Reading happens off the UI isolate.

**The restore screen** (a full-screen dialog) has two stages *(my call: songs can only be matched against the library
once the music is where Orpheus looks)*.

**Stage 1 — Your music** (ZIP only; a JSON skips to stage 2). The backup's music folders, each marked *found on this
device* or *not found* (`Directory(path).existsSync()`), and this device's current folders. *Choose folders…* lets the
owner set this device's folders — the chosen set **becomes the whole set** (folders not chosen are removed); the
choice is staged, not written. *Continue* applies a changed set (through `LibraryFoldersController`) and runs a scan
with progress, then moves to stage 2; *Continue* with no change moves on at once (if the library is stale or empty it
still scans first). The screen says plainly that *Continue* changes the library folders now, and that cancelling later
keeps them. `libraryFolders` in preferences.json is never applied any other way.

**Stage 2 — What to restore** shows, before anything else is written:

- what the file holds: the date, *N playlists*, *N songs with plays*, whether covers and preferences are included;
- **A part the backup could not read** (named in data.json's `problems` — e.g. its playlists store was unreadable
  when the backup was made) is disabled with *not in this backup*, so Replace can never wipe real data with an empty
  section; a `songs` problem only means fewer songs to match by;
- **Playlists**, **Play history**, **Preferences** (the last disabled for a JSON, with *not in this file*): each with
  *Merge* / *Skip* / *Replace* (segmented buttons), default *Merge*, and a one-line description of what that choice
  does for that part;
- **Replace** shows what it removes (*Replaces your 4 playlists*, *Replaces play counts for 1 230 songs*);
- *Restore* and *Cancel*.

**Matching songs** (after stage 1's scan). When the backup had exactly one music folder and this device has exactly
one, a backup path under the old folder is first rewritten to the same relative path under the new one *(my call)*.
Then backup songs are matched to this device's library: first by `path`; if none, by tags — same
`title`, `artist`, `album` (case-insensitive, trimmed) and length within 2 seconds, and only when exactly one library
song matches *(my call)*. A matched song's backup data is applied to the **library song's path**. Unmatched songs keep
their backup path (they become "missing" until the files appear — the step 4 rule).

**The three choices**, per part:

| Part | Merge | Skip | Replace |
| --- | --- | --- | --- |
| Playlists | Backup playlists whose name isn't here are added. A playlist with the same name (the most recently changed one, if several share it) gets the backup's entries whose matched path it doesn't hold, appended in the backup's order. A custom cover is restored only where this device's playlist has none. | Only backup playlists whose name isn't here are added; existing playlists untouched. | All playlists here are removed and the backup's are created, covers included. |
| Play history | Per song: `plays` = the higher of the two; `lastPlayedAt` = the later; dated plays = the union (deduplicated, trimmed to 90 days). Songs only in the backup are added. | Only songs with no history here are added. | The history here is replaced by the backup's. |
| Preferences | The backup's values are applied for settings whose value here **equals the default** (the store cannot tell "unset" from "set to the default"); the rest stay. | Nothing changes. | All eight values are applied, including volume and a `null` locale (follow the system). |

Music folders are never changed by these choices — only by stage 1. **Playlist ids:** every playlist a restore adds
gets a new id and fresh entry ids from the id generator (a backup's id may collide with one here); its cover is
written under the new id *(my call)*.

**Applying.** One restore runs at a time. It writes the playlists (through `PlaylistsController`, one write of the
whole new list, then the covers best-effort — a cover that fails to write is reported in the summary, the playlist
stays) and the history (through the play history store, one write), then the covers and preferences; if a
store could not be read (`AsyncError` / `readFailed`), that part is refused with its reason and nothing of it is
written *(the step 4/5 rule)*. A failure part-way reports which parts were restored and which were not; parts already
written stay (each part is written atomically by its store) *(my call: no cross-store transaction; each part is whole
or untouched)*. After a restore, the auto playlists and statistics follow from the new history by themselves, and a
rescan is started if the folders changed.

**Result.** A summary dialog: *Restored: 3 playlists added, 1 merged; play history for 1 180 songs (12 not in your
library); preferences applied* — and *Couldn't restore: …* lines for any refused part.

**A backup with problems** is still saved, like the JSON (the result says *Backed up, but some data could not be
read*); restore then disables those parts as above.

## 5. Architecture

```
lib/features/data_export/
  domain/backup.dart                  pure: build the backup manifest + preferences.json; parse and validate a backup/data file
  domain/restore_plan.dart            pure: match songs; compute each part's result for Merge/Skip/Replace (new playlists list, new history, preferences to apply) + counts for the screen
  data/zip_backup_codec.dart          encode/decode the ZIP (package:archive)
  application/backup_controller.dart  gather sources (+ covers, preferences), build the ZIP off the UI isolate, save
  application/restore_controller.dart read a picked file, build the plan, apply it part by part
  presentation/your_data_section.dart the Preferences section (two exports, About, Restore)
  presentation/restore_screen.dart    the restore screen and the summary
```

- `package:archive` becomes a **direct dependency** at the version already locked (4.2.0) *(my call)*.
- A file **opener** boundary for restore (`FileOpener.open(extensions) → bytes?` over file_picker), in
  `core/di/providers.dart`, faked in tests.
- `PlaylistsController` gains `replaceAll(List<Playlist>, covers)` (one write, refusing while unreadable) for restore;
  the play history store / recorder gains a `replaceHistory(PlayHistory)` that writes once and publishes the change
  (refusing when `readFailed`). Preferences are applied through the existing setters.

## 6. Documents

- **Vision:** F-24 Back up and restore; §6 Out of scope drops "importing" for Orpheus's own backups (other apps'
  formats stay out).
- **SRS:** `FR-BK-*` (the ZIP and its contents; the two exports explained; restore reads ZIP or JSON, validates,
  refuses newer versions; the restore screen shows effects before writing; folders; per-part Merge/Skip/Replace rules;
  song matching; refusal over unreadable stores; per-part atomicity and the summary); NFR-03 (restore never touches
  music files); traceability.
- **Use cases:** **UC-42: Back up Orpheus**, **UC-43: Restore from a backup** (alternative flows: not a backup; newer
  version; JSON without covers/preferences; folders not found; each choice; a store unreadable; a failure part-way;
  cancel); UC-29 names the section's new entries; UC-41 notes the JSON is one of two exports.
- `docs/data-export.md`: the *Backup file* section; README bullet, roadmap rows, status line `UC-01 to UC-43`; docs
  site; CHANGELOG `Added`.

## 7. Testing

- Domain: manifest and preferences.json build; validation (wrong format, newer version, missing data.json); matching
  (path, tags, ambiguous tags → unmatched, length tolerance); each part × each choice with fixtures (playlists by name,
  entries appended, covers only where none; history max/later/union/trim; preferences only-defaults rule).
- Codec: ZIP round trip (data, preferences, covers); a ZIP without backup.json refused.
- Controllers: backup saves the ZIP with covers and preferences; restore from ZIP and from JSON; Replace/Merge/Skip
  applied; an unreadable playlists store refuses that part only; a failure part-way reports it; folders changed →
  rescan.
- Widgets: the section's two exports with explanations, About table, Restore; the restore screen (counts, folder
  status, choices default Merge, Replace's warning, Preferences disabled for JSON); the summary.
- `flutter analyze`, `flutter test`; new files `dart format`-clean.

## 8. Left to the builder

Widget structure; string key names (`backup…`, `restore…`); how the 2-second length tolerance and case folding are
written; where the About text lives (a dialog is fine); ZIP compression level.
