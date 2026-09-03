# Technology Stack — Orpheus

The informal record of what was chosen and why. The normative list of versions
is the [Technology Stack Document](../requirements/Technology%20Stack%20Document.md);
this is the reasoning behind it.

## The constraint everything else follows from

**Three targets, one source: Windows, Linux and Android.** Every decision below
is the answer to "which option covers all three without a per-platform
implementation".

That constraint is why this project exists at all. Alexandria's Rust core is
linked in process over FFI and has no Android build, so the music half could
not leave the desk. Anything chosen here that needs a fourth implementation for
a fourth platform is a decision that would put us back there.

## Flutter and Dart

The toolkit. It covers the two desktops and Android from one source, it is what
Alexandria's front end is already written in, and its widget testing runs a real
tree in a plain process — which is what makes the interface testable without a
device.

The alternative considered was a native shell per platform with a shared core.
That is the Alexandria architecture, and it is the thing this project is
getting away from.

## media_kit for playback

libmpv-backed, and the one engine in its class that covers all three targets
with the same API and the same container and codec range without transcoding
anything.

The cost is stated plainly: on Linux it needs libmpv present at runtime, which
is a dependency the owner installs. Windows and Android bundle their own. That
is a smaller cost than either a per-platform engine or a codec matrix that
differs by machine.

It is used behind an interface (`MediaPlayer`) rather than directly, for a
reason beyond tidiness: the engine is a native library that cannot run in a
widget test, so every flow above that line is testable *only* because the line
exists.

## audio_metadata_reader for tags — in pure Dart

Covers ID3, Vorbis comments, iTunes atoms, RIFF and APE.

Pure Dart is the whole point. Tag reading is the one component that would
otherwise need a native build per target, and — more importantly — a reader
that cannot run in a test is a reader whose parsing nobody checks. The scanner
and the reader are tested against real files built by the test suite itself.

## audio_service and audio_session for Android background playback

A foreground service is the only mechanism Android offers for a process that
keeps making noise once it is no longer on screen, and the notification it
posts is what the system requires of one. `audio_service` supplies both, plus
the lock screen and media-button plumbing. `audio_session` supplies audio
focus — the phone call that should pause the music, and the headphones pulled
out of the socket.

Both are Android-only in effect, which is why they sit behind a `MediaSession`
interface with a silent implementation for the two desktops. Neither desktop
gets a media session today; the seam is where one would go.

## Riverpod for state and composition

The same choice Alexandria's front end made, for the same reason and one more.

The reason: the player outlives the screen that started it, so the queue has to
live somewhere that is not a widget.

The one more: a single composition root where every outward dependency is bound
means a test overrides a binding rather than reaching into the widget tree or
patching a global. That is what lets the whole suite run without touching the
developer's own preferences, their application-support folder, the network, or
a real audio device.

## Storage: JSON documents and shared_preferences

There is no database and there is deliberately none.

**The catalog is one JSON document**, because the whole library is read at once
and never queried piecemeal — every screen in the music area groups across all
of it, so there is no query a database would answer that reading the file does
not. It is written to a temporary file and renamed over the real one, which is
atomic on every filesystem this runs on.

**The play history is a second document** in the same shape and for the same
reasons.

**Cover art is a directory of files**, one per distinct picture, addressed by a
hash of its bytes. Plain files because pictures are the only large thing cached,
they are written once and read many times, and a directory of them can be
inspected, backed up and deleted by the owner without this application's help.

**Preferences go in `shared_preferences`**, which is the platform's own
mechanism on all three targets.

## Supporting choices

| Package | Why it, specifically |
| --- | --- |
| `file_picker` | The one package whose `getDirectoryPath` answers on Android as well as on both desktops. `file_selector` does not. |
| `permission_handler` | Android's per-media read permission (`READ_MEDIA_AUDIO`), asked for on Android and nowhere else. |
| `window_manager` | The desktop window's minimum size and restored geometry. Desktop-only by nature and guarded as such at every call. |
| `path_provider` | Where this application may write, per platform. |
| `intl` + `flutter_localizations` | English and Brazilian Portuguese, with a generated catalog and a parity test. |
| `logging` | Structured logging, one logger per feature area. |

## Layering

Each feature is `domain` (no Flutter, no IO), `data` (the outward edges),
`application` (the controllers) and `presentation` (the widgets). Nothing
outward is constructed anywhere but the composition root.

This is Alexandria's layering, kept deliberately. It is not chosen for
architectural fashion; it is chosen because the two things this application
cannot test directly — a native audio engine and a platform media service — are
both at the outward edge, and layering is what keeps them there.
