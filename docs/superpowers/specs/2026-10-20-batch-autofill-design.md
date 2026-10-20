# Autofill the tags of many songs at once — design

Status: draft for review · 2026-10-20 · use case UC-44 · builds on UC-34 (autofill a record) and UC-38 (selection)

## 1. Intent

The owner fixes the tags of a large part of the library — an artist, a genre, a playlist, a selection, or everything —
in one go, from MusicBrainz, choosing which tags to fill (all of them, one, or several), without reviewing hundreds of
records one by one.

Today autofill (UC-34) works on one record or one lone track, and every change is reviewed. That stays. This feature
adds a **batch**: Orpheus splits the songs into records, looks each one up, **writes the confident matches without
asking**, and keeps the **doubtful** ones for the owner to review in the existing review screen.

Success: the owner starts an autofill on the whole library, leaves it running, and comes back to *240 albums updated,
45 need you, 15 not found or not writable* — every confident record correctly tagged, every doubtful one a tap away
from the review they already know, and nothing written to a song the owner did not include or for a tag they did not
choose.

Decisions taken with the owner:

| Question | Decision |
| --- | --- |
| What can be autofilled | Any set of songs: a selection, an artist, an album, a genre, a playlist, or the whole library. |
| Which tags | All, one, or several — the existing field dialog and its remembered choice. |
| Confirmation | Confident matches are written without a per-change review; only doubtful ones are shown to the owner. |
| Existing values | A chosen tag **replaces** what is there, as in UC-34 — also on the confident matches written unreviewed. |

## 2. Goals, non-goals, anti-goals

- **Goals:** the decisions above; the same MusicBrainz source, throttle, matching, writer, safeguards and rescan as
  UC-34; a batch the owner can leave running and stop at any time, keeping what was written.
- **Non-goals:** identifying files by their sound (AcoustID); resuming a batch after Orpheus is closed or killed;
  undo; a "fill only empty tags" mode; writing formats other than MP3 and FLAC; a foreground service on Android.
- **Anti-goals** (a failure even if it works):
  - a doubtful match written unreviewed — when in doubt, it is doubtful;
  - a song outside the batch, or a tag the owner did not choose, changed;
  - one record's failure stopping or undoing the others;
  - the owner unable to tell, at the end, which records were written, which need them, and which were skipped and why;
  - the single-record and single-track autofills (UC-34) changing behaviour;
  - more than one MusicBrainz request a second, however many autofills run.

## 3. Product and documentation changes

All in the same pull request. The batch reverses the promise that every written change was confirmed one by one, so
the documents say what confirmation now means: **starting a batch and choosing its tags, after being told that
confident matches will be written without review, confirms those matches.**

- **Vision Document**
  - **C-03**: "…and only for changes the owner has confirmed" becomes "…and only for changes the owner has confirmed —
    one by one, or, for a batch autofill, by starting it after being told its confident matches are written without
    review (`FR-AF-09`)".
  - **F-25 Autofill many songs at once** — new feature row (the next free number; the builder checks).
  - §1.2 Scope and §6 Out of scope: autofill is no longer "a record at a time".
- **System Requirements Document** — new rows in the `FR-AF` section:
  - **FR-AF-09** The owner must be able to start an autofill on a selection of songs, an artist, a genre, a playlist
    or the whole library, choosing the tags as in `FR-AF-01`. Before anything is looked up, Orpheus must say how many
    songs and records it covers, roughly how long it will take, that confident matches are written without review and
    replace existing values, and must be told to start.
  - **FR-AF-10** The songs must be split into records and lone tracks as §4.1 says, and each looked up as in
    `FR-AF-02`/`FR-AF-03`. A record or lone track must be written without review only when its match is confident
    (§4.3); every other one must be kept for the owner to review as in `FR-AF-04`.
  - **FR-AF-11** The batch must show its progress, keep running while the owner uses the rest of Orpheus, and stop
    when asked after the record being written, keeping what was written. At the end it must say how many records were
    updated, how many need the owner, and which were not found, not writable or failed, and why.
  - **NFR-03** gains `FR-AF-09` beside `FR-AF-05`. Traceability: `F-25 → FR-AF-09 … FR-AF-11`.
