# Browse, play and search by genre — design

Status: draft for review · 2026-10-18 · branch `feature/genres` · use case UC-36

Step 1 of 5 in the library work agreed on 2026-10-18: genres (this), editing a whole album's or artist's tags,
selecting several songs, playlists, auto playlists. Each step is its own branch off `develop` and its own pull request.

## 1. Intent

The owner listens by mood as often as by artist. Today a genre is only a line in the statistics; this gives it a place
of its own: a **Genres** tab in the navigation, where every genre in the library is listed, opened, browsed by artist and
by album, and played. Search learns genres too, and gains a selector for what a term is matched against.

The concept, in the owner's words: *an album with different genres on its tracks is an album that has those genres and
should appear under each of them. But when the user chooses to play a specific genre, he only listens to songs from that
genre.*

So there are two rules, and they are deliberately different:

- **Browsing is by record.** A record appears under every genre any of its tracks carries, and opening it from there
  shows the whole record.
- **Playing a genre is by track.** Play or shuffle on a genre queues only the tracks tagged with it.

Success: the owner opens Genres, taps *Rock*, sees the artists and records that have Rock on them, and pressing play on
*Rock* plays Rock and nothing else — including the Rock tracks of a record that is mostly something else.

## 2. Decisions

Taken by the owner during brainstorming:

| Question | Decision |
| --- | --- |
| Where it lives | Its own entry in the navigation (rail and bottom bar), not a fourth view inside Music. |
| A track with several genres (`Rock; Pop`) | It appears under each of them. |
| Inside a genre | The music of that genre, organized by artist and by album. |
| A record only partly in the genre | It is listed under the genre, and opening it shows the **whole** record. |
| Playing a genre | Only the tracks tagged with that genre. |
| `/` in a genre (`Hip-Hop/Rap`) | Part of the name: one genre, never two. |
| Search | A selector chooses what a term is matched against: song name, artist, album, genre, or all of them. |

Calls made in the design (the owner can overturn any of these):

1. **Position:** Genres sits between Music and Queue. Playlists (step 4) will be the fifth entry.
2. **Songs view:** inside a genre the switch offers **Artists**, **Albums** and **Songs**. Songs lists the tracks tagged
   with the genre — the same set that playing the genre queues.
3. **Same spelling, one genre:** genres are matched ignoring case and surrounding spaces, so `rock` and `Rock ` are
   *Rock*. The name shown is the spelling most tracks use; on a tie, the alphabetically first.
4. **Splitting:** every genre value, in every format, is split at `;`, `|` and `,` — **never at `/`** (owner's
   decision: *Hip-Hop/Rap*, *R&B/Soul*, *Singer/Songwriter* are one genre each). Every format, not only those whose
   reader gives one string, because Orpheus itself writes a FLAC file's genres back as one joined value (`Rock; Pop`,
   see `_joined` in `audio_metadata_tag_writer.dart`), and unsplit that file would become one genre called
   *Rock; Pop*. A genre repeated on one track counts once.
   This changes MP3 from today: `audio_metadata_reader` splits `TCON` at `/`, so an MP3's *Hip-Hop/Rap* is currently
   two genres (in the statistics too). Reading `TCON` ourselves (call 12) is what lets the scan stop doing that. Where
   any other format's reader splits at `/` before Orpheus sees the value, the scan must read the raw value instead; the
   builder checks each reader in `audio_metadata_reader` 1.8.0.
5. **No genre:** files without a genre form a *No genre* group, listed last, under the same record rule — a record with
   any untagged track appears there, and playing *No genre* plays only the untagged tracks.
6. **Genre rows only:** the genres list is rows (name, number of tagged tracks, their total length, play, shuffle).
   A genre has no sleeve, so there is no grid at that level. Inside a genre, the rows/grid switch works as in Music and
   is the same remembered setting.
7. **What else plays inside a genre** — what you see is what plays:
   - an **artist** row's play/shuffle queues that artist's records *listed under this genre*, whole, in the order shown
     (not everything the artist ever made);
   - a **record** row plays the whole record, as in Music;
   - a track tapped **inside a record** plays the record from there, as in Music;
   - a track tapped in the genre's **Songs** plays alone, as in Music's Songs;
   - the toolbar's shuffle button, inside a genre, shuffles the genre's tagged tracks.
