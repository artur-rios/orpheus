# The data export file

*Preferences → Your data → Export my data…* saves everything Orpheus knows about your music to one JSON file, in a place
you choose. This page describes that file, field by field, so that it can be read without reading Orpheus's code.

It is meant for three things:

- **A backup.** The file holds the library, the playlists, the two auto playlists and the play history.
- **Analysis in any tool.** It is plain UTF-8 JSON: open it in a text editor, `jq`, Python, or a spreadsheet's JSON
  import.
- **Moving to another program.** Every song carries its path and its tags, so another tool can match them to its own.

**Restoring from the file is not part of this version.** Orpheus does not read the file back in yet; that comes in a
later version, and the layout below was chosen so that it can. Exporting changes nothing: it reads what Orpheus holds
and writes only the file you chose. Not included: cover images, the audio itself, and your preferences.

## The file

- UTF-8 text, indented by two spaces, ending in a newline. It is named `orpheus-data-<yyyy-MM-dd>.json` unless you
  change it in the save dialog.
- The keys of every object are always in the order given here.
- Times are ISO-8601 strings in UTC with a `Z`, such as `2026-10-18T22:30:00.000Z`. The fractional seconds have 3
  digits, or 6 when the time carries microseconds (`2026-10-18T22:30:00.123456Z`): parse them with an ISO-8601
  parser, not a fixed pattern.
- Durations are whole milliseconds, as integers.
- A value Orpheus does not have is `null`; the key is **never left out**. The one exception is stated where it
  applies: `fallback` on the *All-time favourites* auto playlist.
- Counts and years are integers. A section with nothing in it is an empty array (`[]`), not a missing key.

## Top-level keys

The document is one object with these keys, in this order. This list is read by a test in the repository, which fails
when it and the file Orpheus writes disagree.

```text
format
formatVersion
exportedAt
orpheusVersion
songs
artists
albums
playlists
autoPlaylists
playHistory
statistics
problems
```