- **Use Case Specification** — **UC-44: Autofill many songs at once** (main flow, the alternative flows of §6), and
  its traceability row.
- **README** and **docs site overview** — the autofill bullet gains the batch, and *It changes your files only when
  you ask* says that a batch writes its confident matches once you start it.
- **CHANGELOG** — `### Added` under `[Unreleased]`.

No permission, manifest or CI change (the batch uses the access UC-34 already asks for).

## 4. Behaviour

### 4.1 Splitting the songs into records

- Songs are grouped by **album artist (else artist) and album**, both normalised as `normalised()` does. Each group
  is a **record**, looked up as UC-34 looks up a record.
- Songs with a blank album are grouped **by folder**, as the library's untitled-album group and `releaseQueryFor`'s
  folder fallback already treat them: a folder of two or more such songs is a record searched by the folder's name; a
  folder holding just one is a **lone track**, looked up as UC-34 looks up a lone track. *(My call.)*
- Songs Orpheus cannot write (`canWriteTagsTo` false) are counted as *not writable* and never looked up. A record none
  of whose songs is writable is not looked up.
- **A record only partly in the batch** (three songs of an album picked in a selection, or a genre holding half of
  it): the search and the ranking use **every song of that album in the library**, so that `rankCandidates`' first
  key — as many tracks as files — prefers the real album and not a three-track single; tracks are assigned over those
  same songs; but **changes are proposed and written only for the songs in the batch**.
- Records are looked up in library order (artist, then album), lone tracks after them.

### 4.2 The run

- One record at a time: search → fetch the best release (and the release-group genres and the cover where chosen, as
  `AutofillController._propose` does) → assign tracks → propose changes → decide confident or doubtful.
- A **confident** record with changes is written at once, through the same writer, the same `expected`
  (changed-since-read) check and the playing-file-last order within the record. A confident record with no changes
  is *already right*.
- A **doubtful** record is kept with what was found (candidates, the release, the proposals), nothing written.
- A record whose search answers nothing is *not found*; one whose lookup fails `unreachable` or `rateLimited` is
  retried once after the record that follows, then reported as *could not be looked up*; `malformed` is *failed*. Three records in a row unreachable pause
  the batch with *MusicBrainz could not be reached* and *Try again* / *Stop* (so a lost connection does not burn
  through the library as failures).
- Android write access (`ensureWritable`) is asked for **once, when the owner starts the batch**, before any lookup;
  a refusal starts nothing.
- A rescan (`ScanController.rescanSoon`) is asked for **at most once a minute while files are being written, and once
  at the end or on stop** (my call: one per record would rescan the whole library hundreds of times).

### 4.3 What counts as confident

Conservative on purpose: a false "doubtful" costs the owner a review, a false "confident" writes wrong tags
unreviewed.

A **record** is confident only when all of these hold for the best-ranked release:

1. its `status` is official;
2. its title, normalised, **equals** the record's album (the query's album — the folder name where the songs have
   none counts too);
3. its artist credit, normalised, **equals** the record's album artist; a record with no album artist and no artist
   is never confident;
4. **every song of the batch in that record** is assigned a track, and for each, the track's title normalised
   **equals** the song's title (a song with no title is never confident), and where the song has a track number (and
   a disc number) it equals the track's;
5. **for a record only partly in the batch**, no proposed change touches album or album artist — the library groups
   albums by the exact pair of strings, so writing them to three songs of twelve would split the album in two
   unreviewed. Such a record is doubtful with the reason *would split the album*. *(My call.)*

Songs that do not decide confidence: a song that cannot hold one of the chosen fields (`notWritable`) is written for
the rest, as UC-34 does; a song blocked as a whole (`blockedBecause` `unwritableFormat` or `unsafeTags` — an MP3 or
FLAC whose tags Orpheus cannot change safely) is counted as *not writable*, and the rest of its record is judged and
written without it. `noMatch` is rule 4. *(My call.)*

