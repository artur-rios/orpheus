---
title: Architecture
weight: 20
description: The layering, the domain models, and the rule every feature follows.
---

## The shape of it

Orpheus is organised by **feature**, and each feature by **layer**. There is no
`models/`, `services/`, `widgets/` split — a change to how lyrics work touches
one directory, not four.

```mermaid
flowchart TD
    P["presentation<br/><small>widgets, screens</small>"]
    A["application<br/><small>controllers, state</small>"]
    D["domain<br/><small>models, interfaces</small>"]
    DA["data<br/><small>files, tags, network</small>"]
    DI{{"core/di/providers.dart<br/><small>the single composition root</small>"}}

    P --> A
    A --> D
    DA -.implements.-> D
    DI -.binds.-> DA
    DI -.binds.-> A

    classDef pure fill:#4a6fa5,stroke:#2c4368,color:#fff
    classDef edge fill:#7a5c9e,stroke:#4a3560,color:#fff
    classDef root fill:#3f6b4f,stroke:#264530,color:#fff
    class D pure
    class DA edge
    class DI root
```

The rule that matters: **`domain` has no Flutter and no IO.** It is models and
interfaces. `data` implements those interfaces at the outward edges — the
filesystem, the tag reader, the playback engine, the one network call. Nothing
in `domain` knows any of them exist.

That is what makes the whole test suite run without a real audio engine, a real
filesystem or a real network: every outward dependency is an interface bound in
one place, and a test overrides the binding.

### The features

| Feature | What it owns |
| --- | --- |
| `library` | Registering folders, scanning them, the catalog, cover art |
| `playback` | The queue, the engine, the player screen, the spectrum bars |
| `lyrics` | Finding a track's words, and reading along with them |
| `stats` | The play threshold, the history, and the rankings |
| `shell` | The frame: navigation, the playback bar, preferences |

## The library model

What a scan produces, and what every screen in the music area reads from.

```mermaid
classDiagram
    class MusicCatalog {
        +List~MusicEntry~ entries
        +DateTime? scannedAt
        +Map~String, MusicEntry~ byPath
        +bool isEmpty
        +entryFor(AudioFile) MusicEntry
        +entryAt(String path) MusicEntry?
    }

    class MusicEntry {
        +AudioFile file
        +TrackMetadata metadata
        +String? albumArtistOfRecord
        +String? album
        +String? artist
        +String? albumArtist
    }

    class AudioFile {
        +String path
        +int sizeInBytes
        +DateTime modifiedAt
    }

    class TrackMetadata {
        +String? title
        +String? artist
        +String? albumArtist
        +String? album
        +String? genre
        +int? track
        +int? disc
        +int? year
        +Duration? duration
        +String? coverId
    }

    MusicCatalog "1" *-- "many" MusicEntry
    MusicEntry "1" *-- "1" AudioFile
    MusicEntry "1" *-- "1" TrackMetadata
```

Two things in that model are worth explaining, because both exist to fix a
real bug rather than to be tidy.

`byPath` is built once and lazily. The player asks "what is this file?" for
every track it opens and every frame the bar draws, and a linear search of the
whole library per frame is what that becomes without an index.

`albumArtistOfRecord` is how a compilation stays one record. Half-tagged
libraries are the norm, so where a file carries no album-artist tag the answer
is worked out across the whole record rather than falling through to the
performer — which is what keeps a rap album with a guest on every track out of
the artist list twelve times over.

## The outward edges

Every one of these is an interface in `domain` with an implementation in `data`
and a binding in the composition root. The right-hand column is what a test gets
instead.

```mermaid
classDiagram
    direction LR

    class CatalogStore {
        <<interface>>
        +read() Future~MusicCatalog~
        +write(MusicCatalog) Future~void~
        +clear() Future~void~
    }
    class MediaPlayer {
        <<interface>>
        +Stream~PlaybackStatus~ status
        +open(String path, Duration startAt) Future~void~
        +play() Future~void~
        +pause() Future~void~
        +seek(Duration) Future~void~
        +setVolume(double) Future~void~
    }
    class LibraryScanner {
        <<interface>>
        +scan(List~String~ folders) Stream~ScanEvent~
    }
    class MediaSession {
        <<interface>>
    }

    JsonCatalogStore ..|> CatalogStore
    InMemoryCatalogStore ..|> CatalogStore
    MediaKitPlayer ..|> MediaPlayer
    FakeMediaPlayer ..|> MediaPlayer
    IsolateLibraryScanner ..|> LibraryScanner
    ScriptedScanner ..|> LibraryScanner
    AudioServiceMediaSession ..|> MediaSession
    SilentMediaSession ..|> MediaSession
```

`SilentMediaSession` is not only a test double. It is the honest answer on the
two desktop targets, which have no notification and no lock screen — the Android
session sits behind the same interface and is bound only there.

## The flows

- **[Finding a track's words]({{< relref "/docs/architecture/lyrics" >}})** —
  the only flow that reaches a network, and the order that governs it.
- **[Scanning a library]({{< relref "/docs/architecture/library" >}})** — why a
  re-scan of an unchanged library is nearly free.
- **[Playing something]({{< relref "/docs/architecture/playback" >}})** — the
  states a player can be in, including the two that are about failure.
