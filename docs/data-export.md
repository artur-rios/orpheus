# The data export file

*Preferences → Your data → Export my data (JSON)…* saves everything Orpheus knows about your music to one JSON file,
in a place you choose. This page describes that file, field by field, so that it can be read without reading Orpheus's
code. It also describes the [backup file](#backup-file) that *Back up Orpheus (ZIP)…* saves, which holds this
document, the playlists' cover pictures and your preferences, and how a [restore](#restoring) reads either.

It is meant for three things:

- **Analysis in any tool.** It is plain UTF-8 JSON: open it in a text editor, `jq`, Python, or a spreadsheet's JSON
  import.
- **Moving to another program.** Every song carries its path and its tags, so another tool can match them to its own.
- **A backup of the data.** The file holds the library, the playlists, the two auto playlists and the play history, and
  *Restore from a backup…* reads it back. For restoring Orpheus on this or another device, the ZIP is the better
  choice: it also holds the cover pictures and the preferences, which this file does not.

Exporting changes nothing: it reads what Orpheus holds and writes only the file you chose. Not included: cover images,
the audio itself, and your preferences.

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
the catalog an older version wrote, and a catalog that cannot be read at all is refused the same way, and it scans
again; until that scan has refilled it the library is empty. A
playlists or history file that was set aside as unreadable and replaced by an empty one is not a problem: Orpheus kept
it aside, as a `.bad-` file next to its data. If the library fails to load, there is nothing worth saving, so no file is
written at all.

A `catalog.json` that cannot be read at all is treated like one another version wrote: the library is reported as being
rebuilt (`songs` in `problems`) and a scan refills it. Only a missing `catalog.json`, a library never scanned, reads as
an empty library, so an export with no songs and no problem means Orpheus found no music.

When `problems` is not empty, Orpheus tells you so after the export: *Exported, but some data could not be read*.

## Backup file

*Preferences → Your data → Back up Orpheus (ZIP)…* saves a ZIP that holds the document above, the playlists' cover
pictures and your preferences. It is for restoring Orpheus on this or another device; the JSON export is for reading
your data in other tools. *About these exports*, under the two entries, shows the same comparison:

| | Export my data (JSON) | Back up Orpheus (ZIP) |
| --- | --- | --- |
| Songs, artists, albums (as a list) | yes | yes |
| Playlists | yes | yes |
| Auto playlists (as they are now) | yes | yes |
| Play history and statistics | yes | yes |
| Playlist cover pictures | no | yes |
| Preferences, with the music folders | no | yes |
| Your music files | no | no |

The file is named `orpheus-backup-<yyyy-MM-dd>.zip` unless you change it in the save dialog. A backup only reads what
Orpheus holds and writes only the file you chose. Like the export, it waits for the library, the playlists and the play
history to load and builds the ZIP without freezing the window. It says *Backed up, but some data could not be read*
when a source could not be read (the data's `problems` is then not empty) or a cover picture could not. If the library
cannot be read, nothing is saved.

### The files in the ZIP

```text
backup.json
data.json
preferences.json
covers/<playlistId>
```

| File | Meaning |
| --- | --- |
| `backup.json` | What the ZIP is: its `format`, the version of its layout, when it was made, and the other files in it. Described [below](#backupjson). |
| `data.json` | The data export document described on this page, exactly as *Export my data (JSON)…* writes it: same keys, same order, same `formatVersion`. It has its own `format`, `orpheus-data`. |
| `preferences.json` | The owner's preferences, described [below](#preferencesjson). |
| `covers/<playlistId>` | One file for each playlist that has a cover of its own, holding the picture's bytes as Orpheus keeps them, with no extension. `<playlistId>` is the `id` of that playlist in `data.json`'s `playlists`. A playlist whose picture cannot be read is left out, and the backup is reported as partial. |

Nothing else is in the ZIP: not your music files, not the library's own cover cache (a scan makes it again), and not the
update version you chose to skip, which is a fact about one device.

### backup.json

The keys, in this order. A test in the repository holds this list to the file Orpheus writes.

```text
format
formatVersion
createdAt
orpheusVersion
contents
```

| Key | Type | Nullable | Meaning |
| --- | --- | --- | --- |
| `format` | string | no | Always `"orpheus-backup"`. Check it first, to know the ZIP is one of these. |
| `formatVersion` | integer | no | The version of the *ZIP's* layout, currently `1`. It is separate from `data.json`'s `formatVersion`; see [Versioning](#versioning). |
| `createdAt` | string (time) | no | When the backup was made, as the times above. |
| `orpheusVersion` | string | yes | The version of Orpheus that wrote it; `null` when it is not known. |
| `contents` | array of string | no | The other files in the ZIP, as they are named in it: `data.json`, `preferences.json`, then one `covers/<playlistId>` for each cover. |

### Example backup.json

```json
{
  "format": "orpheus-backup",
  "formatVersion": 1,
  "createdAt": "2026-10-19T14:00:00.000Z",
  "orpheusVersion": "1.5.0",
  "contents": [
    "data.json",
    "preferences.json",
    "covers/p1"
  ]
}
```

The example is read by the same test as the key lists: it checks that it is valid JSON with the keys above, in order,
and a `format` and `formatVersion` that this release accepts.

### preferences.json

An object with these keys, in this order. A test in the repository holds this list to the file Orpheus writes.

```text
themeMode
locale
opensPlayerOnPlay
rescansAtStartup
fetchesLyricsOnline
checksForUpdatesOnStartup
showsAutoPlaylists
volume
libraryFolders
```

| Key | Type | Nullable | Meaning |
| --- | --- | --- | --- |
| `themeMode` | string | no | `"system"`, `"light"` or `"dark"`. |
| `locale` | string | yes | The language chosen, as Orpheus keeps it: `"en"` or `"pt_BR"`, with an underscore. `null` follows the system's language. |
| `opensPlayerOnPlay` | boolean | no | *Open the player when a track starts*. |
| `rescansAtStartup` | boolean | no | *Re-scan the library at every launch*. |
| `fetchesLyricsOnline` | boolean | no | *Look up missing lyrics online*. |
| `checksForUpdatesOnStartup` | boolean | no | *Check for updates when Orpheus starts*. |
| `showsAutoPlaylists` | boolean | no | *Show auto playlists*. |
| `volume` | number | no | The playback volume, from `0` to `1`. |
| `libraryFolders` | array of string | no | The music folders, as the machine stored them. |

When Orpheus reads the file, a key that is missing or holds the wrong kind of value stands in as it is on a fresh
install (`"system"`, `null`, `true`, `1`, `[]`), so a backup from a release with fewer preferences still restores the
ones it has. A `preferences.json` that is not a JSON object is treated as absent.

## Restoring

*Preferences → Your data → Restore from a backup…* opens a file dialog for a `.zip` or a `.json`, reads the file without
freezing the window, and shows what it holds before anything is written.

**What is accepted.** A file that starts the way a ZIP does is read as a backup ZIP, and anything else as a data JSON.

- A **backup ZIP** needs a `backup.json` whose `format` is `orpheus-backup` and a `data.json` whose `format` is
  `orpheus-data`, each with a `formatVersion` that is a whole number from 1 up to the one this release reads.
  `preferences.json` and `covers/` are optional: without a readable `preferences.json` the backup restores everything
  else, and a cover with no playlist of that `id` in `data.json` is ignored. Files in the ZIP that this page does not
  name are ignored.
- A **data JSON** needs a `format` of `orpheus-data` and a supported `formatVersion`. It holds no preferences, covers or
  music folders, so none of those is restored from it.
- Anything else shows *This isn't an Orpheus backup*, and a `formatVersion` higher than this release reads shows *This
  backup is from a newer Orpheus — update first*. Nothing is written either way.

**What a restore reads.** Besides `preferences.json` and `covers/`, only these keys, and nothing else in the file:

- `format` and `formatVersion` of `data.json`, and of `backup.json` in a ZIP, to accept the file. The date the restore
  shows is `backup.json`'s `createdAt` for a ZIP, and `data.json`'s `exportedAt` for a data JSON.
- `songs`: `id`, `path`, `title`, `artist`, `album` and `durationMs`, which the songs the playlists and the history name
  are matched by.
- `playlists`: `id` (which the playlist's cover is filed under), `name`, `createdAt` and `modifiedAt`, and each entry's
  `path`, `songId`, `title`, `artist`, `album` and `durationMs`.
- `playHistory`: each record's `path`, `songId`, `plays`, `lastPlayedAt` and `recentPlays`.
- `problems`: each problem's `section`.

The artists, albums, auto playlists and statistics are worked out again from the library and the history, and are not
restored.

**A part the backup could not read.** When `problems` names `playlists` or `playHistory`, that section of the file is
empty because it could not be read, not because the owner had none, so a restore does not offer it (*Not in this
backup*): replacing the playlists here with an empty section would wipe real data. A `songs` problem only means fewer
songs to match by.

### Matching songs

A path is only good on the machine that wrote it, so a backup's songs are matched to the library of the device that is
restoring. For a ZIP, the restore's first stage is where the owner points Orpheus at the music, and the library is
scanned before anything is matched. A scan already under way is waited for first, for a data JSON too. When the scan
fails, or access to the music is refused, the choices say that some songs may not be found in the library.

1. **By path.** When the backup named exactly one music folder and this device has exactly one, a path under the old
   folder is moved to the same relative path under the new one, using the new folder's separators, and the moved path
   is looked for in the library first; then the path as the backup has it.
2. **By tags**, when no path matched: the same `title`, `artist` and `album`, compared trimmed and ignoring case, and a
   length within 2 seconds, and only when **exactly one** library song answers. A song with no title or no length is not
   matched by tags, and two library songs that both answer are not guessed between.

A matched song's data goes to the **library song's path**. A song that is not matched keeps the backup's path, so its
plays and its place in a playlist wait for the file to turn up, and the playlist shows it as missing meanwhile.

### What Merge, Skip and Replace do

The restore screen offers a choice for each of three parts, each defaulting to **Merge**, which never loses anything
here. A part is whole or untouched: the playlists are written as one list and the history as one history. A part whose
data here could not be read is refused (*this part couldn't be read here, so it was left alone*) rather than written
over.

| Part | Merge | Skip | Replace |
| --- | --- | --- | --- |
| Playlists | A backup playlist whose name is not here is added. One with the name of a playlist here (the most recently changed, if several share it) gives that playlist the entries whose song it does not already hold, appended in the backup's order; a cover is restored only to a playlist here that has none. | Only backup playlists whose name is not here are added. A backup playlist whose name is here is left out, and everything here stays as it is. | Every playlist here is removed, with its cover, and the backup's are created, with theirs. |
| Play history | Per song: `plays` is the highest of the count here, the count in the backup and the number of dated plays left after putting the two lists together; `lastPlayedAt` is the later of the two; the dated plays are the two lists together, each date once, from the last 90 days only. Songs only the backup has are added. | Only songs with no history here are added. | The history here is replaced by the backup's, and is empty if the backup's was. |
| Preferences | The backup's value is applied for each setting whose value here equals a fresh install's (`"system"`, `null`, `true`, `1`), since the store cannot tell a setting never touched from one set back to its default; the others stay. | Nothing changes. | All eight values are applied, volume and a `null` language included. |

- **Music folders** are never changed by these choices. Only the restore's first stage changes them, and only when the
  owner presses *Continue*.
- **Ids.** Every playlist a restore adds, and every entry in it, gets a new id, because the backup's may be one already
  used here; a cover is stored under the new playlist id. When entries are merged into a playlist here, a song the
  backup lists twice is added once.
- **Two backup songs that match one library song** are combined the way the history's Merge combines two records.
- **A data JSON** has no preferences, so that part is not offered (*Not in this file*), and no covers, so playlists
  restored from it have none.

A restore never changes a music file. It changes the music *folders* only when the owner, in the first stage, chooses a
different set: that set becomes the whole set, a folder not chosen is taken out of the library, and nothing on disk is
touched. The first stage is shown for a ZIP only, since a data JSON names no folders.

## Versioning

`formatVersion` is an integer, `1` today.

- **A change that keeps old readers working does not change the number.** Adding a key to an object, adding a value to
  a list or a new top-level section is not a new version, so a reader must **ignore keys it does not know**.
- **A change that could break a reader does.** Removing or renaming a key, changing a key's type or meaning, changing
  how a reference works, or making a nullable value non-null or the other way round, raises `formatVersion`.
- A reader should refuse a `formatVersion` higher than the one it was written for, and say so, rather than guess.
- Keys keep their order within a version.
- **The backup ZIP has a version of its own** (`backup.json`'s `formatVersion`, `1` today), under the same rules, apart
  from `data.json`'s. A restore refuses a ZIP or a data document of a higher version than it reads, and says the backup
  is from a newer Orpheus.

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
