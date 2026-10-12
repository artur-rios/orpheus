# Autofill tags from MusicBrainz — design

Status: draft for review · 2026-10-12 · branch `feature/autofill-tags` (built on `fix/review-and-metadata-refresh`, PR #44,
whose startup rescan of re-tagged files this feature relies on)

## 1. Intent

The owner corrects or completes the tags of their own files from an outside source, without leaving Orpheus and without
anything being written that they did not see and confirm.

- They choose **which tags** to fill, each time.
- Orpheus looks the record (or a lone track) up on **MusicBrainz**, proposes values, and shows **every change, file by
  file, as old → new**, each with its own checkbox.
- Only the changes they confirm are written — **into the files and into the library** — and the rest of the
  application picks them up through the same rescan that brings in tags edited elsewhere.

Success: a mis-tagged record (a misspelt artist, missing track numbers, no year, no cover) becomes correctly tagged in
two or three clicks when the first match is right, and is still recoverable — another release, another search, or
unticking — when it is not. Nothing is ever written to a file the owner did not confirm a change for, and no tag the
owner did not choose is altered or lost.

Decisions taken during brainstorming:

| Question | Decision |
| --- | --- |
| Where do confirmed changes go? | Always both: the audio file's own tags, and the library. |
| Product promise | Rewritten: files may be written, **for their metadata only**, and only on confirmation. |
| Source | MusicBrainz, plus the Cover Art Archive for covers. No API key, no account. |
| Scope | A record at a time, and a lone track for files outside a record. Artist-wide and library-wide batches are out. |
| Tags offered | Title, artist, album artist, album, track no./total, disc no./total, year, genre, cover (cover unticked by default). |
| Existing values | A ticked tag **replaces** what is there; the review screen is the safeguard. |
| Platforms | Windows, Linux and Android. On Android, write access is asked for at the first confirmed write. |
| Matching UX | Best match preselected, other candidates one tap away, query editable (approach A). |

## 2. Product and documentation changes

This feature reverses two stated promises, so the documents change with it, in the same pull request.

- **Vision Document**
  - Positioning statement: "reads only what it was pointed at, never writes to an audio file" becomes "reads only what it
    was pointed at, and writes to an audio file only to change its tags, when the owner confirms each change".
  - **C-03** becomes: *The owner's audio files are opened for reading, and written only to change their metadata —
    never renamed, moved, deleted or re-encoded — and only for changes the owner has confirmed.*
  - **C-02** gains MusicBrainz and the Cover Art Archive beside the lyrics lookup and the update check, as lookups that
    happen only when the owner starts an autofill.
- **README** — *It never touches your audio files* becomes *It changes your files only when you ask*: the one change it
  makes to an audio file is to its tags, from an autofill whose every change you confirmed. *Almost no network* gains
  the third exception. The Android permission count goes from eight to nine.
- **Use Case Specification** — new **UC-34: Autofill a record's tags** (main flow, the alternative flows of §6, and
  traceability to new `FR-AF-*` requirements in the System Requirements Document).
- **AndroidManifest.xml** — `WRITE_EXTERNAL_STORAGE` with `android:maxSdkVersion="29"`, commented in the manifest's
  own voice; the comments on `MANAGE_EXTERNAL_STORAGE` and `INTERNET` updated for their new uses.
- **CI** — the permission pin in `verify.yml` and `release.yml` moves from eight to nine.
- **CHANGELOG** — `### Added` under `[Unreleased]`.

## 3. Architecture

A new feature folder, `lib/features/autofill/`, laid out like the others. Nothing outward is constructed anywhere but
`core/di/providers.dart`.

### 3.1 Domain (no Flutter, no IO)

- **`AutofillField`** — `title, artist, albumArtist, album, trackNumber, trackTotal, discNumber, discTotal, year,
  genre, cover`.
- **`ReleaseCandidate`** — a MusicBrainz release as the search answers it: `id`, `title`, `artistCredit`, `date`,
  `country`, `status`, `primaryType`, `format`, `disambiguation`, `trackCount`, `score`.
- **`ReleaseDetail`** — one release in full: the candidate's fields plus `discCount` and `tracks`
  (`disc`, `position`, `title`, `artistCredit`, `length`), `genres` (name, votes) and `releaseGroupId`.
