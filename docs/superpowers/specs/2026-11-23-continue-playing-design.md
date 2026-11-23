# Keep playing, and a shuffle that follows the browser — design

Two small changes to playback, agreed with the owner on 2026-11-23.

## 1. Keep playing after the queue ends

### Intent

An album or playlist that finishes leaves the app silent. The owner wants
to choose whether music keeps going on its own, and from where.

### What gets built

A preference under **Preferences → Playback**, a dropdown named for what it
answers ("When the queue ends"), with four choices:

| Choice | What plays next |
|--------|-----------------|
| Stop (default, today's behaviour) | Nothing. |
| Same artist | A random track by the artist of the track that just ended. |
| Same genre | A random track sharing a genre with the track that just ended. |
| Whole library | A random track from the whole library. |

Saved through the settings store like the other playback preferences, and
carried in the backup (`backup.dart`, `backup_controller.dart`) alongside
`opensPlayerOnPlay`, so a restore brings it back. A backup without the
field restores as **Stop**.

### Approaches considered

- **A. One track at a time — chosen.** When the queue runs out, one random
  track is appended and opened; the next time it runs out, another. Previous
  still walks back through the album, the Queue view keeps the history, and
  "same artist / genre" follows whatever is playing now.
- B. Append the whole pool shuffled. Shows what is coming, but appends
  thousands of rows for "whole library" and is fixed to the artist or genre
  of the moment the album ended.
- C. Replace the queue with a new shuffled one. Simplest, but the album just
  heard disappears and Previous cannot reach it.

### Behaviour

- **When it applies.** Only with repeat **off**. Repeat all and repeat one
  keep their meaning and win over the preference.
- **The seed** is the track at the end of the queue when it ran out (the
  current track; when the last one would not play, the last track that did).
- **Same artist** matches a candidate whose artist *or* album artist equals
  the seed's artist (falling back to the seed's album artist when it has no
  artist), compared the way the library groups names. The performer first,
  so a compilation continues with that performer rather than with
  "Various Artists".
- **Same genre** matches a candidate sharing any of the seed's genres
  (`genreKey`).
- **Fallbacks.** A seed with no artist tag (for Same artist) or no genre (for
  Same genre) continues from the whole library rather than stopping.
- **No immediate repeats.** Candidates already in the queue are left out.
  When that leaves none (a small artist fully heard), the queue's tracks are
  allowed again, except the seed itself; only when even that leaves nothing
  does playback stop, as today.
- **Missing files.** A candidate the probe says is gone is stepped over and
  another is drawn, a bounded number of times, then playback stops.
- **Randomness** comes from `shuffleRandomProvider`, so tests seed it.
- **Next.** Pressing next on the last track with the preference on draws a
  track the same way. The next button on the bar, the player and the media
  session (`hasNext`) is enabled in that case too.
- **The queue's kind and label are left as they were** (the album's name
  stays the Queue view's title); the appended tracks show as ordinary rows.
  *Builder's call, flagged for the owner.*

## 2. The toolbar shuffle follows where the browser is

### Intent

Under Music, the toolbar shuffle always plays the whole library, even inside
an artist or an album. The owner wants it to shuffle what they are looking
at.

### What gets built

The `onShuffle` and `shuffleTooltip` of `MusicBrowser` are derived from the
`MusicBrowseState` the browser shows:

| Where | The button |
|-------|------------|
| Artists, Albums or Songs, nothing opened | Shuffle everything (as today) |
| An artist opened (its albums) | Shuffle the artist |
| An album opened, directly or through an artist | Shuffle the album |

Under **Genres** the same rule, one level down: the genre's own level
shuffles the genre (as today); an artist or album opened inside it shuffles
that artist's or album's tracks *within the genre*, as the row buttons there
already do (`within`).

The existing strings are reused (`audioShuffleAll`, `audioShuffleArtist`,
`audioShuffleAlbum`, `genreShuffle`). The shuffled queue is gathered the way
`playArtist` / `playAlbum` gather it, including the untagged artist and
untitled album groups.

Playlists need nothing: an open playlist's own Shuffle already plays only it.

The code comment on `playEverythingShuffled` that argues for "everything
wherever you stand" is rewritten to match.

## Non-goals

- No shuffle toggle for a queue already playing.
- No "smart" picks (similar artists, play counts, energy).
- No new shuffle on the playlists list.

## Delivery

One branch (`feature/continue-playing`), one pull request into `develop`,
tests first for each behaviour above, CHANGELOG entries under
`[Unreleased]`, English and Portuguese strings for the new preference.
Tests run through `ci-check linux`, since orpheus' tests need GTK.