8. **Unshuffled genre order:** by album artist, then record (the order the Artists view lists them), then track order —
   the same ordering `inArtistOrder` applies.
9. **Its own place:** Genres remembers where the owner was separately from Music. Switching tabs and back returns to
   the same genre, artist or record.
10. **Statistics follow:** *Most played genres* credits a `Rock; Pop` track's plays to both, so the statistics agree with
    the tab. A played track counts as having no genre only when it has none at all.
11. **Search selector** — see §4.5 for the full behavior.
12. **Genres the tag library drops:** `audio_metadata_reader` stops an ID3v2.4 genre frame at its first zero byte, so a
    file holding *Rock*, *Pop* as v2.4 values (the way MusicBrainz Picard writes them) reaches the scan as *Rock* only.
    The scan reads every value of an MP3's `TCON` frame itself, reusing the v2.4-aware reading the tag editor already
    has (`_textValues` in `lib/features/autofill/data/id3_tag_editor.dart`), moved somewhere both can use. It must
    still resolve ID3v1 numeric references (`(17)`, `17` → *Rock*) as the library does today, and still fall back to
    an ID3v1 tag's genre where there is no `TCON`. MP4 files
    with several genre atoms — the library keeps only the last — are left as a known limitation: they are rare, and
    reading MP4 atoms by hand is not worth it in this step.
13. **Loose tracks are not a record:** in Music, an artist's tracks with no album name form one untitled group. Under
    a genre that group is not treated as a record — otherwise one loose Pop single would file every loose track of that
    artist under Pop. Under a genre, an artist's untitled group holds only its tracks tagged with that genre (under
    *No genre*, only its untagged ones); playing it plays those.
14. **A record that leaves the open genre:** if the owner is inside *Rock › Artist › Record* and an edit or re-scan
    takes the last Rock tag off that record, they stay where they are — the record still exists, and moving them out
    straight after their own edit would be jarring. Going back up shows the genre without it. Only a level whose
    content is gone entirely is stepped out of (§4.3).
15. **A genre's share of plays:** once a track counts toward several genres, a genre's percentage on the statistics
    story card is its plays divided by **all plays**, not by the sum of every genre's plays — so "*N*% of what you
    played" stays literally true. Shares can therefore add up to more than 100%; the builder checks the card's wording
    still reads right.

## 3. Goals, non-goals, anti-goals

**Goals:** every genre the tags name is reachable in two taps; a mixed-genre record shows up under each of its genres;
playing a genre never plays a track from another genre; a search can be narrowed to one kind of tag; every existing
screen keeps working as it does.

**Non-goals (this step):** genre artwork or collages; renaming, merging or hiding genres from the tab; genre hierarchies
(*Rock › Prog rock*); search results grouped by artist, record or genre (results stay a list of tracks); editing
tags from the tab (step 2 brings album and artist editing);
playlists and auto playlists (steps 4 and 5).

**Anti-goals — a failure even if it technically works:**

- A Pop track playing when the owner pressed play on Rock.
- A record shown under a genre opening on a fragment of itself.
- A second genre silently dropped, so a `Rock; Pop` record is missing from Pop.
- *Hip-Hop/Rap* turning into *Hip-Hop* and *Rap*.
- A search for *Rock* under *Songs* returning tracks merely because they are tagged Rock.
- Music's browsing, sorting, queues or back gesture behaving differently than before.

## 4. What changes, by layer

### 4.1 Library — keep every genre

Today the catalog keeps only the first genre (`genre: tags.genres.firstOrNull` in
`lib/features/library/data/tag_reading.dart`). This step changes that, and it is the precondition for everything else:

- `TrackMetadata.genre` (`String?`) becomes a list of genres. Empty means none. Every reader in `tag_reading.dart` fills
  it — the list where the reader gives one, the split string where it gives one string (call 4).
- `JsonCatalogStore` writes and reads the list. Its `documentVersion` goes up, so the first launch of the new version
  re-scans once (the store already does this for a version mismatch and logs why). Nothing else about the catalog
  changes.