| Key | Type | Nullable | Meaning |
| --- | --- | --- | --- |
| `format` | string | no | Always `"orpheus-data"`. Check it before anything else, to know the file is one of these. |
| `formatVersion` | integer | no | The version of this layout, currently `1`. See [Versioning](#versioning). |
| `exportedAt` | string (time) | no | When the export was made. |
| `orpheusVersion` | string | yes | The version of Orpheus that wrote the file, such as `"1.5.0"`; `null` when it is not known. |
| `songs` | array of [song](#songs) | no | Every song in the library. |
| `artists` | array of [artist](#artists) | no | The library grouped by artist, as the Artists list shows it. |
| `albums` | array of [album](#albums) | no | The library grouped by album, as the Albums list shows it. |
| `playlists` | array of [playlist](#playlists) | no | Your playlists. |
| `autoPlaylists` | array of [auto playlist](#auto-playlists) | no | *Favourites lately* and *All-time favourites*. |
| `playHistory` | array of [played track](#play-history) | no | Every song you have played, with its plays. |
| `statistics` | [object](#statistics) | no | The numbers the statistics screen shows. |
| `problems` | array of [problem](#problems) | no | Sources that could not be read; empty normally. |

## References

Songs are referred to by `id`, which exists **only inside the file**.

- A song's `id` is `s1`, `s2`, `s3`… in the order the songs are listed. The same song can have a different `id` in
  another export, if songs were added, removed or re-tagged in between. Never keep an `id`.
- `artists[].songs`, `albums[].songs`, `autoPlaylists[].songs`, `playlists[].entries[].songId` and
  `playHistory[].songId` all point at `songs[].id` in the same file. A `songId` of `null` means the song is not in the
  library: its file has gone, or its folder is not registered any more.
- A song is identified **across files and across machines by its path, and then by its tags** (title, artist, album,
  track number, length). Every entry that can refer to a song that is not in the library carries its own `path`, and a
  playlist entry also keeps the title, artist, album and length it was saved with, so it can still be matched.
- Paths are written as the machine stored them, with its separators: `/library/a.flac` on Linux and Android,
  `C:\Music\a.flac` on Windows. In JSON text the backslashes are doubled.

## Sections

### Songs

One object per song in the library, in the library's own song order (by title, songs with no title last). Exactly the
tags Orpheus keeps; there is no disc total, because the library does not hold one.

| Field | Type | Nullable | Meaning |
| --- | --- | --- | --- |
| `id` | string | no | `s1`, `s2`… in the order listed; a reference used only inside this file. |
| `path` | string | no | The file's absolute path on the machine that made the export. |
| `title` | string | yes | The title tag. |
| `artist` | string | yes | The artist (performer) tag. |
| `albumArtist` | string | yes | The album artist tag as the file carries it, trimmed. It is not filled in from anything else; `albums[].albumArtist` is. |
| `album` | string | yes | The album tag. |
| `trackNumber` | integer | yes | The track number. |
| `trackTotal` | integer | yes | How many tracks the album has, when the file says. |
| `discNumber` | integer | yes | The disc number. |
| `year` | integer | yes | The year. |
| `genres` | array of string | no | Every genre the file holds; `[]` when it has none. |
| `durationMs` | integer | yes | The length in milliseconds; `null` when it could not be read. |

### Artists

One object per artist, alphabetically, with the songs that have no artist last.
Songs are grouped by their album artist, as the Artists list does: the file's own album artist tag, else what the rest
of its album says, else the song's artist.

| Field | Type | Nullable | Meaning |
| --- | --- | --- | --- |
| `name` | string | yes | The artist; `null` for the group of songs with no artist. |
| `songs` | array of string | no | `songs[].id` of the artist's songs, album by album, in the order the Albums list shows the albums, each album in track order. |

### Albums

One object per album, alphabetically, with the songs that have no album last. An album is its title *and* its album
artist, so two artists' records of the same name are two albums.

| Field | Type | Nullable | Meaning |
| --- | --- | --- | --- |
| `title` | string | yes | The album; `null` for the group of songs with no album. |
| `albumArtist` | string | yes | The album's artist, worked out as for the artists above: the file's album artist tag, else what the rest of the album says, else the song's artist; `null` when none is set. |
| `year` | integer | yes | The year, when every song on the album agrees on it; otherwise `null`. |
| `songs` | array of string | no | `songs[].id` of the album's songs, in track order. |

### Playlists

Your playlists, in the order Orpheus keeps them. The auto playlists are not here; see below.

| Field | Type | Nullable | Meaning |
| --- | --- | --- | --- |
| `id` | string | no | The playlist's own identifier inside Orpheus's data. Unlike a song's `id`, it is not renumbered per export. |
| `name` | string | no | The name. |
| `createdAt` | string (time) | no | When it was made. |
| `modifiedAt` | string (time) | no | When it was last changed. |
| `hasCustomCover` | boolean | no | Whether you gave it a cover picture. The picture is not in the file. |
| `entries` | array of entry | no | The songs, in the playlist's order. |

An **entry** is a song as the playlist saved it:

| Field | Type | Nullable | Meaning |
| --- | --- | --- | --- |
| `path` | string | no | The song's path. |
| `songId` | string | yes | `songs[].id` of the song, or `null` when the library no longer holds it. |
| `title` | string | yes | The title saved when the song was added, or last saved while the library had it. |
| `artist` | string | yes | The artist saved with it. |
| `album` | string | yes | The album saved with it. |
| `durationMs` | integer | yes | The length saved with it. |

### Auto playlists

Always two objects, in this order, **whatever the *Show auto playlists* preference says**: the preference hides them on
screen, it does not change what your data is. They are the lists as they are at the moment of the export.

| Field | Type | Nullable | Meaning |
| --- | --- | --- | --- |
| `kind` | string | no | `"lately"` or `"allTime"`. Use this, not the name, to tell them apart. |
| `name` | string | no | `"Favourites lately"` or `"All-time favourites"`, always in English, whatever language Orpheus is set to. |
| `fallback` | boolean | no | **Only on `lately`.** `true` when too little of your listening has been dated to rank the last 30 days by its own plays, and the list is the songs played in that time ranked by their plays in all. |
| `songs` | array of string | no | `songs[].id`, in the list's order, up to 50. Songs the library does not hold are left out. |

`lately` is what you played most in the last 30 days before `exportedAt`; `allTime` is what you played most ever. The
`allTime` object has no `fallback` key.

### Play history

One object for every song you have played, **including songs no longer in the library**. No order is promised.

| Field | Type | Nullable | Meaning |
| --- | --- | --- | --- |
| `path` | string | no | The song's path. |
| `songId` | string | yes | `songs[].id`, or `null` when the library does not hold the song. |
| `plays` | integer | no | How many times it has counted as played, in all. |
| `lastPlayedAt` | string (time) | no | When it last counted. |
| `recentPlays` | array of string (time) | no | When it counted over the last 90 days, oldest first. Orpheus keeps no older dates, so for a song played long ago, or played before dates were kept, this is shorter than `plays`, or `[]`. |

### Statistics

What the statistics screen shows, worked out from the play history against the library at the moment of the export.

| Field | Type | Nullable | Meaning |
| --- | --- | --- | --- |
| `totalPlays` | integer | no | Every play counted. |
| `distinctTracks` | integer | no | How many different files they came from. |
| `untaggedTracks` | integer | no | How many played files the library holds that carry no artist, album or genre tag; a played file the library no longer holds is not counted. |
| `topTracks` | array of ranked line | no | The ten most played tracks, most first. A track with no title, or no longer in the library, is named by its file name. |
| `topArtists` | array of ranked line | no | The ten most played artists. |
| `topAlbums` | array of ranked line | no | The ten most played albums. |
| `topGenres` | array of ranked line | no | The ten most played genres. A song counts toward each of its genres. |

A **ranked line** is `{ "name", "plays", "share" }`:

| Field | Type | Nullable | Meaning |
| --- | --- | --- | --- |
| `name` | string | no | The track, artist, album or genre. |
| `plays` | integer | no | Its plays. |
| `share` | number | yes | Its fraction of the plays that ranking is measured against, from `0` to `1`: all plays for tracks and genres, and for artists and albums the plays of the songs that carry that tag. Genre shares can add up to more than `1`, because a song counts toward each of its genres. A reader should expect `null`, though Orpheus currently always writes a number. |

Lines with equal plays are ordered by name. These lines carry no `songId`: this section is the screen's summary, and the
per-song numbers are in `playHistory`.

### Problems

Empty normally. If a source could not be read **at all**, its section is left empty and a problem says so, rather than
the export pretending there is nothing there: a partial file you know about is better than none.

| Field | Type | Nullable | Meaning |
| --- | --- | --- | --- |
| `section` | string | no | The section that is empty because of it: `"songs"`, `"playlists"` or `"playHistory"`. |
| `message` | string | no | What went wrong, in English, for a person to read. |

The `playlists` source is a problem when the playlists could not be read; `playHistory` when the play history could not
be read in this run. When the play history is unreadable, `autoPlaylists` and `statistics` come out empty too, because
they are worked out from it. `songs` is a problem when the library is being rebuilt: after an upgrade Orpheus refuses
the catalog an older version wrote and scans again, and until that scan has refilled it the library is empty. A
playlists or history file that was set aside as unreadable and replaced by an empty one is not a problem: Orpheus kept
it aside, as a `.bad-` file next to its data. If the library fails to load, there is nothing worth saving, so no file is
written at all.

A `catalog.json` that cannot be read at all reads as an empty library (a rescan rebuilds it), and the export cannot tell
that apart from a library with no music. So an export with no songs and no problem means Orpheus found no music.

When `problems` is not empty, Orpheus tells you so after the export: *Exported, but some data could not be read*.

## Versioning

`formatVersion` is an integer, `1` today.

- **A change that keeps old readers working does not change the number.** Adding a key to an object, adding a value to
  a list or a new top-level section is not a new version, so a reader must **ignore keys it does not know**.
- **A change that could break a reader does.** Removing or renaming a key, changing a key's type or meaning, changing
  how a reference works, or making a nullable value non-null or the other way round, raises `formatVersion`.
- A reader should refuse a `formatVersion` higher than the one it was written for, and say so, rather than guess.
- Keys keep their order within a version.

## Example

A small export, cut down to one of each thing: a song that is in the library and a played song that is not, one
playlist, and short rankings.

```json
{
  "format": "orpheus-data",
  "formatVersion": 1,
  "exportedAt": "2026-10-18T22:30:00.000Z",
  "orpheusVersion": "1.5.0",
  "songs": [
    {
      "id": "s1",
      "path": "/library/ann/first/01-alpha.flac",
      "title": "Alpha",
      "artist": "Ann",
      "albumArtist": null,
      "album": "First",
      "trackNumber": 1,
      "trackTotal": 10,
      "discNumber": null,
      "year": 2001,
      "genres": [
        "Rock"
      ],
      "durationMs": 185000
    }
  ],
  "artists": [
    {
      "name": "Ann",
      "songs": [
        "s1"
      ]
    }
  ],
  "albums": [
    {
      "title": "First",
      "albumArtist": "Ann",
      "year": 2001,
      "songs": [
        "s1"
      ]
    }
  ],
  "playlists": [
    {
      "id": "p1",
      "name": "Road trip",
      "createdAt": "2026-01-02T03:04:05.000Z",
      "modifiedAt": "2026-02-03T04:05:06.007Z",
      "hasCustomCover": false,
      "entries": [
        {
          "path": "/library/ann/first/01-alpha.flac",
          "songId": "s1",
          "title": "Alpha",
          "artist": "Ann",
          "album": "First",
          "durationMs": 185000
        },
        {
          "path": "/old/gone.mp3",
          "songId": null,
          "title": "Gone",
          "artist": "Nobody",
          "album": null,
          "durationMs": null
        }
      ]
    }
  ],
  "autoPlaylists": [
    {
      "kind": "lately",
      "name": "Favourites lately",
      "fallback": true,
      "songs": [
        "s1"
      ]
    },
    {
      "kind": "allTime",
      "name": "All-time favourites",
      "songs": [
        "s1"
      ]
    }
  ],
  "playHistory": [
    {
      "path": "/library/ann/first/01-alpha.flac",
      "songId": "s1",
      "plays": 4,
      "lastPlayedAt": "2026-10-10T12:00:00.000Z",
      "recentPlays": [
        "2026-10-01T10:00:00.000Z",
        "2026-10-10T12:00:00.000Z"
      ]
    },
    {
      "path": "/old/gone.mp3",
      "songId": null,
      "plays": 6,
      "lastPlayedAt": "2026-09-30T09:00:00.000Z",
      "recentPlays": [
        "2026-09-30T09:00:00.000Z"
      ]
    }
  ],
  "statistics": {
    "totalPlays": 10,
    "distinctTracks": 2,
    "untaggedTracks": 0,
    "topTracks": [
      {
        "name": "gone.mp3",
        "plays": 6,
        "share": 0.6
      },
      {
        "name": "Alpha",
        "plays": 4,
        "share": 0.4
      }
    ],
    "topArtists": [
      {
        "name": "Ann",
        "plays": 4,
        "share": 1.0
      }
    ],
    "topAlbums": [
      {
        "name": "First",
        "plays": 4,
        "share": 1.0
      }
    ],
    "topGenres": [
      {
        "name": "Rock",
        "plays": 4,
        "share": 0.4
      }
    ]
  },
  "problems": []
}
```

The example is read by the same test as the key list, which checks that it is valid JSON with the keys above, in order.
With an unreadable play history the same file would have `"playHistory": []` and, in `problems`:

```text
{ "section": "playHistory", "message": "The play history could not be read, so no plays are listed" }
```
