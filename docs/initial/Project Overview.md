# Project Overview — Orpheus

## What This Is

Orpheus is a music player for Windows, Linux and Android. It reads the audio
files already present on the machine it runs on, names every track by its tags
rather than by its file name, and plays them — with the same interface on all
three platforms.

It is the music half of [Alexandria](https://github.com/artur-rios/alexandria-ui)
taken out on its own: the same browsing area, the same persistent playback bar,
the same full-window player. What changed is what stands behind it. Alexandria
reads its catalog from a Rust core over FFI; Orpheus has no core and no server.
It walks the folders it is pointed at, reads the tags itself, and keeps the
result in a file beside its own settings.

## The Problem

A person with music on disk has two bad options.

**A streaming client** does not play their files. It plays a catalog somebody
else curates, requires an account, requires the network, and stops working the
day a licence lapses. The record they bought is not in it.

**A desktop music player** plays their files and stops at the edge of the
desk. The same library is unreachable from the phone in their pocket without
either a sync service, a server to run, or a second application with its own
idea of what the library contains.

Between them sits a specific, ordinary want: *play the files I already have, on
the machines I already use, without asking anyone's permission and without
sending anything anywhere.* That is the whole of what this project is for.

Alexandria answers half of it. It is a desktop application with a Rust core
linked in process, and there is no build of that core for Android — so the
music it manages so carefully cannot leave the desk. Orpheus is that half,
rewritten to stand alone and to run where the listening actually happens.

## Who It's For

**The owner.** One person, with their own music on their own disks. There is no
second role, no sharing, no administration, and no account. The word *owner*
appears throughout these documents in place of *user* for that reason: this
application has exactly one, and everything it holds belongs to them.

They are assumed to be someone who has files rather than subscriptions, who
cares that their tags are more or less right, and who would rather their music
player did not have opinions about what they should listen to next.

## What It Does

- **Reads a library from folders the owner chooses.** Registered folders are
  walked, every audio file's tags are read, and cover art is extracted. Nothing
  is indexed that was not pointed at.
- **Browses by artist, record and song**, in rows or as a wall of sleeves, with
  a way back out of whatever was drilled into.
- **Searches** across titles, artists and records, ranked so a match at the
  start of a title outranks one buried in the middle of something else.
- **Plays a track, a record, an artist, or everything shuffled**, with a visible
  queue, repeat, and a resume point per track.
- **Shows what is playing everywhere** — a persistent bar across the bottom and
  a full player with the record's sleeve as large as the window allows.
- **Keeps playing on Android** once the application is no longer on screen,
  from a notification and a lock screen that carry the transport controls.
- **Says what the owner listens to** — most played tracks, artists, records and
  genres, counted from their own listening and nobody else's.
- **Adapts to the window**: a rail down the side on a desktop, a bar across the
  bottom on a phone.
- **Light and dark, English and Brazilian Portuguese.**

## What It Doesn't Do

- **It never writes to the owner's audio files.** No tag editing, no renaming,
  no moving, no deleting, no transcoding. They are opened for reading and that
  is all. The one thing written into a music folder is a `.lrc` beside a track
  whose words were looked up — a new file, never a replacement for one the
  owner wrote.
- **Almost no network.** No streaming, no scrobbling, no telemetry, no
  analytics, no crash reporting, no cover art fetched from anywhere. The single
  exception is the lyrics lookup, which sends a track's artist and title and
  which the owner can turn off. The Android package declares exactly seven
  permissions and CI fails on an eighth, which is the version of this promise a
  machine can check.
- **No accounts, no sync, no cloud.** One person, one machine, one library.
- **No library management.** Organising, tagging and de-duplicating a music
  collection is a different program. This one reads what is there.

## How Success Is Measured

1. **A folder becomes a library without instruction.** The owner points at a
   folder and gets a browsable, playable library, with no configuration step
   and no explanation of what a scan is.
2. **Nothing is lost when tags are poor.** A half-tagged library — the common
   case — browses sensibly rather than fragmenting into one artist per track.
3. **The same interface answers on all three platforms.** Not a desktop program
   with a phone build, but one application whose layout rules cover both.
4. **Playback survives the phone.** Music started on Android keeps playing when
   the owner switches away, and is controllable without returning to the
   application.
5. **The promises are checkable.** "It never touches your audio files" and
   "nothing but the lyrics lookup leaves the machine" are enforced by the test
   suite and by the shipped package's permissions, not asserted in a README.
6. **A change is safe to make.** Every flow above the platform edges is covered
   by tests that run without a real audio engine, a real filesystem, or a real
   device.