- `music_stats.dart` credits each genre (call 10); the "no artist, record or genre" check treats an empty list as no
  genre.

The autofill and the tag editor read genres from the file (`FileTags`), not the catalog, so they are unaffected; the
builder should confirm nothing else reads `metadata.genre`.

### 4.2 Grouping — pure functions

Beside `artistsIn` / `albumsIn` in `lib/features/library/domain/music_grouping.dart`, and following its conventions
(absent last, case-insensitive order, album keyed by album *and* album artist):

- every genre in the library, with its tagged tracks;
- the records under a genre — every `(album, albumArtist)` group with at least one track in it, each **whole**;
- the album artists under a genre, and an artist's records under a genre;
- the tracks tagged with a genre, in the order of call 8.

`null` stands for *No genre*, as `null` stands for the untagged artist today. Genre matching (call 3) lives here, so the
tab, the queues and the statistics all use the same rule.

### 4.3 Navigation and browse state

- `ShellDestination` gains `genres` between `music` and `queue`, with an icon, a selected icon and a localized label
  (*Genres* / *Gêneros*). Its doc comment ("Three, and deliberately few") is rewritten to say why there are now four.
- The Genres tab has its own browse state: which genre is open (with an *open* flag, as `inArtist` exists, so *No genre*
  can be opened), which view (Artists, Albums, Songs), which artist and record. Whether this is a second controller or
  a generalized `MusicBrowseController` is the builder's call; the constraint is that the two tabs' places are
  independent (call 9).
- It follows a re-scan the way `MusicBrowseController._follow` does: a record or artist renamed by a re-tag is followed
  through a file it held; a level left empty is stepped out of. A genre that no longer exists returns to the genres list.
- Android back steps out one level in Genres as it does in Music: `app.dart` widens `canGoUp` to the Genres tab's
  levels, and search clearing still comes first.

### 4.4 Presentation

- **Genres list:** rows of genres (call 6), with play and shuffle on each row, and tapping a row opens it.
- **Inside a genre:** the same controls bar as Music — the Artists / Albums / Songs switch, the shuffle button (call 7),
  the layout switch — and the breadcrumb *Genres › Rock › Artist › Record*, each crumb going back to its level. The
  lists reuse `MusicGroupList` and `MusicTrackList`, so rows, sleeves, menus (*Autofill tags…*, *Edit tags…*, play and
  shuffle) behave exactly as in Music.
- Artist rows inside a genre need a play action that queues the genre's records of that artist (call 7) rather than
  `playArtist`; genre rows use `AudioPlaybackController.playAll` with the genre's tracks and a queue named after the
  genre.
- **Empty states:** an empty library shows the Music tab's empty message; a library with no genre tags at all shows
  only *No genre*.
- **Search:** typing a search on the Genres tab shows the same results as on Music (the shell already covers every
  destination but Folders), with the selector of §4.5.
- **Strings** in `app_en.arb` and `app_pt.arb`: the destination label, *No genre*, and any new crumb or queue-name
  strings. Track counts reuse existing plural strings where they fit.

### 4.5 Search selector

Today `matchesIn` in `lib/features/playback/presentation/search_results_view.dart` ranks tracks matched against title,
artist, album artist and album. The owner asked for a selector to search by song name, artist, album, genre, or all.

- **What it is:** a single-choice row — *All*, *Songs*, *Artists*, *Albums*, *Genres* — under the results heading,
  shown whenever search results are shown. *All* is selected by default. On a narrow window it scrolls sideways rather
  than wrapping or being cut. (Choice chips or a segmented button — the builder's call, matching the app's controls.)
- **What each matches** (always case-insensitive, trimmed, start-of-field ranked above within-field, as today):
  - *Songs* — the title;
  - *Artists* — the artist and the album artist;
  - *Albums* — the album;
  - *Genres* — any of the track's genres;
  - *All* — every one of those. Genre is new here and ranks after album, so today's best matches stay on top.
- **Results stay a list of tracks**, ranked and played exactly as today. A track matches a selector only through the
  fields that selector names — under *Songs*, a track tagged *Rock* is not a match for *Rock* unless its title is.