A **lone track** is confident only when the best recording's title and artist credit, normalised, equal the song's,
its length is within 3 seconds of the song's (unknown length → doubtful), and the release it is filed under is
official, of primary type album, and not a compilation — the album-dependent fields (album, album artist, numbers,
year, cover) come from it.

These rules live in a pure, exhaustively tested domain function (`confidenceOf(...)` beside `matching.dart`), so that
they can be tightened without touching the run.

### 4.4 The owner's view

- **Start** — the field dialog of UC-34 (same remembered choice, cover unticked until chosen), then a confirmation
  that says, for example: *Autofill 3,412 songs in 288 records? About 25 minutes. Records that match MusicBrainz
  clearly are written without asking, replacing their current tags; the others are kept for you to check.* —
  *Start* / *Cancel*. Songs not writable are counted in it (*124 songs can't be changed and will be skipped*). The
  estimate is ~2.5 s per record (plus 1 s each with cover), a lone track the same.
- **Batch screen** (a full-screen route):
  - progress: *Looking up 37 of 288 records*, a bar, and live counts — *updated*, *need you*, *already right*, *not
    found*, *skipped*;
  - *Stop* while running; *Close* leaves it running;
  - when done (or stopped): the summary, then **Need you** — one row per doubtful record (album, artist, the release
    proposed, if any, and why it is doubtful in a few words: *different title*, *3 songs unmatched*, *not an official
    release*, *no match*) — then the lists of not found, not writable and failed, each named with its reason.
  - Tapping a doubtful record opens the **existing review screen (UC-34)** for that record's songs in the batch, with
    the batch's field choice; when it finishes with files written, the row is marked done. For a partial record the
    review must rank and assign against the **album's library songs** as §4.1 does, so that looking it up again does
    not prefer the very single the batch avoided: `AutofillController.start` (and `AutofillScreen`) gain an optional
    `matchAgainst` list of entries used for the query, `rankCandidates`' file count and `assignTracks`, while
    proposals stay limited to the songs passed; omitted, UC-34 behaves exactly as today. Whether the review reuses
    what the batch already fetched or looks the record up again is the builder's call. *(My call.)*
- **While it runs elsewhere** — a small indicator in the shell (beside the player bar or in the navigation rail; the
  builder picks, following the layout's breakpoints) shows *Autofilling 37/288* and reopens the batch screen.
- **After it finishes** — the indicator stays until the owner has seen the summary once, and after that, as *45 need
  you*, for as long as unreviewed doubtful records remain; it reopens the summary. The summary's *Try again* rewrites
  the files that were in use or failed, as UC-34's does. The summary has *Clear list*, which asks
  first and then forgets the doubtful records (nothing is written); the indicator goes when nothing is left to review
  or the list is cleared. Kept in memory only: closing Orpheus forgets it (non-goal: resuming). *(My call.)*
- **One batch at a time.** Starting another while one runs opens the running one instead. Starting one while a
  finished batch still has doubtful records asks *Start a new autofill? The 45 records waiting for you will be
  forgotten.* — the new batch replaces it only on yes. A single-record autofill can still be started; it shares the
  one throttle and so simply waits its turn. *(My call.)*

### 4.5 Entry points

*Autofill tags…* (the existing string and `Icons.auto_fix_high_outlined`) on:

| Where | Songs | Flow |
| --- | --- | --- |
| An album's menu | that album | **unchanged: UC-34**, every change reviewed (it is one record already) |
| A song's menu | that song | unchanged: UC-34 lone track |
| An artist's menu (new item) | every song of the artist in the library | batch |
| A genre row (new ⋮ menu, right-click and long press, like album rows) | every song tagged with the genre | batch |
| A playlist's menu, own and auto (new item) | the playlist's songs the library still has | batch |
| The selection bar (new action) | the selected songs | one song → UC-34 lone track; several → batch |
| The Music tab's controls bar (new ⋮ beside shuffle) | the whole library; inside an open genre, the genre's songs, as shuffle there means | batch |

The album row stays on UC-34 because the owner already reviews a single record there; giving it the unreviewed batch
would change UC-34's behaviour (an anti-goal). *My call — the owner can ask for it the other way.*

## 5. Architecture

Inside `lib/features/autofill/`, beside what exists; nothing outward constructed outside `core/di/providers.dart`.

- **Domain** (pure):
  - `BatchPlan` / `planBatch(batchEntries, libraryEntries)` — the records and lone tracks of §4.1, each with its
    batch songs and its library songs.
  - `Confidence` / `confidenceOf(...)` — §4.3, answering confident, or doubtful with the reason shown in §4.4.
  - `RecordOutcome` — `updated`, `alreadyRight`, `doubtful(reason)`, `notFound`, `unreachable`, `notWritable`,
    `failed(per-file WriteOutcomes)`.
- **Application:** `BatchAutofillController` — a **kept-alive** notifier (not auto-disposed: the batch outlives its
  screen), one at a time. State: stage (`confirming → running → paused → finished/stopped`), the plan, the index,
  per-record outcomes, the doubtful records with what was found, counts. Actions: `start(entries, fields)`, `stop()`,
  `resume()`, `retryFailed()`, `markReviewed(record)`, `markSeen()`, `clear()` (forgets a finished batch and its
  doubtful records). It reuses the domain functions UC-34's controller uses
  (`releaseQueryFor`, `rankCandidates`, `assignTracks`, `proposalsFor`, `rankAppearances`, `recordingQueryFor`) rather
  than driving `AutofillController`; shared lookup steps may be extracted from `AutofillController` into a helper both
  use, without changing UC-34's behaviour (its tests must pass unchanged).
- **Presentation:** the confirmation dialog, `BatchAutofillScreen`, the shell indicator, `startBatchAutofill(context,
  ref, entries)` beside `startAutofill`, the new menu items of §4.5. All strings in both catalogs (en, pt, with
  Portuguese plurals); colours from the theme only.

## 6. Errors and edge cases

| Case | Behaviour |
| --- | --- |
| Nothing in the batch writable | The field dialog says so, as UC-34's; nothing is looked up. |
| A song changed since the batch read it | Skipped and named (`changedSinceRead`), the rest of its record written. |
| The playing song on Windows | Written last in its record; if refused, *in use*, retryable from the summary. |
| Network lost mid-batch | Three unreachable records in a row pause it (§4.2); *Try again* resumes from that record. |
| The owner stops | Stops after the record being written; written stays written; a rescan is asked for; the summary shows what was not reached as *not looked up*. |
| A scan runs during the batch | The batch keeps the entries it started with; the `expected` check refuses any file the scan saw change. |
| Orpheus closed or killed (Android) | What was written stays written; the batch is not resumed (non-goal). |
| An album split across differently spelt album names | Two records, each looked up on its own; whichever is not exact is doubtful. |
| Library of thousands of records | One request a second holds; the screen stays responsive (no work on the UI isolate beyond state updates). |

## 7. Testing

Given-When-Then, mirroring `lib/`, with the fakes UC-34 already has (`test/support/fake_autofill.dart`).

- **`planBatch`** — grouping by album artist/artist and album, normalised; blank album → by folder, one-song folders
  as lone tracks; partial records carry their library songs; unwritable songs counted out.
- **`confidenceOf`** — each rule of §4.3 on its own making a record doubtful, and all together confident; a partial
  record changing album or album artist doubtful; lone-track rules; songs without titles; `notWritable` fields and
  whole-file blocks not deciding it.
- **`AutofillController` with `matchAgainst`** — ranks and assigns over the album's songs, proposes only for the songs
  passed.
- **`BatchAutofillController`** — confident records written and doubtful ones not; a partial record written only for
  its batch songs; stop after the current record; three unreachable → paused, resume; access refused → nothing
  looked up; rescan throttled and asked for at the end; one batch at a time.
- **Widgets** — the confirmation's counts and estimate; the batch screen's progress, counts and summary lists; a
  doubtful row opening the review screen; the indicator staying while doubtful records remain and going on *Clear
  list*; a new batch over a finished one asking first; the new menu items on artist, genre, playlist, selection bar and controls
  bar; album and song menus unchanged.
- UC-34's existing tests pass unchanged.
