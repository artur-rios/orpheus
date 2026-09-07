# Testing Specification Document — Orpheus

## 1. Principles

**A rule nobody checks is a comment.** Every promise this project makes that a
machine can verify is verified by a test, not asserted in a document.

**Nothing reaches outside the process.** No test reads the developer's own
preferences, writes into their application-support folder, records against their
listening statistics, opens the native playback engine, starts a platform media
service, writes into a music folder, or touches the network (`NFR-08`). Every
one of those is a provider, and every one is overridden by the harness — the
lyrics lookup included, which is scripted rather than reached, so no test in
the suite opens a socket.

**One behaviour per test.** A test asserting three things fails once and tells
you one thing.

## 2. Naming

Given-When-Then, in one identifier:

```
GivenSomeCondition_WhenSomeAction_ThenSomeOutcome
```

```dart
test(
  'GivenATrackWithAStoredPosition_WhenItIsPlayed_ThenTheOwnerIsAskedBeforeAnythingOpens',
  () async { ... },
);
```

The *Then* states an observable outcome, never an implementation detail. "Then
the engine opens it from the start" is a behaviour; "then `_openAt` is called"
is not.

## 3. Layout

Tests follow the source tree: `lib/x/y.dart` is tested by `test/x/y_test.dart`.

```
test/
  core/              the guard tests
  features/
    library/         domain, data, application, presentation
    playback/        …
    stats/           …
    shell/           …
    lyrics/          …
  support/           the harness, the fakes, and the fixtures
```

## 4. The harness

`test/support/test_container.dart` builds a provider container with every
outward dependency bound to a double:

| Provider | Double |
| --- | --- |
| `settingsStoreProvider` | in-memory preferences |
| `appDirectoriesProvider` | a path no test writes to |
| `catalogStoreProvider` | in-memory catalog |
| `coverStoreProvider` | in-memory covers |
| `playHistoryStoreProvider` | in-memory play history |
| `audioPlayerProvider` | a fake engine that records what it was asked to open |
| `mediaSessionProvider` | a fake session that records what it was shown |
| `trackProbeProvider` | a fake answering which files exist |
| `libraryAccessProvider` | a fake permission gate |
| `folderPickerProvider` | a fake folder picker |
| `shuffleRandomProvider` | a seeded source |
| `clockProvider` | a pinned instant, where the test needs one |
| `lyricsSourceProvider` | a source answering the words the test seeded, by track path |
| `energyStoreProvider` | in-memory analyses, so no test writes a spectrum to disk |
| `trackAnalysisProvider` | a scripted analysis, so no test starts a decoder |

A test that needs a real edge — the JSON stores, the cover store, the tag
reader — uses a temporary directory it creates and deletes.

## 5. What is tested where

| Layer | What its tests assert |
| --- | --- |
| **domain** | Pure rules, with no container at all: the play threshold, the album-artist derivation, the rankings, the queue, the search ranking. |
| **data** | The outward edges against real files in a temporary directory: what round-trips, what a malformed document does, what an incompatible version does. |
| **application** | Flows through the controllers against the harness: what was queued, what was opened, what was recorded, what was published. |
| **presentation** | Widget tests over a real tree: what is on screen, what a press does, what an empty state says, and both languages where the words are the point. |

## 6. The guard tests

Two tests assert rules rather than behaviour, and exist because a rule nobody
checks is a comment.

| Test | Rule |
| --- | --- |
| `test/core/theme/no_colour_literal_test.dart` | Every colour comes from the theme's single seed; nothing outside `lib/core/theme/` may declare one (`FR-UX-08`). |
| `test/core/l10n/catalog_parity_test.dart` | Both catalogs stay complete, every message carries a description, and a translation uses the same placeholders as its original (`FR-UX-09`). |

## 7. Fixtures

The scanner and the tag reader are tested against **real audio files** built by
`test/support/flac_fixture.dart` — a genuine FLAC header with real Vorbis
comments and a real embedded picture, small enough to write from a test.

ID3 tags are built the same way by `test/support/id3_fixture.dart` — a real tag,
frame by frame, in any of the three versions, with the header and frame flags
and the four text encodings the reader has to cope with. It exists because the
synchronised-lyrics reader walks those bytes itself: the branches worth testing
are the ones an ordinary file would not happen to carry, and the only way to
have a file that carries them is to write one.

A tag reader tested against a mock of itself proves nothing. This is why the
reader is pure Dart in the first place.

## 8. Coverage expectations

Not a percentage. The expectation is stated as rules:

- Every use case's **main flow** is covered.
- Every **alternative flow** that describes an observable outcome is covered.
- Every rule in [Business Rules](../initial/Business%20Rules.md) that a machine
  can check is covered by at least one test.
- Every bug fixed gets the test that would have caught it.

## 9. Running

```bash
flutter analyze              # must report no issues
flutter test                 # must be green
flutter test test/features/stats     # one area
```

Neither a failing analyzer nor a failing suite may be merged, and there is no
known-warnings list to add to.