- **Memory:** the choice stays while the app runs — across searches, clearing, and tabs — and is back to *All* at the
  next launch. It is not a saved preference. *(Call made in the design.)*
- **Empty result:** the existing *nothing matches* message; the selector stays, so the owner can widen the search.
- **Strings:** the five selector labels, in English and Portuguese.

The ranking rule can move wherever the builder sees fit (it is a pure function and already tested as one); the selector
state is a small provider beside `searchTermProvider`.

## 5. Product and documentation changes

In the same pull request, as for UC-35:

- **Vision Document** — F-04 *Browsing* gains "and by genre"; F-11's genre ranking notes that a track counts toward
  each of its genres.
- **System Requirements Document** — new `FR-CT-*` requirements: browsable by genre; a record listed under every genre
  of its tracks and opened whole; playing a genre queues only its tracks; a track with several genres under each;
  genres matched ignoring case and spaces; Android back. `FR-ST-09` / `FR-ST-11` updated for several genres. The data
  model row for the catalog says it keeps every genre. Traceability updated.
- **Business Rules** — the two rules of §1 and calls 3–5 belong there if the project records browsing rules as `BR-*`;
  the builder checks how `BR-08`/`BR-09` are written and follows that.
- **Use Case Specification** — new **UC-36: Browse and play by genre**: main flow (open Genres, open a genre, browse by
  artist / album / songs, play), alternative flows for *No genre*, a library with no genres, a genre emptied by a
  re-scan, and back on Android; its traceability row.
- **Search requirements and use case** — `FR-CT-07` widens to "titles, artists, records and genres, together or one
  at a time, as the owner chooses"; `FR-CT-08`'s ranking rule still applies within each choice. The existing search use
  case gains the selector (main flow) and the narrowed search with no results (alternative flow); the builder finds it
  in the Use Case Specification and updates it rather than adding a new one.
- **README** and the **docs site overview** — *Browses by artist, album and song* gains genre; *Searches* names the
  selector; the roadmap gains UC-36.
- **CHANGELOG** — `### Added` under `[Unreleased]` for the tab and the selector; `### Changed` for the one-time
  re-scan and for MP3 genres containing `/` now being one genre.

## 6. Error handling

Nothing new can fail: the tab reads the catalog the Music tab reads, through the same `AsyncStateView` (loading, error
with retry, empty). The one-time re-scan after the catalog version change is the existing path.

## 7. Testing

Following the existing layout of `test/`:

- **Tag reading** — a multi-genre file in each format keeps every genre; values are split at `;`, `|`, `,` and never
  at `/` (*Hip-Hop/Rap* stays one, in MP3 too); an ID3v2.4 `TCON` with zero-byte-separated values keeps all of them;
  ID3v1 numeric references still resolve; repeats collapse.
- **Catalog store** — genres round-trip; a document of the old version is refused and re-scanned.
- **Grouping** — genres listed alphabetically with *No genre* last; case/space variants merged under the majority
  spelling; a mixed record listed under each genre and returned whole; artists and an artist's records under a genre;
  a genre's tracks contain no track of another genre, in call 8's order; *No genre* follows the same rules.
- **Statistics** — a `Rock; Pop` track's plays credited to both; a track with no genres is the "no genre" case; a
  genre's share is of all plays (call 15).
- **Search** — each selector matches only its fields; *All* also matches genre and ranks it after album; today's
  ranking is unchanged under *All* for title/artist/album matches; the selector survives clearing and switching tabs;
  the selector row is shown with results and with the empty result.
- **Browse state** — open/back at each level; independent from Music; following a re-tag; a vanished genre.
- **Widgets** — the navigation shows Genres in rail and bar; the genres list, drill-down, breadcrumb, switch and layout;
  play on a genre queues only its tracks; play on an artist inside a genre queues only that genre's records; Android
  back in Genres.
- The project's verification: `flutter analyze`, `dart format --set-exit-if-changed`, `flutter test`.

## 8. Left to the builder

Names of types, files and providers; whether the browse state is a new controller or a generalized one; the icons; the
exact wording of new strings and documentation; how to split the work into commits.