- **`MetadataSource`** (interface)
  - `Future<List<ReleaseCandidate>> searchReleases(ReleaseQuery query)`
  - `Future<ReleaseDetail> release(String id)`
  - `Future<List<String>> releaseGroupGenres(String releaseGroupId)` — the fallback when a release has none
  - `Future<List<RecordingMatch>> searchRecordings(RecordingQuery query)` — for a lone track
  - `Future<Uint8List?> frontCover(String releaseId)` — `null` where there is none
  - Throws `MetadataSourceException(kind)` with `kind` ∈ `unreachable, rateLimited, notFound, malformed`.
- **`TagWriter`** (interface)
  - `Set<AutofillField> writableFields(String path)` — empty for a format that cannot be written at all.
  - `Future<WriteOutcome> write(String path, Map<AutofillField, Object?> values, {required AudioFile expected})` —
    `expected` is the file as the catalog knows it; a size or timestamp that differs is refused as
    `changedSinceRead`.
  - `WriteOutcome` ∈ `written, unsupported, changedSinceRead, inUse, denied, failed`.
- **Matching** (pure functions, the heart of the feature, exhaustively tested):
  - `rankCandidates(List<ReleaseCandidate>, RecordContext) → List<ReleaseCandidate>` — see §4.2.
  - `assignTracks(List<MusicEntry> files, ReleaseDetail) → Map<MusicEntry, ReleaseTrack?>` — see §4.3.
  - `proposalsFor(assignment, ReleaseDetail, Set<AutofillField>, {Uint8List? cover}) → List<FileProposal>` — see §4.4.
- **`FileProposal`** — `entry`, `track` (or `null`: no match), `blockedBecause` (unsupported format, or a field the
  format cannot hold), and `changes`: `List<FieldChange>`.
- **`FieldChange`** — `field`, `before`, `after`, `accepted` (default `true`).

### 3.2 Data

- **`MusicBrainzSource implements MetadataSource`**
  - `http.Client` injected, as `LrclibLyricsSource` does; base `https://musicbrainz.org/ws/2/`, `fmt=json`.
  - User-Agent `Orpheus/<version> ( https://github.com/artur-rios/orpheus )` — required by MusicBrainz.
  - **One request per second**, enforced by a single throttle inside the one instance the provider binds, so two
    autofills back to back cannot exceed it. The clock and the delay are injected for tests.
  - 503 → one retry after 2 s, then `rateLimited`. Timeout 15 s → `unreachable`.
  - Endpoints:
    - `release?query=<lucene>&limit=10` — `release:"<album>" AND artist:"<album artist>"`, terms escaped.
    - `release/<id>?inc=recordings+artist-credits+genres+release-groups+media`.
    - `release-group/<id>?inc=genres`.
    - `recording?query=recording:"<title>" AND artist:"<artist>" AND dur:[<ms-3000> TO <ms+3000>]&limit=10`
      (the duration clause dropped when the file's duration is unknown).
  - Covers: `https://coverartarchive.org/release/<id>/front-500`, redirects followed, 404 → `null`, also throttled.
- **`AudioMetadataTagWriter implements TagWriter`**
  - `updateMetadata` from `audio_metadata_reader` (already a dependency), run on an isolate. It writes a temporary file
    and renames it into place, so a failed write leaves the original untouched.
  - Field support per format, mapped explicitly rather than through the package's common setters, because those have
    no album artist and silently ignore what a format cannot hold:

    | Field | MP3 (ID3v2) | FLAC | M4A/MP4 | WAV | APE |
    | --- | --- | --- | --- | --- | --- |
    | title, artist, album, track no., year, genre, cover | ✓ | ✓ | ✓ | ✓ (cover: verify) | ✓ |
    | album artist | `TPE2` | `ALBUMARTIST` | ✗ (no `aART` in the model) | ✗ | ✓ |
    | track total | ✓ | ✓ | verify | ✗ | verify |
    | disc no. / total | ✓ | ✓ | no. only (verify) | ✗ | verify |

    "verify" cells are settled by the preservation tests below before the format is enabled; a field a format cannot
    hold is shown on that file's card as not writable for that format, never written partially.
  - **Preservation gate.** A format is reported writable only once a test proves that writing the chosen fields leaves
    every other tag in the file intact — including tags the package's model does not represent (ID3 `COMM`/`TXXX`/
    `SYLT`/`USLT`, Vorbis custom comments, MP4 `aART`/freeform atoms, embedded pictures when cover is not chosen). A
    format that loses anything is unwritable until it does not. OGG, Opus, AIFF and Matroska are unwritable from the
    start: the package cannot write them.
  - Refuses `changedSinceRead` by comparing size and timestamp with `expected` before writing; reports a Windows
    sharing violation on the rename as `inUse`, a permission error as `denied`.

