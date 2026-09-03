# Orpheus

A music player for Windows, Linux and Android. It reads the audio files already
on the machine it is running on, names every track by its tags rather than by
its file name, and plays them — with the same interface on all three platforms.

It is the music half of [Alexandria](https://github.com/artur-rios/alexandria-ui)
taken out on its own: the same browsing area, the same persistent playback bar,
the same full-window player. What changed is what stands behind it. Alexandria
reads its catalog from a Rust core over FFI; Orpheus has no core and no server.
It walks the folders it is pointed at, reads the tags itself, and keeps the
result in a file beside its own settings.

> **Status:** complete and tested. 197 unit and widget tests; `flutter analyze`
> clean. Verified running on Linux, and the Linux and Android release builds
> are verified to produce a binary from this checkout. Neither Windows nor
> Android has been run on a device here.

## What it does

- **Reads a library from folders you choose.** Register one or more folders and
  Orpheus walks them, reads the tags out of every audio file, and pulls out the
  cover art. Nothing is indexed that you did not point it at.
- **Browses by artist, album and song**, in rows or as a wall of sleeves, with a
  breadcrumb back out of whatever you drilled into.
- **Plays a track, a record, an artist, or everything shuffled**, with a queue
  you can see and jump around in, repeat, and a resume point per track.
- **Shows what is playing everywhere** — a persistent bar across the bottom, and
  a full player with the record's own sleeve as large as the window allows.
- **Keeps playing on Android once you switch away**, from a notification and the
  lock screen that carry the sleeve and the transport buttons — and stops for a
  phone call, and for headphones pulled out of the socket.
- **Searches** across titles, artists and albums, ranked so a match at the start
  of a title comes above one buried in the middle of something else.
- **Adapts to the window**: a rail down the side on a desktop, a bar across the
  bottom on a phone, and the same rules at every width in between.
- **Light and dark, English and Brazilian Portuguese.**

## What it doesn't do

- **It never writes to your music.** No tag editing, no renaming, no moving, no
  deleting, no transcoding. It opens files for reading and that is all.
- **No network of anything.** No streaming, no scrobbling, no metadata lookup,
  no cover art fetched from the internet. The Android package asks for no
  `INTERNET` permission, which is the version of this promise a machine can
  check.
- **No accounts, no sync, no cloud.** One person, one machine, one library.

## Screenshots

The library, and a record opened inside it:

| Artists | Inside a record |
| --- | --- |
| ![The artists list](docs/images/artists.png) | ![A record's tracks](docs/images/album.png) |

## Installing and running

Orpheus is a Flutter application. There are no published packages yet; build it
from source.

```bash
flutter pub get
flutter run -d linux      # or -d windows, or a connected Android device
```

**Linux** additionally needs libmpv at runtime — the playback engine is
media_kit, which is libmpv-backed:

```bash
sudo apt install libmpv-dev mpv     # Debian and Ubuntu
```

**Android** needs no extra dependency; the engine ships inside the package. The
minimum supported release is Android 6 (API 23).

**Windows** needs no extra dependency either — the engine's DLLs are bundled by
`media_kit_libs_audio`.

### First run

The library starts empty and stays empty until you point it somewhere. Open
**Folders**, add the folder your music is in — or press **Add my music folder**,
which offers the platform's conventional one — and the scan starts. On Android
the system asks for permission to read audio files at that point; it is asked
for once you have registered a folder, never before. Android also asks to be
allowed to post the playback notification, and that one is asked for the first
time you press play. Refusing it costs the notification and nothing else —
playback still runs, and still runs in the background.

## How it works

Seven things happen, and they are worth reading in this order.

**A scan walks the folders and reads the tags.** It runs on an isolate of its
own, because it is the whole of the expensive half of this application: a walk
of every path under the library folders and a parse of every audio file among
them. Progress is reported from a strip above the playback bar, and the library
already on screen stays usable while it runs.
(`features/library/data/scan_worker.dart`)

**Tags are read in pure Dart** — `audio_metadata_reader`, covering ID3, Vorbis
comments, iTunes atoms, RIFF and APE. Pure Dart matters here: it is the one
component that would otherwise need a native build per target, and a reader that
cannot run in a test is a reader whose parsing nobody checks.
(`features/library/data/tag_reading.dart`)

**Cover art is extracted once, at scan time, and stored by content.** The id of
a picture is a hash of its bytes, so the twelve tracks of a record that each
carry the same JPEG store it once — which keeps the cache proportional to the
number of records rather than the number of files. A record with no embedded art
but a `cover.jpg` beside it uses that instead.
(`features/library/domain/cover_store.dart`)

**Whose record a track is on is worked out across the record, not per file.**
Several common tag formats have no album-artist field at all, and half-tagged
libraries are the norm — so a rap record whose tracks credit a different guest
each time is one artist rather than twelve. One track carrying the tag settles
the record; with no tag anywhere, the performer most of the record's tracks name
is taken as its artist. That last rule is a judgement, and it is documented as
one where it lives. (`features/library/domain/music_grouping.dart`)

**The catalog is a single JSON document, written atomically.** It is read back at
launch so a start is fast, and re-scanned behind the interface: a file still on
disk at the same size and timestamp is carried over rather than re-parsed, which
is what makes re-scanning an unchanged library cheap enough to do at every
launch. (`features/library/data/json_catalog_store.dart`)

**The player outlives the screen that started it.** The queue and the engine
live in a controller; the bar and the full player are views of it. A file that
is missing or will not decode is named, stepped over, and the queue carries on;
when the queue runs out of tracks to try, it says so.
(`features/playback/application/audio_playback_controller.dart`)

**On Android the notification is the background playback.** A foreground
service is the only way the system lets a process keep making noise once it is
no longer on screen, and the notification is what a foreground service is
obliged to post — so the two are one thing rather than a feature and its
decoration. The session behind it is a third view of the same player, alongside
the bar and the full player: it shows what is playing and it sends back what was
pressed, and it holds no queue of its own. What comes back through it is not
only the transport buttons — a phone call arriving and a pair of headphones
leaving the socket arrive as the same ask, which is why the player never learns
the difference between them. On Windows and Linux the same seam is bound to a
session that shows nothing, which is why none of the code above it has a
platform check in it.
(`features/playback/domain/media_session.dart`)

### The sound bars, honestly

The moving bars on the player screen are **synthesised, not measured**. Nothing
in this application decodes audio — the playback engine reports a position and a
duration and nothing about the waveform behind them — so what they show is a
figure computed from the track's identity and the moment being played.

It is built to the two properties that make that honest: it is **deterministic**
(the same second of the same track draws the same bars every time, on every
machine) and **distinct** (two tracks seed differently and move differently). It
is a sign that something is playing. It is not an analysis, and it is not
labelled as one anywhere in the interface.
(`features/playback/domain/track_energy.dart`)

## Layout

```
lib/
  core/            themes, spacing, breakpoints, settings, failures, l10n,
                   and the single composition root in core/di/providers.dart
  features/
    library/       folders, scanning, tags, cover and catalog storage
    playback/      the queue, the engine and media-session boundaries, and
                   the music area
    shell/         the frame: navigation, the playback bar, preferences
```

Each feature is `domain` (no Flutter, no IO), `data` (the outward edges),
`application` (the controllers), `presentation` (the widgets). Nothing outward
is constructed anywhere but `core/di/providers.dart`, which is what lets a test
override a binding rather than patching a global.

## Building and testing

```bash
flutter analyze              # must be clean; there is no known-warnings list
flutter test                 # 197 unit and widget tests
flutter build linux --release
flutter build windows --release
flutter build apk --release
```

Tests are named Given-When-Then, one behaviour apiece, and follow the source
tree: `lib/x/y.dart` is tested by `test/x/y_test.dart`. Nothing in the suite
reads the developer's own preferences, writes into their application-support
folder, opens the native playback engine, starts a platform media service, or
reaches the network — every one of those is a provider, and every one is
overridden by the harness in `test/support/test_container.dart`.

Two of the tests are guards rather than assertions about behaviour, and they
exist because a rule nobody checks is a comment:

- `test/core/theme/no_colour_literal_test.dart` — every colour comes from the
  theme's single seed, and nothing outside `lib/core/theme/` may declare one.
- `test/core/l10n/catalog_parity_test.dart` — both languages stay complete, every
  message carries a description, and a translation uses the same placeholders as
  its original.

The scanner and the tag reader are tested against real files in a temporary
directory, built by `test/support/flac_fixture.dart` — a genuine FLAC header
with real Vorbis comments and a real embedded picture, small enough to write
from a test.

## Known limits

- **The Android media session is written and built, but unrun on a device.**
  The foreground service, the notification, the lock screen controls and the
  audio-focus handling are all there and are covered by tests against a stand-in
  session; what no test on a build machine can tell you is how the real one
  behaves on real hardware. It is the part of this application most in need of a
  phone.
- **No media session on Windows or Linux.** Neither desktop gets transport keys
  or a system now-playing panel. The seam that would carry them exists and is
  bound to a session that shows nothing, so this is an implementation to write
  rather than a design to change.
- **No playlists.** Queues are built from a track, a record, an artist, or the
  whole library shuffled. There is nothing to save and name yet.
- **A track is identified by its path.** Move a file and it is a different track
  to this application, and its resume point does not follow it. Re-scanning is
  what reconciles that.
- **Album artist for MP4, Vorbis and RIFF tags is derived rather than read.**
  Those formats' readers here do not surface a distinct album-artist field, so
  the across-the-record derivation described above is what answers for them. For
  an ordinary record it gives the same answer; a various-artists compilation with
  no album-artist tag anywhere lands under whichever performer has the most
  tracks on it.
- **Windows and Android are unrun from this checkout.** The Android release
  package builds from this source and its permissions have been read back out of
  the built APK; Windows is configured from the same source and the same engine.
  Neither has been launched on a device here.

## Licence

MIT.
