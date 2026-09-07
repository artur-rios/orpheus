---
title: Overview
weight: 10
description: What Orpheus is, what it refuses to be, and why.
---

## The problem

A person with music on disk has two bad options.

A **streaming client** does not play their files. It plays a catalog somebody
else curates, requires an account, requires the network, and stops working the
day a licence lapses. The record they bought is not in it.

A **desktop music player** plays their files and stops at the edge of the desk.
The same library is unreachable from the phone in their pocket.

Orpheus is the third option: one player, the owner's own files, the same
interface on Windows, Linux and Android.

## What it does

| | |
| --- | --- |
| **Reads a library from folders you choose** | Registers one or more folders, walks them, reads the tags out of every audio file and pulls out the cover art. Nothing is indexed that you did not point it at. |
| **Browses by artist, album and song** | In rows or as a wall of sleeves, with a breadcrumb back out of whatever you drilled into. |
| **Plays a track, a record, an artist, or everything shuffled** | With a queue you can see and jump around in, repeat, and a resume point per track. |
| **Shows what is playing everywhere** | A persistent bar across the bottom, and a full player with the record's own sleeve as large as the window allows. |
| **Draws the music itself** | The bars on the player are the spectrum of the recording, measured from its own samples by the engine that plays it. |
| **Keeps playing on Android** | From a notification and the lock screen — and stops for a phone call, and for headphones pulled out of the socket. |
| **Shows the words, in time with the music** | Your own files first; a lookup for the tracks that have none. |
| **Says what you actually listen to** | Total plays, and the most played tracks, artists, records and genres — counted from your own listening and nobody else's. |
| **Adapts to the window** | A rail down the side on a desktop, a bar across the bottom on a phone. |
| **Light and dark, English and Brazilian Portuguese** | |

## What it deliberately does not do

**It never touches your audio files.** No tag editing, no renaming, no moving,
no deleting, no transcoding. They are opened for reading and that is all. The
one thing Orpheus ever writes into a music folder is a `.lrc` next to a track
whose words it looked up — a new file, never a replacement for one you wrote,
and never the track itself.

**Almost no network.** No streaming, no scrobbling, no telemetry, no analytics,
no crash reporting, no cover art fetched from anywhere. The single exception is
the lyrics lookup, which you can turn off.

That last promise is enforced rather than asserted. The Android package declares
an exact set of permissions, and CI reads them back out of the built package and
**fails the build on any permission not on that list** — including one merged in
by a dependency.

**No accounts, no sync, no cloud.** One person, one machine, one library.
Nothing Orpheus sends identifies you or persists between requests: no account,
no key, no identifier of any kind.

**No library management.** Organising, tagging and de-duplicating a music
collection is a different program. This one reads what is there.

## The one thing that leaves the machine

For a track with no words on your machine — no `.lrc` beside it, no `SYLT`
frame, no lyrics tag — and only while you leave the lookup on, Orpheus asks a
lyrics service for them using **that track's artist and title**, with its record
and length where the tags give them.

It sends nothing else: not the file's name, not its path, not your library, not
what else is on the machine. A track whose tags do not give both an artist and a
title is not looked up at all, because a lookup on a title alone is a guess
between every recording that shares the name.

See [the lyrics flow]({{< relref "/docs/architecture/lyrics" >}}) for exactly
how that is ordered.

## How it is built

Flutter, one source tree, three targets. The playback engine is libmpv through
`media_kit` — the one engine in its class that covers Windows, Linux and Android
with the same API and the same codec range, without transcoding anything.

Tags are read in pure Dart, which matters more than convenience: it is the one
component that would otherwise need a native build per target, and a reader that
cannot run in a test is a reader whose parsing nobody checks.

There is no database. The catalog is a JSON document, read once and held for the
run — a library of tens of thousands of tracks is a few megabytes of tags, and
every screen in the music area needs all of it to group by.