### 3.3 Application

- **`AutofillController`** — an auto-disposed notifier per session (one record or one track):
  - States: `searching → reviewing → writing → finished`, plus `failed(kind)` for a search that could not run.
  - Holds `fields`, `query`, `candidates`, the chosen `ReleaseDetail`, the `proposals` with their ticks, write progress,
    and per-file `WriteOutcome`s.
  - Actions: `start(entries, fields)`, `chooseRelease(id)`, `search(text)`, `toggle(file, field)`, `toggleFile`,
    `toggleAll`, `write()`, `cancel()`, `retry(failedOnly)`.
  - `write()` first asks `LibraryAccessController.ensureWritable(paths)` (Android; always granted on the desktops),
    then writes one file at a time — the playing file last — then calls `ScanController.rescanSoon()`.
- **`ScanController.rescanSoon()`** — new: starts a scan, or, if one is running, marks it owed another one regardless
  of folders (generalising the pending-rescan flag added in PR #44), so a scan that already passed the written files
  cannot leave the old tags in the library.
- **`LibraryAccessController.ensureWritable`** — new: on Android 11+ asks for all-files access with an explanation
  first; on Android 7–10, `WRITE_EXTERNAL_STORAGE`; elsewhere granted. A refusal is reported, with the settings page
  offered when it is permanent — the pattern the folders screen already uses.
- **The remembered field choice** — `SettingsStore` key `autofillFields`, defaulting to every field but `cover`.

### 3.4 Presentation

- Entry points: **Autofill tags…** in an album's actions (`_GroupActions`, beside play and shuffle) and in a track's
  menu (`MusicRowMenu`), on all three platforms.
- **Field dialog** — the checklist, the remembered choice, *Find* and *Cancel*. If no file in the selection is
  writable, it says so and offers nothing to find.
- **Review screen** (a full-screen route):
  - Header: the matched release — title, artist credit, year, country, format, disambiguation — and **Different
    release**, a list of the other candidates (choosing one fetches it and rebuilds the proposals).
  - A search field holding the query, editable, with *Search again*.
  - One card per file: its name, then each change as `Artist  Radiohed → Radiohead` with a checkbox; cover changes as two
    thumbnails. A card with a tick-all toggle. Files with no match or no writable fields shown greyed with the reason.
  - Footer: **Write N changes to M files**, disabled at zero; a global tick-all.
  - While writing: progress (*Writing 4 of 12*), *Cancel*.
  - When finished: *12 files updated*, then each file that was not, named with its reason, and *Try again* for the
    `inUse` and `failed` ones.
- All strings in both catalogs; colours from the theme only (the existing guard tests enforce both).

## 4. Behaviour in detail

### 4.1 Building the query

- Record: `album` and `albumArtist` of the entries (the most common non-blank value of each); where the album is
  blank, the folder name; where the artist is blank, the clause is dropped.
- Lone track: `title` and `artist`, the file's duration for the `dur` range; a blank title falls back to the file name
  without its extension and any leading track number.

### 4.2 Ranking release candidates

Using only what the search response carries (no extra requests):

1. Track count equal to the number of files in the selection.
2. `status` official before promotion before bootleg/pseudo-release.
3. Normalised title equal (case-, accent- and punctuation-insensitive), then contained.
4. Normalised artist credit equal, then contained.
5. MusicBrainz `score`.
6. Earliest date, then id, so the order is stable.

The first is fetched in full and preselected. For a lone track, the recording's releases are ranked the same way,
preferring `primaryType` album over single and EP, and compilations last.

### 4.3 Assigning files to tracks

In order, each step only over what is still unassigned:

1. Disc and track number both present and equal (a missing disc counts as 1, as the library's ordering does).
2. Normalised title equal.
3. Normalised title similar (token overlap ≥ 0.6) and duration within 5 s.
4. Duration within 2 s, when it singles out exactly one track.

A track can be assigned once; a file left over is *no match on this release*.

### 4.4 Proposing changes

For each assigned, writable file and each chosen field the format can hold, a `FieldChange` where the new value
differs from the current one (compared after trimming; numbers as numbers). Unchanged values are not listed.

- **artist** — the track's artist credit, joined with MusicBrainz's join phrases.
- **album artist** — the release's artist credit, so a compilation reads *Various Artists*.
- **year** — the release's own date's year.
- **genre** — the release's top-voted genre, else the release group's, else no change.
- **cover** — the release's front cover, fetched once per release; offered only where it differs from the embedded one
  (by bytes).
- **track/disc totals** — from the release's media.

## 5. Data flow

```
field dialog ──start──▶ AutofillController ──searchReleases/release──▶ MusicBrainzSource ──▶ musicbrainz.org
                              │ rankCandidates, assignTracks, proposalsFor (domain)
                              ▼
                        review screen ◀── ticks, chooseRelease, search
                              │ write
                              ▼
            LibraryAccessController.ensureWritable ──▶ TagWriter (isolate) ──▶ the files
                              │
                              ▼
                   ScanController.rescanSoon ──▶ catalog ──▶ every screen, the player, the session
```

## 6. Errors and edge cases

| Case | Behaviour |
| --- | --- |
| No file in the selection is writable | The field dialog says so; nothing is looked up. |
| Some files are not writable | Shown greyed with the reason; nothing proposed for them. |
| No network, timeout, 5xx | *MusicBrainz could not be reached*, *Try again*. |
| 503 (rate-limited) | One retry after 2 s, then as above. |
| No results | *Nothing found*, the search field focused. |
| Two files claim one track | The closer one gets it; the other is *no match*. |
| Typographic punctuation from MusicBrainz | Shown as a change like any other; untickable. |
| File changed since it was read | Skipped and named: never overwrite an edit made elsewhere in the meantime. |
| The playing file on Windows | Written last; if Windows refuses, *in use by playback*, with *Try again*. |
| Read-only file, permission error | Skipped and named; the rest proceed. |
| Android write access refused | Nothing written; the reason, and the settings page when the refusal is permanent. |
| Cover will not download | That change dropped with a note; the rest proceed. |
| Cancel while writing | Stops after the current file; what was written stays written and is rescanned. |
| Crash or power cut mid-write | The original is intact: the writer renames a finished temporary file into place. |

## 7. Testing

Given-When-Then, mirroring `lib/`; nothing reaches the network or writes into a real library.

- **Domain** — `rankCandidates`, `assignTracks` (numbers, titles, durations, collisions, missing discs),
  `proposalsFor` (unchanged values omitted, join phrases, genre fallback, totals, unsupported fields).
- **`MusicBrainzSource`** — a fake `http.Client` answering recorded MusicBrainz JSON (fixtures under
  `test/support/musicbrainz/`): parsing, query escaping, the User-Agent, the one-second spacing with an injected
  clock, the 503 retry, 404 cover → `null`.
- **`AudioMetadataTagWriter`** — real temporary MP3, FLAC and M4A fixtures (new builders beside `flac_fixture.dart`):
  each field written reads back through `readTags`; **the preservation gate** for every enabled format; OGG refused;
  `changedSinceRead` refused.
- **`AutofillController`** — fakes for the source, the writer, access and the scanner: search → review → write →
  rescan; another release; search again; partial failures; Android refusal; cancel; retry.
- **`ScanController.rescanSoon`** — a scan running when it is asked for runs again after.
- **Widgets** — the field dialog (remembered choice, cover unticked, nothing-writable message), the review screen
  (old → new, ticks drive the button's counts, greyed files untickable, finished summary).

## 8. Out of scope

- Identifying files by their sound (AcoustID/Chromaprint). `MetadataSource` leaves room for a second source.
- Artist-wide and library-wide batches.
- Editing a tag by hand, and writing any tag not in §1's list.
- Renaming or moving files to match their tags.
- Fixing `audio_metadata_reader`'s refusal of a non-numeric `TRACKNUMBER` (reported upstream instead).
