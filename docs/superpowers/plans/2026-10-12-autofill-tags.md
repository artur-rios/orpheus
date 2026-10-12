# Autofill Tags Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the owner fill a record's (or a lone track's) tags from MusicBrainz, review every change file by file, and write only the confirmed changes into the files and the library.

**Architecture:** A new `lib/features/autofill/` feature (domain / data / application / presentation, like every other feature). Pure matching and proposal logic in the domain; `MusicBrainzSource` (HTTP, throttled) and `AudioMetadataTagWriter` (`audio_metadata_reader`'s `updateMetadata`, on an isolate) at the edges, bound only in `core/di/providers.dart`; an auto-disposed `AutofillController` drives search → review → write, then asks the existing scan controller for a rescan so every screen picks the new tags up.

**Tech Stack:** Flutter 3.47 / Dart 3.13, Riverpod 3 (`Notifier`, `isAutoDispose`), `http` (`MockClient` in tests), `audio_metadata_reader` 1.8.0 (already a dependency), `permission_handler`, gen-l10n (en + pt), ffmpeg (only to generate committed test fixtures).

**Spec:** `docs/superpowers/specs/2026-10-12-autofill-tags-design.md` — read it before starting; this plan argues from it.

**One deliberate refinement of the spec:** the spec's `TagWriter.writableFields(path)` is folded into `TagWriter.inspect(path) → FileTags`, which answers the writable fields *and* the file's current values in one read. A proposal must be measured against what the file holds, not against the catalog — the catalog's album artist is partly worked out across the record — and that needs a read of the file anyway.

## Global Constraints

- Branch: `feature/autofill-tags` (already created, built on `fix/review-and-metadata-refresh`). Never commit to `develop`/`main`.
- Commits: Conventional Commits, all lower case, subject ≤ 50 characters, imperative; body wrapped at 72; **no co-author trailers** (the owner's commit skill).
- Tests: Given-When-Then names (`GivenX_WhenY_ThenZ`), one behaviour each, `lib/x/y.dart` ↔ `test/x/y_test.dart`. Nothing in the suite reaches the network, writes into a real library, or reads the developer's settings.
- Every outward dependency is constructed only in `lib/core/di/providers.dart`; tests override providers through `test/support/test_container.dart`'s `Harness`.
- Every user-visible string is in **both** `lib/core/l10n/app_en.arb` and `lib/core/l10n/app_pt.arb`, each with an `@key` `description`; regenerate with `flutter gen-l10n`. `test/core/l10n/catalog_parity_test.dart` enforces it.
- No colour literals outside `lib/core/theme/` (`test/core/theme/no_colour_literal_test.dart`).
- Code style: match the surrounding code — explanatory `///` doc comments on public members (the analyzer's `public_member_api_docs` is on), comments that say *why*. LF line endings.
- **Do not run `dart format` on whole files or directories** — the installed formatter rewrites hundreds of untouched lines. Write code already formatted; if needed, format only a brand-new file.
- MusicBrainz: base `https://musicbrainz.org/ws/2/`, `fmt=json`, User-Agent `Orpheus/<version> ( https://github.com/artur-rios/orpheus )`, at most one request per second, 503 → one retry after 2 s.
- Writable formats: `.mp3`, `.flac`, `.m4a`, `.mp4`, `.wav`, `.ape` — and each only once its preservation test passes. OGG, Opus, AIFF, Matroska and anything else: never written.
- Default field choice: every field except `cover`. A ticked field **replaces** the current value.
- Verification for every task: `flutter analyze` clean, and the task's tests green; run the whole suite (`flutter test`) at the end of each task.

## Review Focus

1. **Lucene-special characters in queries** — `AC/DC`, `Sgt. Pepper's Lonely Hearts Club Band (Remastered)`, `"Heroes"`: the query must be escaped, not rejected or mangled. Test in Task 5.
2. **Two files claiming the same track** — a two-disc record with no disc tags, both disc's track 1 tagged `1`: the second must fall through to title/duration, not overwrite the first's assignment. Test in Task 3.
3. **Values equal but for whitespace** — `"Radiohead "` vs `"Radiohead"` is not a change; `"radiohead"` vs `"Radiohead"` is. Test in Task 4.
4. **The owner closes the review screen while the lookup is in flight** — the auto-disposed controller must not set state after disposal or throw. Test in Task 10.
5. **A record with bonus tracks on MusicBrainz but not on disk (or vice versa)** — extra release tracks are ignored, extra files are *no match*, and ranking prefers the release whose track count equals the files. Tests in Tasks 2 and 3.

---

## File Structure

| File | Responsibility |
| --- | --- |
| `lib/features/autofill/domain/autofill_field.dart` | The fields, their default set, and their settings encoding |
| `lib/features/autofill/domain/release.dart` | `ArtistCredit`, `ReleaseCandidate`, `ReleaseTrack`, `ReleaseDetail`, `RecordingMatch`, `RecordingAppearance` |
| `lib/features/autofill/domain/metadata_source.dart` | `ReleaseQuery`, `RecordingQuery`, `MetadataSource`, `MetadataSourceException` |
| `lib/features/autofill/domain/tag_writer.dart` | `FileTags`, `WriteOutcome`, `TagWriter`, `canWriteTagsTo` |
| `lib/features/autofill/domain/matching.dart` | `normalised`, `rankCandidates`, `rankAppearances`, `assignTracks`, query building |
| `lib/features/autofill/domain/proposals.dart` | `FieldChange`, `FileProposal`, `proposalsFor` |
| `lib/features/autofill/data/musicbrainz_source.dart` | `MusicBrainzSource` (HTTP, parsing, throttle, retry) |
| `lib/features/autofill/data/audio_metadata_tag_writer.dart` | `AudioMetadataTagWriter` (inspect and write, on an isolate) |
| `lib/features/autofill/application/autofill_controller.dart` | `AutofillState`, `AutofillController` |
| `lib/features/autofill/presentation/autofill_fields_dialog.dart` | The field checklist |
| `lib/features/autofill/presentation/autofill_screen.dart` | The review screen |
| `lib/features/autofill/presentation/autofill_launcher.dart` | `startAutofill` — dialog, then screen |
| `lib/features/autofill/presentation/autofill_field_names.dart` | Localized field names |
| Modified: `lib/core/di/providers.dart` | `metadataSourceProvider`, `tagWriterProvider`, `autofillControllerProvider` |
| Modified: `lib/features/library/domain/library_access.dart`, `data/permission_library_access.dart`, `application/library_folders_controller.dart` | Write access |
| Modified: `lib/features/library/application/scan_controller.dart` | `rescanSoon()` |
| Modified: `lib/features/playback/presentation/music_rows.dart` | The two entry points |
| Tests | Mirrors of the above, plus `test/support/fake_autofill.dart` and `test/support/tag_fixtures/` |

---

### Task 1: Domain types

**Files:**
- Create: `lib/features/autofill/domain/autofill_field.dart`, `lib/features/autofill/domain/release.dart`, `lib/features/autofill/domain/metadata_source.dart`, `lib/features/autofill/domain/tag_writer.dart`
- Test: `test/features/autofill/domain/autofill_field_test.dart`, `test/features/autofill/domain/release_test.dart`, `test/features/autofill/domain/tag_writer_test.dart`

**Interfaces:**
- Consumes: `AudioFile` (`lib/features/library/domain/audio_file.dart`).
- Produces (exact names used by every later task):
  - `enum AutofillField { title, artist, albumArtist, album, trackNumber, trackTotal, discNumber, discTotal, year, genre, cover }`, `static const Set<AutofillField> defaults`, `static Set<AutofillField> decode(String? stored)`, `static String encode(Set<AutofillField> fields)`.
  - `class ArtistCredit { String name; String joinPhrase; }`, `String creditedName(List<ArtistCredit> credits)`.
  - `class ReleaseCandidate { String id, title; List<ArtistCredit> artistCredit; String? date, country, status, primaryType, format, disambiguation; List<String> secondaryTypes; int trackCount; int score; int? get year; String get artist; }`.
  - `class ReleaseTrack { int disc, position; String title; List<ArtistCredit> artistCredit; Duration? length; String? recordingId; String get artist; }`.
  - `class Genre { String name; int votes; }`.
  - `class ReleaseDetail { ReleaseCandidate release; List<ReleaseTrack> tracks; List<Genre> genres; String? releaseGroupId; int get discCount; int tracksOnDisc(int disc); }`.
  - `class RecordingAppearance { ReleaseCandidate release; int disc, position; }`, `class RecordingMatch { String recordingId, title; List<ArtistCredit> artistCredit; Duration? length; int score; List<RecordingAppearance> appearances; }`.
  - `class ReleaseQuery { String? album, artist; String? text; }`, `class RecordingQuery { String? title, artist; Duration? duration; String? text; }` (`text`, when set, is the owner's own words and replaces the structured query).
  - `enum MetadataSourceFailure { unreachable, rateLimited, malformed }`, `class MetadataSourceException implements Exception { MetadataSourceFailure kind; }`.
  - `abstract interface class MetadataSource { Future<List<ReleaseCandidate>> searchReleases(ReleaseQuery); Future<ReleaseDetail> release(String id); Future<List<Genre>> releaseGroupGenres(String id); Future<List<RecordingMatch>> searchRecordings(RecordingQuery); Future<Uint8List?> frontCover(String releaseId); }`.
  - `enum WriteOutcome { written, unsupported, changedSinceRead, inUse, denied, failed }`.
  - `class FileTags { Set<AutofillField> writable; Map<AutofillField, Object?> values; Uint8List? cover; static const FileTags unwritable; }`.
  - `abstract interface class TagWriter { Future<FileTags> inspect(String path); Future<WriteOutcome> write(String path, Map<AutofillField, Object?> values, {required AudioFile expected}); }`.
  - `const Set<String> writableExtensions = {'.mp3', '.flac', '.m4a', '.mp4', '.wav', '.ape'}`, `bool canWriteTagsTo(String path)`.

- [ ] **Step 1: Write the failing tests**

`test/features/autofill/domain/autofill_field_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/autofill/domain/autofill_field.dart';

/// Which tags an autofill offers, and how the owner's last choice is kept.
void main() {
  test('GivenNothingStored_WhenTheChoiceIsRead_ThenEveryTagButTheCoverIsTicked', () {
    final fields = AutofillField.decode(null);

    expect(fields, AutofillField.defaults);
    expect(fields, isNot(contains(AutofillField.cover)));
    expect(fields, hasLength(AutofillField.values.length - 1));
  });

  test('GivenAChoiceWasStored_WhenItIsReadBack_ThenItIsTheSameChoice', () {
    const chosen = {AutofillField.artist, AutofillField.cover};

    expect(AutofillField.decode(AutofillField.encode(chosen)), chosen);
  });

  test('GivenAStoredNameThisVersionDoesNotKnow_WhenTheChoiceIsRead_ThenItIsIgnored', () {
    expect(AutofillField.decode('artist,mood'), {AutofillField.artist});
  });

  test('GivenAnEmptyStoredChoice_WhenItIsRead_ThenTheDefaultsAreOffered', () {
    // An empty choice is not one the dialog lets anybody confirm; one that
    // was stored anyway is treated as nothing stored.
    expect(AutofillField.decode(''), AutofillField.defaults);
  });
}
```

`test/features/autofill/domain/release_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/autofill/domain/release.dart';

/// What a release says about itself.
void main() {
  test('GivenACreditOfTwoArtists_WhenItIsNamed_ThenTheJoinPhrasesAreKept', () {
    const credits = [
      ArtistCredit(name: 'Queen', joinPhrase: ' & '),
      ArtistCredit(name: 'David Bowie'),
    ];

    expect(creditedName(credits), 'Queen & David Bowie');
  });

  test('GivenADateWithOnlyAYear_WhenTheYearIsAsked_ThenItIsThatYear', () {
    expect(_candidate(date: '1997').year, 1997);
    expect(_candidate(date: '1997-05-21').year, 1997);
    expect(_candidate(date: null).year, isNull);
    expect(_candidate(date: 'soon').year, isNull);
  });

  test('GivenATwoDiscRelease_WhenItsShapeIsAsked_ThenEachDiscCountsItsOwnTracks', () {
    final detail = ReleaseDetail(
      release: _candidate(),
      tracks: [
        _track(disc: 1, position: 1),
        _track(disc: 1, position: 2),
        _track(disc: 2, position: 1),
      ],
    );

    expect(detail.discCount, 2);
    expect(detail.tracksOnDisc(1), 2);
    expect(detail.tracksOnDisc(2), 1);
  });
}

ReleaseCandidate _candidate({String? date = '1997'}) => ReleaseCandidate(
  id: 'r1',
  title: 'OK Computer',
  artistCredit: const [ArtistCredit(name: 'Radiohead')],
  date: date,
  trackCount: 12,
);

ReleaseTrack _track({required int disc, required int position}) => ReleaseTrack(
  disc: disc,
  position: position,
  title: 'Track $position',
  artistCredit: const [ArtistCredit(name: 'Radiohead')],
);
```

`test/features/autofill/domain/tag_writer_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/autofill/domain/tag_writer.dart';

/// Which files an autofill may write to at all.
void main() {
  test('GivenAFormatTheWriterHandles_WhenItIsAsked_ThenItMayBeWritten', () {
    for (final path in ['/m/a.mp3', '/m/b.FLAC', '/m/c.m4a', '/m/d.wav', '/m/e.ape']) {
      expect(canWriteTagsTo(path), isTrue, reason: path);
    }
  });

  test('GivenAFormatTheWriterCannotWrite_WhenItIsAsked_ThenItMayNotBeWritten', () {
    for (final path in ['/m/a.ogg', '/m/b.opus', '/m/c.aiff', '/m/d.mka', '/m/e']) {
      expect(canWriteTagsTo(path), isFalse, reason: path);
    }
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/autofill/domain`
Expected: compilation errors — the libraries do not exist.

- [ ] **Step 3: Write the implementation**

`lib/features/autofill/domain/autofill_field.dart`:

```dart
/// A tag an autofill can fill.
///
/// The owner ticks which of these an autofill may change, and the choice is
/// remembered for the next one — see [encode] and [decode].
enum AutofillField {
  /// The track's title.
  title,

  /// The track's artist.
  artist,

  /// The record's own artist, which is what a compilation's "Various Artists"
  /// lives in.
  albumArtist,

  /// The record's title.
  album,

  /// The track's position on its disc.
  trackNumber,

  /// How many tracks its disc has.
  trackTotal,

  /// Which disc of the record it is on.
  discNumber,

  /// How many discs the record has.
  discTotal,

  /// The year of the release.
  year,

  /// The record's genre.
  genre,

  /// The front cover, embedded in the file.
  cover;

  /// What an owner who has never chosen is offered: everything but the cover.
  ///
  /// The cover is the one choice that reaches a second service, downloads a
  /// picture and makes every file it is written into larger by that picture,
  /// so it is something to ask for rather than something to get.
  static const Set<AutofillField> defaults = {
    title,
    artist,
    albumArtist,
    album,
    trackNumber,
    trackTotal,
    discNumber,
    discTotal,
    year,
    genre,
  };

  /// [fields] as one string for the settings store.
  static String encode(Set<AutofillField> fields) =>
      [for (final field in values) if (fields.contains(field)) field.name]
          .join(',');

  /// The choice [stored] as [encode] wrote it, or [defaults] where there is
  /// none worth using.
  ///
  /// A name this version does not know — written by a later one — is skipped
  /// rather than failing the read.
  static Set<AutofillField> decode(String? stored) {
    if (stored == null) return defaults;

    final names = stored.split(',').toSet();
    final fields = {
      for (final field in values) if (names.contains(field.name)) field,
    };

    return fields.isEmpty ? defaults : fields;
  }
}
```

`lib/features/autofill/domain/release.dart`:

```dart
/// One name in a credit, and what joins it to the next.
///
/// MusicBrainz credits a track to "Queen & David Bowie" as two artists and a
/// join phrase, and the phrase is part of how the credit reads.
class ArtistCredit {
  /// Creates a credit.
  const ArtistCredit({required this.name, this.joinPhrase = ''});

  /// The name as credited here.
  final String name;

  /// What follows it before the next name, or nothing for the last.
  final String joinPhrase;
}

/// [credits] as one line, the way MusicBrainz writes it.
String creditedName(List<ArtistCredit> credits) =>
    credits.map((credit) => '${credit.name}${credit.joinPhrase}').join().trim();

/// A release as a search answers it — enough to rank it and to show it, not
/// yet its tracks.
class ReleaseCandidate {
  /// Creates a candidate.
  const ReleaseCandidate({
    required this.id,
    required this.title,
    required this.artistCredit,
    required this.trackCount,
    this.date,
    this.country,
    this.status,
    this.primaryType,
    this.secondaryTypes = const [],
    this.format,
    this.disambiguation,
    this.score = 0,
  });

  /// Its MusicBrainz id.
  final String id;

  /// Its title.
  final String title;

  /// Who it is credited to.
  final List<ArtistCredit> artistCredit;

  /// How many tracks it has, across every disc.
  final int trackCount;

  /// When it was released, as MusicBrainz writes it: `1997`, `1997-05` or
  /// `1997-05-21`.
  final String? date;

  /// Where it was released.
  final String? country;

  /// `Official`, `Promotion`, `Bootleg` or `Pseudo-Release`.
  final String? status;

  /// `Album`, `Single`, `EP`, `Broadcast` or `Other`.
  final String? primaryType;

  /// `Compilation`, `Live`, `Remix` and the like.
  final List<String> secondaryTypes;

  /// The first medium's format: `CD`, `Digital Media`, `12" Vinyl`…
  final String? format;

  /// What tells it apart from releases of the same name: "2011 remaster".
  final String? disambiguation;

  /// How well the search thinks it matched, 0 to 100.
  final int score;

  /// Who it is credited to, as one line.
  String get artist => creditedName(artistCredit);

  /// The year of [date], or `null` where there is none to read.
  int? get year {
    final value = date;
    if (value == null || value.length < 4) return null;

    return int.tryParse(value.substring(0, 4));
  }
}

/// One track of a release.
class ReleaseTrack {
  /// Creates a track.
  const ReleaseTrack({
    required this.disc,
    required this.position,
    required this.title,
    required this.artistCredit,
    this.length,
    this.recordingId,
  });

  /// Which disc it is on, from 1.
  final int disc;

  /// Where on that disc, from 1.
  final int position;

  /// Its title on this release.
  final String title;

  /// Who it is credited to on this release.
  final List<ArtistCredit> artistCredit;

  /// How long it is, where MusicBrainz knows.
  final Duration? length;

  /// The recording it is, which is what a lone track was matched by.
  final String? recordingId;

  /// Who it is credited to, as one line.
  String get artist => creditedName(artistCredit);
}

/// A genre and how many people voted for it.
class Genre {
  /// Creates a genre.
  const Genre({required this.name, this.votes = 0});

  /// Its name, as MusicBrainz spells it: lower case.
  final String name;

  /// How many votes it has.
  final int votes;
}

/// A release in full: its tracks and its genres.
class ReleaseDetail {
  /// Creates the detail.
  const ReleaseDetail({
    required this.release,
    required this.tracks,
    this.genres = const [],
    this.releaseGroupId,
  });

  /// The release itself.
  final ReleaseCandidate release;

  /// Every track, disc by disc, in order.
  final List<ReleaseTrack> tracks;

  /// Its genres, most voted first.
  final List<Genre> genres;

  /// The release group it belongs to, whose genres stand in where it has none.
  final String? releaseGroupId;

  /// How many discs it has.
  int get discCount => tracks.isEmpty
      ? 1
      : tracks.map((track) => track.disc).reduce((a, b) => a > b ? a : b);

  /// How many tracks disc [disc] has.
  int tracksOnDisc(int disc) =>
      tracks.where((track) => track.disc == disc).length;
}

/// Where a recording appears: a release, and its place on it.
class RecordingAppearance {
  /// Creates an appearance.
  const RecordingAppearance({
    required this.release,
    required this.disc,
    required this.position,
  });

  /// The release.
  final ReleaseCandidate release;

  /// The disc it is on.
  final int disc;

  /// Its place on that disc.
  final int position;
}

/// A recording a lone track was matched to.
class RecordingMatch {
  /// Creates a match.
  const RecordingMatch({
    required this.recordingId,
    required this.title,
    required this.artistCredit,
    required this.appearances,
    this.length,
    this.score = 0,
  });

  /// Its MusicBrainz id.
  final String recordingId;

  /// Its title.
  final String title;

  /// Who it is credited to.
  final List<ArtistCredit> artistCredit;

  /// Every release it appears on.
  final List<RecordingAppearance> appearances;

  /// How long it is, where known.
  final Duration? length;

  /// How well the search thinks it matched, 0 to 100.
  final int score;
}
```

`lib/features/autofill/domain/metadata_source.dart`:

```dart
import 'dart:typed_data';

import 'release.dart';

/// What to look a record up by.
class ReleaseQuery {
  /// Creates a query.
  const ReleaseQuery({this.album, this.artist, this.text});

  /// The record's title.
  final String? album;

  /// The record's artist.
  final String? artist;

  /// The owner's own words, which replace the two fields above when given.
  final String? text;
}

/// What to look a lone track up by.
class RecordingQuery {
  /// Creates a query.
  const RecordingQuery({this.title, this.artist, this.duration, this.text});

  /// The track's title.
  final String? title;

  /// The track's artist.
  final String? artist;

  /// How long the file is, which narrows the search to recordings of about
  /// that length.
  final Duration? duration;

  /// The owner's own words, which replace the fields above when given.
  final String? text;
}

/// Why a lookup could not run.
enum MetadataSourceFailure {
  /// No network, a timeout, or the service answering with an error.
  unreachable,

  /// The service asked for fewer requests, and kept asking.
  rateLimited,

  /// The service answered with something that could not be read.
  malformed,
}

/// A lookup that could not run.
class MetadataSourceException implements Exception {
  /// Creates the exception.
  const MetadataSourceException(this.kind);

  /// Why.
  final MetadataSourceFailure kind;

  @override
  String toString() => 'MetadataSourceException(${kind.name})';
}

/// Where proposed tags come from.
///
/// An interface for the usual reason — nothing in the suite reaches a network
/// — and for one more: identifying a file by its sound would be a second
/// implementation of this, not a change to anything that uses it.
abstract interface class MetadataSource {
  /// Releases that match [query], at most ten, in the service's own order.
  Future<List<ReleaseCandidate>> searchReleases(ReleaseQuery query);

  /// The release [id] in full.
  Future<ReleaseDetail> release(String id);

  /// The genres of the release group [id], most voted first.
  Future<List<Genre>> releaseGroupGenres(String id);

  /// Recordings that match [query], at most ten.
  Future<List<RecordingMatch>> searchRecordings(RecordingQuery query);

  /// The front cover of release [releaseId], or `null` where it has none.
  Future<Uint8List?> frontCover(String releaseId);
}
```

`lib/features/autofill/domain/tag_writer.dart`:

```dart
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../../library/domain/audio_file.dart';
import 'autofill_field.dart';

/// The extensions of the formats tags can be written to.
///
/// What `audio_metadata_reader` can write, and nothing it can only read: an
/// Ogg or Opus file is in the library and plays, and has its tags left alone.
const Set<String> writableExtensions = {
  '.mp3',
  '.flac',
  '.m4a',
  '.mp4',
  '.wav',
  '.ape',
};

/// Whether tags can be written to the file at [path] at all.
bool canWriteTagsTo(String path) =>
    writableExtensions.contains(p.extension(path).toLowerCase());

/// What a file's own tags say, and which of them can be written.
///
/// Read from the file rather than from the catalog: the catalog's album artist
/// is partly worked out across the record, and what a change is measured
/// against has to be what the file actually holds.
class FileTags {
  /// Creates the tags.
  const FileTags({
    required this.writable,
    this.values = const {},
    this.cover,
  });

  /// A file nothing can be written to.
  static const FileTags unwritable = FileTags(writable: {});

  /// The fields this file's format can hold and the writer can write.
  final Set<AutofillField> writable;

  /// The current value of each field the file has: a `String` for the
  /// text fields, an `int` for the numbers and the year.
  final Map<AutofillField, Object?> values;

  /// The embedded front cover, where there is one.
  final Uint8List? cover;
}

/// What became of one file's write.
enum WriteOutcome {
  /// Written.
  written,

  /// Its format cannot be written.
  unsupported,

  /// It is not the file it was when it was read — another program wrote to
  /// it since — so it was left alone rather than overwritten.
  changedSinceRead,

  /// Another program holds it open and the system would not let it be
  /// replaced. On Windows, the track playing.
  inUse,

  /// This process may not write it.
  denied,

  /// Anything else.
  failed,
}

/// Reads and writes a file's tags.
abstract interface class TagWriter {
  /// The tags of the file at [path], and which can be written.
  Future<FileTags> inspect(String path);

  /// Writes [values] into the file at [path], leaving every other tag in it as
  /// it was.
  ///
  /// [expected] is the file as the catalog knows it. A file whose size or
  /// timestamp differs is answered [WriteOutcome.changedSinceRead] and not
  /// touched. A `null` value removes the tag.
  Future<WriteOutcome> write(
    String path,
    Map<AutofillField, Object?> values, {
    required AudioFile expected,
  });
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/features/autofill/domain` then `flutter analyze`
Expected: all pass; no analyzer issues.

- [ ] **Step 5: Commit**

```bash
git add lib/features/autofill/domain test/features/autofill/domain
git commit -m "feat: add the autofill domain types"
```

---

### Task 2: Normalising names and ranking candidates

**Files:**
- Create: `lib/features/autofill/domain/matching.dart`
- Test: `test/features/autofill/domain/matching_test.dart`

**Interfaces:**
- Consumes: Task 1's `ReleaseCandidate`, `RecordingMatch`, `RecordingAppearance`, `ReleaseQuery`, `RecordingQuery`; `MusicEntry` (`lib/features/library/domain/music_entry.dart`).
- Produces:
  - `String normalised(String value)` — lower case, accents folded, punctuation dropped, whitespace collapsed.
  - `List<ReleaseCandidate> rankCandidates(List<ReleaseCandidate> candidates, {required int fileCount, String? album, String? artist})`.
  - `List<RecordingAppearance> rankAppearances(List<RecordingMatch> matches, {String? title, String? artist})` — every appearance of every match, best first.
  - `ReleaseQuery releaseQueryFor(List<MusicEntry> entries)`, `RecordingQuery recordingQueryFor(MusicEntry entry)`.

- [ ] **Step 1: Write the failing tests**

`test/features/autofill/domain/matching_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/autofill/domain/matching.dart';
import 'package:orpheus/features/autofill/domain/release.dart';

import '../../../support/entries.dart';

/// Choosing between what MusicBrainz offers.
void main() {
  group('normalised', () {
    test('GivenNamesThatDifferOnlyInCaseAccentsAndPunctuation_WhenNormalised_ThenTheyAreEqual', () {
      expect(normalised('Sigur Rós'), normalised('sigur ros'));
      expect(normalised('OK Computer!'), normalised('ok   computer'));
      expect(normalised('Don’t Stop'), normalised("Don't stop"));
    });
  });

  group('rankCandidates', () {
    ReleaseCandidate candidate(
      String id, {
      String title = 'OK Computer',
      String artist = 'Radiohead',
      int trackCount = 12,
      String status = 'Official',
      int score = 100,
      String? date = '1997-05-21',
    }) => ReleaseCandidate(
      id: id,
      title: title,
      artistCredit: [ArtistCredit(name: artist)],
      trackCount: trackCount,
      status: status,
      score: score,
      date: date,
    );

    List<String> ranked(List<ReleaseCandidate> candidates, {int files = 12}) => [
      for (final c in rankCandidates(
        candidates,
        fileCount: files,
        album: 'OK Computer',
        artist: 'Radiohead',
      ))
        c.id,
    ];

    test('GivenAReleaseWithBonusTracks_WhenRanked_ThenTheOneWithAsManyTracksAsFilesComesFirst', () {
      expect(
        ranked([candidate('deluxe', trackCount: 24), candidate('original')]),
        ['original', 'deluxe'],
      );
    });

    test('GivenABootlegAndAnOfficialRelease_WhenRanked_ThenTheOfficialOneComesFirst', () {
      expect(
        ranked([candidate('boot', status: 'Bootleg'), candidate('official')]),
        ['official', 'boot'],
      );
    });

    test('GivenATitleThatOnlyContainsTheAlbum_WhenRanked_ThenTheExactTitleComesFirst', () {
      expect(
        ranked([candidate('tribute', title: 'OK Computer Tribute'), candidate('exact')]),
        ['exact', 'tribute'],
      );
    });

    test('GivenOtherwiseEqualCandidates_WhenRanked_ThenTheEarliestComesFirstEveryTime', () {
      final order = ranked([
        candidate('b', date: '2009'),
        candidate('a', date: '1997'),
        candidate('c', date: null),
      ]);

      expect(order, ['a', 'b', 'c']);
    });
  });

  group('rankAppearances', () {
    ReleaseCandidate release(String id, {String type = 'Album', List<String> secondary = const [], String date = '2000'}) =>
        ReleaseCandidate(
          id: id,
          title: id,
          artistCredit: const [ArtistCredit(name: 'A')],
          trackCount: 10,
          status: 'Official',
          primaryType: type,
          secondaryTypes: secondary,
          date: date,
        );

    test('GivenARecordingOnASingleACompilationAndAnAlbum_WhenRanked_ThenTheAlbumComesFirstAndTheCompilationLast', () {
      final match = RecordingMatch(
        recordingId: 'rec',
        title: 'Song',
        artistCredit: const [ArtistCredit(name: 'A')],
        appearances: [
          RecordingAppearance(release: release('best of', secondary: ['Compilation']), disc: 1, position: 3),
          RecordingAppearance(release: release('single', type: 'Single'), disc: 1, position: 1),
          RecordingAppearance(release: release('album'), disc: 1, position: 5),
        ],
      );

      expect(
        [for (final a in rankAppearances([match], title: 'Song', artist: 'A')) a.release.id],
        ['album', 'single', 'best of'],
      );
    });
  });

  group('queries', () {
    test('GivenARecordTaggedMostlyOneWay_WhenItsQueryIsBuilt_ThenTheCommonestValuesAreUsed', () {
      final entries = [
        entry(id: '1', title: 'A', artist: 'Radiohead', album: 'OK Computer'),
        entry(id: '2', title: 'B', artist: 'Radiohead', album: 'OK Computer'),
        entry(id: '3', title: 'C', artist: 'Radiohed', album: 'Ok Computer'),
      ];

      final query = releaseQueryFor(entries);

      expect(query.album, 'OK Computer');
      expect(query.artist, 'Radiohead');
    });

    test('GivenARecordWithNoAlbumTag_WhenItsQueryIsBuilt_ThenTheFolderNameStandsIn', () {
      final entries = [entry(id: '1', title: 'A', directory: '/music/Kid A')];

      expect(releaseQueryFor(entries).album, 'Kid A');
    });

    test('GivenAnUntitledTrack_WhenItsQueryIsBuilt_ThenItsFileNameWithoutTheNumberStandsIn', () {
      final untitled = MusicEntry(
        file: AudioFile(
          path: '/music/OK Computer/03 - Lucky.flac',
          sizeInBytes: 1,
          modifiedAt: DateTime.utc(2026),
        ),
        metadata: TrackMetadata.empty,
      );

      expect(recordingQueryFor(untitled).title, 'Lucky');
    });
  });
}
```

Add to the test's imports: `package:orpheus/features/library/domain/audio_file.dart`, `.../music_entry.dart` and `.../track_metadata.dart`. Open `test/support/entries.dart` first and confirm `entry(...)` takes `id`, `title`, `artist`, `album` and `directory`.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/autofill/domain/matching_test.dart`
Expected: compilation error — `matching.dart` does not exist.

- [ ] **Step 3: Write the implementation**

`lib/features/autofill/domain/matching.dart`:

```dart
import 'package:path/path.dart' as p;

import '../../library/domain/music_entry.dart';
import 'metadata_source.dart';
import 'release.dart';

/// [value] reduced to what two spellings of one name have in common.
///
/// Lower case, accents folded to their letters, typographic quotes and every
/// other piece of punctuation dropped, and runs of space collapsed: `Sigur
/// Rós` and `sigur ros` are one band, and `Don’t` and `Don't` one song.
String normalised(String value) {
  final folded = StringBuffer();
  for (final rune in value.toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    folded.write(_folds[char] ?? char);
  }

  return folded
      .toString()
      .replaceAll(RegExp(r"[^\p{L}\p{N}\s]", unicode: true), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

const Map<String, String> _folds = {
  'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a',
  'ç': 'c',
  'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
  'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
  'ñ': 'n',
  'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', 'ø': 'o',
  'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u',
  'ý': 'y', 'ÿ': 'y',
};

/// How closely [candidate] matches [wanted]: 2 equal, 1 one contains the
/// other, 0 neither — and 0 where nothing was wanted.
int _closeness(String? wanted, String candidate) {
  if (wanted == null || wanted.trim().isEmpty) return 0;

  final a = normalised(wanted);
  final b = normalised(candidate);
  if (a == b) return 2;
  if (a.isNotEmpty && b.isNotEmpty && (a.contains(b) || b.contains(a))) {
    return 1;
  }

  return 0;
}

int _statusRank(String? status) => switch (status?.toLowerCase()) {
  'official' => 0,
  'promotion' => 1,
  null => 2,
  _ => 3,
};

/// [candidates] best first, by what the search already said about them.
///
/// The order the spec gives, each key breaking the previous one's ties:
/// as many tracks as the owner has files, then an official release, then the
/// title, then the artist, then the service's own score, then the earliest
/// date, then the id — so the same answer always ranks the same way.
List<ReleaseCandidate> rankCandidates(
  List<ReleaseCandidate> candidates, {
  required int fileCount,
  String? album,
  String? artist,
}) {
  int compare(ReleaseCandidate a, ReleaseCandidate b) {
    final byCount = (b.trackCount == fileCount ? 1 : 0)
        .compareTo(a.trackCount == fileCount ? 1 : 0);
    if (byCount != 0) return byCount;

    final byStatus = _statusRank(a.status).compareTo(_statusRank(b.status));
    if (byStatus != 0) return byStatus;

    final byTitle = _closeness(album, b.title).compareTo(_closeness(album, a.title));
    if (byTitle != 0) return byTitle;

    final byArtist = _closeness(artist, b.artist).compareTo(_closeness(artist, a.artist));
    if (byArtist != 0) return byArtist;

    final byScore = b.score.compareTo(a.score);
    if (byScore != 0) return byScore;

    final byDate = (a.date ?? '9999').compareTo(b.date ?? '9999');
    if (byDate != 0) return byDate;

    return a.id.compareTo(b.id);
  }

  return [...candidates]..sort(compare);
}

int _typeRank(ReleaseCandidate release) {
  if (release.secondaryTypes.any((type) => type.toLowerCase() == 'compilation')) {
    return 3;
  }

  return switch (release.primaryType?.toLowerCase()) {
    'album' => 0,
    'ep' => 1,
    'single' => 2,
    _ => 2,
  };
}

/// Every place the recordings in [matches] appear, best first.
///
/// For a lone track the question is which record to file it under, and the
/// answer an owner expects is the album it was released on: an official
/// album before an EP or a single, a compilation last, and the earliest of
/// equals.
List<RecordingAppearance> rankAppearances(
  List<RecordingMatch> matches, {
  String? title,
  String? artist,
}) {
  final scored = [
    for (final match in matches)
      for (final appearance in match.appearances)
        (match: match, appearance: appearance),
  ];

  scored.sort((a, b) {
    final byTitle = _closeness(title, b.match.title)
        .compareTo(_closeness(title, a.match.title));
    if (byTitle != 0) return byTitle;

    final byArtist = _closeness(artist, creditedName(b.match.artistCredit))
        .compareTo(_closeness(artist, creditedName(a.match.artistCredit)));
    if (byArtist != 0) return byArtist;

    final byStatus = _statusRank(a.appearance.release.status)
        .compareTo(_statusRank(b.appearance.release.status));
    if (byStatus != 0) return byStatus;

    final byType = _typeRank(a.appearance.release)
        .compareTo(_typeRank(b.appearance.release));
    if (byType != 0) return byType;

    final byDate = (a.appearance.release.date ?? '9999')
        .compareTo(b.appearance.release.date ?? '9999');
    if (byDate != 0) return byDate;

    return a.appearance.release.id.compareTo(b.appearance.release.id);
  });

  return [for (final item in scored) item.appearance];
}

/// The commonest non-blank value among [values], or `null` for none.
String? _commonest(Iterable<String?> values) {
  final counts = <String, int>{};
  for (final value in values) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) continue;
    counts.update(trimmed, (count) => count + 1, ifAbsent: () => 1);
  }
  if (counts.isEmpty) return null;

  final ranked = counts.entries.toList()
    ..sort((a, b) {
      final byCount = b.value.compareTo(a.value);
      return byCount != 0 ? byCount : a.key.compareTo(b.key);
    });

  return ranked.first.key;
}

/// What to search for a record made of [entries] by.
///
/// The commonest album and album artist across them, so one mis-tagged track
/// does not steer the search; the folder's name where nothing is tagged.
ReleaseQuery releaseQueryFor(List<MusicEntry> entries) => ReleaseQuery(
  album:
      _commonest(entries.map((entry) => entry.album)) ??
      _commonest(entries.map((entry) => p.basename(entry.file.directory))),
  artist: _commonest(entries.map((entry) => entry.albumArtist)),
);

/// What to search for the lone track [entry] by.
///
/// Its title, or its file name without the extension and any leading track
/// number (`03 - Lucky.flac` → `Lucky`) where it has none.
RecordingQuery recordingQueryFor(MusicEntry entry) => RecordingQuery(
  title:
      entry.title ??
      p
          .basenameWithoutExtension(entry.file.path)
          .replaceFirst(RegExp(r'^\s*\d+\s*[-._)\]]*\s*'), '')
          .trim(),
  artist: entry.artist,
  duration: entry.duration,
);
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/features/autofill/domain/matching_test.dart` then `flutter analyze`
Expected: all pass, analyzer clean.

- [ ] **Step 5: Commit**

```bash
git add lib/features/autofill/domain/matching.dart test/features/autofill/domain/matching_test.dart
git commit -m "feat: rank musicbrainz candidates for a record"
```

---

### Task 3: Assigning files to a release's tracks

**Files:**
- Modify: `lib/features/autofill/domain/matching.dart` (append)
- Test: `test/features/autofill/domain/matching_test.dart` (append a group)

**Interfaces:**
- Consumes: Task 1's `ReleaseDetail`, `ReleaseTrack`; Task 2's `normalised`.
- Produces: `Map<MusicEntry, ReleaseTrack?> assignTracks(List<MusicEntry> files, ReleaseDetail release)` — every file is a key; `null` means no match. Iteration order of the map is the order of `files`.

- [ ] **Step 1: Write the failing tests** — append to `matching_test.dart` inside `main()`:

```dart
  group('assignTracks', () {
    ReleaseTrack track(int disc, int position, String title, {int seconds = 200}) =>
        ReleaseTrack(
          disc: disc,
          position: position,
          title: title,
          artistCredit: const [ArtistCredit(name: 'Radiohead')],
          length: Duration(seconds: seconds),
        );

    ReleaseDetail releaseOf(List<ReleaseTrack> tracks) => ReleaseDetail(
      release: const ReleaseCandidate(
        id: 'r',
        title: 'OK Computer',
        artistCredit: [ArtistCredit(name: 'Radiohead')],
        trackCount: 3,
      ),
      tracks: tracks,
    );

    test('GivenFilesNumberedLikeTheRelease_WhenAssigned_ThenEachGetsItsNumbersTrack', () {
      // No titles: the numbers are the only evidence, and they are enough.
      final files = [entry(id: '1', track: 1), entry(id: '2', track: 2)];
      final release = releaseOf([track(1, 1, 'Airbag'), track(1, 2, 'Paranoid Android')]);

      final assigned = assignTracks(files, release);

      expect(assigned[files[0]]?.title, 'Airbag');
      expect(assigned[files[1]]?.title, 'Paranoid Android');
    });

    test('GivenUnnumberedFiles_WhenAssigned_ThenTheyAreMatchedByTitle', () {
      final files = [entry(id: '1', title: 'paranoid android'), entry(id: '2', title: 'AIRBAG')];
      final release = releaseOf([track(1, 1, 'Airbag'), track(1, 2, 'Paranoid Android')]);

      final assigned = assignTracks(files, release);

      expect(assigned[files[0]]?.position, 2);
      expect(assigned[files[1]]?.position, 1);
    });

    test('GivenTwoFilesTaggedTrackOneWithNoDisc_WhenAssignedToATwoDiscRelease_ThenTheSecondFallsThroughToItsTitle', () {
      // Review focus: the second "track 1" must not take the first's track.
      final files = [
        entry(id: 'a', title: 'Opening', track: 1),
        entry(id: 'b', title: 'Second Opening', track: 1),
      ];
      final release = releaseOf([track(1, 1, 'Opening'), track(2, 1, 'Second Opening')]);

      final assigned = assignTracks(files, release);

      expect(assigned[files[0]]?.disc, 1);
      expect(assigned[files[1]]?.disc, 2);
    });

    test('GivenAFileTheReleaseDoesNotHave_WhenAssigned_ThenItHasNoMatchAndTheOthersAreUnaffected', () {
      // Review focus: extra files are no match; extra release tracks ignored.
      final files = [
        entry(id: '1', title: 'Airbag', track: 1),
        entry(id: 'x', title: 'A Hidden Demo', track: 13),
      ];
      final release = releaseOf([
        track(1, 1, 'Airbag'),
        track(1, 2, 'Paranoid Android'),
        track(1, 3, 'Subterranean Homesick Alien'),
      ]);

      final assigned = assignTracks(files, release);

      expect(assigned[files[0]]?.title, 'Airbag');
      expect(assigned.containsKey(files[1]), isTrue);
      expect(assigned[files[1]], isNull);
    });

    test('GivenAnUntitledUnnumberedFile_WhenItsLengthSinglesOutATrack_ThenItIsAssignedThatTrack', () {
      final files = [entry(id: 'u', duration: const Duration(seconds: 387))];
      final release = releaseOf([track(1, 1, 'Airbag', seconds: 284), track(1, 2, 'Paranoid Android', seconds: 386)]);

      expect(assignTracks(files, release)[files[0]]?.title, 'Paranoid Android');
    });
  });
```

Check `test/support/entries.dart` before running: if `entry(...)` has no `track`, `disc` or `duration` parameter, add them there (each forwarded into `TrackMetadata`, defaulting to `null`) — every other test keeps working because the defaults are unchanged.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/autofill/domain/matching_test.dart`
Expected: compilation error — `assignTracks` is not defined.

- [ ] **Step 3: Write the implementation** — append to `matching.dart` (add `import 'release.dart';` is already there):

```dart
/// Which of [release]'s tracks each of [files] is.
///
/// Four passes, each over what the ones before left unassigned, from the
/// surest evidence to the weakest: disc and track number (a missing disc
/// counting as the first, as the library orders it); the title exactly, once
/// normalised; a similar title and a length within five seconds; and a length
/// within two seconds where it singles out exactly one track. A track is
/// given out once. A file left at the end has no match on this release, and
/// tracks nobody claimed — bonus tracks the owner does not have — are simply
/// not used.
Map<MusicEntry, ReleaseTrack?> assignTracks(
  List<MusicEntry> files,
  ReleaseDetail release,
) {
  final assigned = <MusicEntry, ReleaseTrack?>{for (final file in files) file: null};
  final free = [...release.tracks];

  void claim(MusicEntry file, ReleaseTrack track) {
    assigned[file] = track;
    free.remove(track);
  }

  Iterable<MusicEntry> open() => files.where((file) => assigned[file] == null);

  // 1. Numbers.
  for (final file in open().toList()) {
    final number = file.metadata.track;
    if (number == null) continue;
    final disc = file.metadata.disc ?? 1;
    final track = free
        .where((t) => t.disc == disc && t.position == number)
        .firstOrNull;
    // A disc-less file numbered like a track on a later disc is left for the
    // passes below rather than guessed into it.
    if (track != null && _titlesAgreeOrUnknown(file, track)) claim(file, track);
  }

  // 2. Titles, exactly.
  for (final file in open().toList()) {
    final title = file.title;
    if (title == null) continue;
    final track = free
        .where((t) => normalised(t.title) == normalised(title))
        .firstOrNull;
    if (track != null) claim(file, track);
  }

  // 3. Similar titles of about the same length.
  for (final file in open().toList()) {
    final title = file.title;
    if (title == null) continue;
    final track = free
        .where(
          (t) =>
              _overlap(title, t.title) >= 0.6 &&
              _lengthsWithin(file.duration, t.length, const Duration(seconds: 5)),
        )
        .firstOrNull;
    if (track != null) claim(file, track);
  }

  // 4. Length alone, where it is unambiguous.
  for (final file in open().toList()) {
    final near = free
        .where(
          (t) => _lengthsWithin(file.duration, t.length, const Duration(seconds: 2)),
        )
        .toList();
    if (near.length == 1) claim(file, near.single);
  }

  return assigned;
}

/// Whether a number match is trustworthy: either the file has no title, or
/// its title is not plainly a different track's.
///
/// What stops two disc-less "track 1"s from both landing on disc one: the
/// second one's title names the second disc's first track, so it is left for
/// the title pass to place.
bool _titlesAgreeOrUnknown(MusicEntry file, ReleaseTrack track) {
  final title = file.title;
  if (title == null) return true;

  return _overlap(title, track.title) >= 0.6 ||
      normalised(title) == normalised(track.title);
}

/// The share of words two titles have in common, 0 to 1.
double _overlap(String a, String b) {
  final left = normalised(a).split(' ').where((w) => w.isNotEmpty).toSet();
  final right = normalised(b).split(' ').where((w) => w.isNotEmpty).toSet();
  if (left.isEmpty || right.isEmpty) return 0;

  final shared = left.intersection(right).length;
  final larger = left.length > right.length ? left.length : right.length;

  return shared / larger;
}

bool _lengthsWithin(Duration? a, Duration? b, Duration tolerance) =>
    a != null && b != null && (a - b).abs() <= tolerance;
```

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/features/autofill/domain/matching_test.dart` then `flutter analyze`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add lib/features/autofill/domain/matching.dart test/features/autofill/domain/matching_test.dart test/support/entries.dart
git commit -m "feat: match a record's files to a release's tracks"
```

---

### Task 4: Proposing the changes

**Files:**
- Create: `lib/features/autofill/domain/proposals.dart`
- Test: `test/features/autofill/domain/proposals_test.dart`

**Interfaces:**
- Consumes: Tasks 1–3 (`AutofillField`, `ReleaseDetail`, `ReleaseTrack`, `Genre`, `FileTags`, `canWriteTagsTo`).
- Produces:
  - `class FieldChange { AutofillField field; Object? before; Object? after; bool accepted; FieldChange withAccepted(bool); }`
  - `enum ProposalBlock { unwritableFormat, noMatch }`
  - `class FileProposal { MusicEntry entry; ReleaseTrack? track; ProposalBlock? blockedBecause; List<FieldChange> changes; Set<AutofillField> notWritable; int get acceptedCount; FileProposal withChanges(List<FieldChange>); }`
  - `List<FileProposal> proposalsFor({required Map<MusicEntry, ReleaseTrack?> assignment, required ReleaseDetail release, required Set<AutofillField> fields, required Map<String, FileTags> tags, List<Genre> fallbackGenres = const [], Uint8List? cover})` — `tags` keyed by file path.

- [ ] **Step 1: Write the failing tests**

`test/features/autofill/domain/proposals_test.dart`:

```dart
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/autofill/domain/autofill_field.dart';
import 'package:orpheus/features/autofill/domain/proposals.dart';
import 'package:orpheus/features/autofill/domain/release.dart';
import 'package:orpheus/features/autofill/domain/tag_writer.dart';
import 'package:orpheus/features/library/domain/music_entry.dart';

import '../../../support/entries.dart';

/// Turning a match into the changes the owner is shown.
void main() {
  final airbag = entry(id: 'ok1', title: 'Airbag', artist: 'Radiohed', album: 'OK Computer', track: 1);

  const release = ReleaseDetail(
    release: ReleaseCandidate(
      id: 'r',
      title: 'OK Computer',
      artistCredit: [ArtistCredit(name: 'Radiohead')],
      trackCount: 2,
      date: '1997-05-21',
    ),
    tracks: [
      ReleaseTrack(disc: 1, position: 1, title: 'Airbag', artistCredit: [ArtistCredit(name: 'Radiohead')]),
      ReleaseTrack(disc: 1, position: 2, title: 'Paranoid Android', artistCredit: [ArtistCredit(name: 'Radiohead')]),
    ],
    genres: [Genre(name: 'alternative rock', votes: 9), Genre(name: 'art rock', votes: 4)],
  );

  FileTags tagsOf(Map<AutofillField, Object?> values, {Set<AutofillField>? writable, Uint8List? cover}) =>
      FileTags(writable: writable ?? AutofillField.values.toSet(), values: values, cover: cover);

  List<FileProposal> propose(
    Map<MusicEntry, ReleaseTrack?> assignment,
    Set<AutofillField> fields,
    Map<String, FileTags> tags, {
    Uint8List? cover,
    List<Genre> fallback = const [],
  }) => proposalsFor(
    assignment: assignment,
    release: release,
    fields: fields,
    tags: tags,
    cover: cover,
    fallbackGenres: fallback,
  );

  test('GivenAMisspeltArtist_WhenProposed_ThenOnlyTheArtistChangesAndItIsTicked', () {
    final proposals = propose(
      {airbag: release.tracks.first},
      {AutofillField.title, AutofillField.artist},
      {airbag.file.path: tagsOf({AutofillField.title: 'Airbag', AutofillField.artist: 'Radiohed'})},
    );

    final changes = proposals.single.changes;
    expect(changes, hasLength(1));
    expect(changes.single.field, AutofillField.artist);
    expect(changes.single.before, 'Radiohed');
    expect(changes.single.after, 'Radiohead');
    expect(changes.single.accepted, isTrue);
  });

  test('GivenValuesEqualButForSurroundingSpace_WhenProposed_ThenThereIsNoChange', () {
    // Review focus: whitespace is not a change; case is.
    final proposals = propose(
      {airbag: release.tracks.first},
      {AutofillField.artist},
      {airbag.file.path: tagsOf({AutofillField.artist: ' Radiohead '})},
    );
    expect(proposals.single.changes, isEmpty);

    final lower = propose(
      {airbag: release.tracks.first},
      {AutofillField.artist},
      {airbag.file.path: tagsOf({AutofillField.artist: 'radiohead'})},
    );
    expect(lower.single.changes.single.after, 'Radiohead');
  });

  test('GivenEveryField_WhenProposedForAnEmptyFile_ThenNumbersYearAndGenreComeFromTheRelease', () {
    final proposals = propose(
      {airbag: release.tracks[1]},
      AutofillField.defaults,
      {airbag.file.path: tagsOf({})},
    );

    final after = {for (final c in proposals.single.changes) c.field: c.after};
    expect(after[AutofillField.title], 'Paranoid Android');
    expect(after[AutofillField.albumArtist], 'Radiohead');
    expect(after[AutofillField.album], 'OK Computer');
    expect(after[AutofillField.trackNumber], 2);
    expect(after[AutofillField.trackTotal], 2);
    expect(after[AutofillField.discNumber], 1);
    expect(after[AutofillField.discTotal], 1);
    expect(after[AutofillField.year], 1997);
    expect(after[AutofillField.genre], 'alternative rock');
  });

  test('GivenAReleaseWithNoGenres_WhenProposed_ThenTheReleaseGroupsGenreStandsIn', () {
    const bare = ReleaseDetail(release: ReleaseCandidate(id: 'r', title: 'T', artistCredit: [], trackCount: 1), tracks: [
      ReleaseTrack(disc: 1, position: 1, title: 'Airbag', artistCredit: []),
    ]);

    final proposals = proposalsFor(
      assignment: {airbag: bare.tracks.single},
      release: bare,
      fields: {AutofillField.genre},
      tags: {airbag.file.path: tagsOf({})},
      fallbackGenres: const [Genre(name: 'rock', votes: 1)],
    );

    expect(proposals.single.changes.single.after, 'rock');
  });

  test('GivenAFieldTheFormatCannotHold_WhenProposed_ThenItIsNamedAsNotWritableAndNotProposed', () {
    final proposals = propose(
      {airbag: release.tracks.first},
      {AutofillField.albumArtist, AutofillField.artist},
      {
        airbag.file.path: tagsOf(
          {AutofillField.artist: 'Radiohed'},
          writable: AutofillField.values.toSet()..remove(AutofillField.albumArtist),
        ),
      },
    );

    expect([for (final c in proposals.single.changes) c.field], [AutofillField.artist]);
    expect(proposals.single.notWritable, {AutofillField.albumArtist});
  });

  test('GivenAnUnwritableFormat_WhenProposed_ThenTheFileIsBlockedWithNoChanges', () {
    final ogg = entry(id: 'song.ogg');
    final proposals = propose({ogg: release.tracks.first}, {AutofillField.title}, {ogg.file.path: FileTags.unwritable});

    expect(proposals.single.blockedBecause, ProposalBlock.unwritableFormat);
    expect(proposals.single.changes, isEmpty);
  });

  test('GivenAFileWithNoMatch_WhenProposed_ThenItIsBlockedAsNoMatch', () {
    final proposals = propose({airbag: null}, {AutofillField.title}, {airbag.file.path: tagsOf({})});

    expect(proposals.single.blockedBecause, ProposalBlock.noMatch);
  });

  test('GivenTheSameCoverIsAlreadyEmbedded_WhenProposed_ThenTheCoverIsNoChange', () {
    final picture = Uint8List.fromList([1, 2, 3]);

    final same = propose(
      {airbag: release.tracks.first},
      {AutofillField.cover},
      {airbag.file.path: tagsOf({}, cover: Uint8List.fromList([1, 2, 3]))},
      cover: picture,
    );
    expect(same.single.changes, isEmpty);

    final different = propose(
      {airbag: release.tracks.first},
      {AutofillField.cover},
      {airbag.file.path: tagsOf({})},
      cover: picture,
    );
    expect(different.single.changes.single.after, picture);
  });

  test('GivenAProposal_WhenAChangeIsUnticked_ThenTheAcceptedCountFalls', () {
    final proposal = propose(
      {airbag: release.tracks[1]},
      {AutofillField.title, AutofillField.artist},
      {airbag.file.path: tagsOf({AutofillField.title: 'Airbag', AutofillField.artist: 'Radiohed'})},
    ).single;

    final edited = proposal.withChanges([
      proposal.changes.first.withAccepted(false),
      ...proposal.changes.skip(1),
    ]);

    expect(proposal.acceptedCount, 2);
    expect(edited.acceptedCount, 1);
  });
}
```

The `entry(id: 'song.ogg')` call builds `zzz-song.ogg.flac` with the current helper. If `entries.dart` cannot build a non-FLAC path, construct that `MusicEntry` by hand with path `/test/music/song.ogg` instead.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/autofill/domain/proposals_test.dart`
Expected: compilation error — `proposals.dart` does not exist.

- [ ] **Step 3: Write the implementation**

`lib/features/autofill/domain/proposals.dart`:

```dart
import 'dart:typed_data';

import '../../library/domain/music_entry.dart';
import 'autofill_field.dart';
import 'release.dart';
import 'tag_writer.dart';

/// One tag's proposed change.
class FieldChange {
  /// Creates a change.
  const FieldChange({
    required this.field,
    required this.before,
    required this.after,
    this.accepted = true,
  });

  /// Which tag.
  final AutofillField field;

  /// What the file holds now, or `null` for nothing.
  final Object? before;

  /// What it would hold.
  final Object? after;

  /// Whether the owner has left it ticked.
  final bool accepted;

  /// This change, ticked or not.
  FieldChange withAccepted(bool accepted) =>
      FieldChange(field: field, before: before, after: after, accepted: accepted);
}

/// Why a file has nothing proposed for it.
enum ProposalBlock {
  /// Its format cannot be written.
  unwritableFormat,

  /// The release has no track it matched.
  noMatch,
}

/// Everything proposed for one file.
class FileProposal {
  /// Creates a proposal.
  const FileProposal({
    required this.entry,
    this.track,
    this.blockedBecause,
    this.changes = const [],
    this.notWritable = const {},
  });

  /// The file, as the library knows it.
  final MusicEntry entry;

  /// The release track it was matched to.
  final ReleaseTrack? track;

  /// Why nothing is proposed, where nothing is.
  final ProposalBlock? blockedBecause;

  /// The changes, in the order the fields are declared.
  final List<FieldChange> changes;

  /// Chosen fields this file's format cannot hold.
  final Set<AutofillField> notWritable;

  /// How many changes are ticked.
  int get acceptedCount => changes.where((change) => change.accepted).length;

  /// This proposal with [changes] in place of its own.
  FileProposal withChanges(List<FieldChange> changes) => FileProposal(
    entry: entry,
    track: track,
    blockedBecause: blockedBecause,
    changes: changes,
    notWritable: notWritable,
  );
}

/// The changes [release] proposes for every file in [assignment].
///
/// Only real changes are listed: a value equal to the current one once both
/// are trimmed is left out, so the screen shows nothing that would not change.
/// Case is not ignored — `radiohead` → `Radiohead` is a change an owner may
/// want. [tags] holds what each file says now, by path; [fallbackGenres] are
/// the release group's, used where the release has none; [cover] is the
/// release's front cover, where the owner chose it and one was found.
List<FileProposal> proposalsFor({
  required Map<MusicEntry, ReleaseTrack?> assignment,
  required ReleaseDetail release,
  required Set<AutofillField> fields,
  required Map<String, FileTags> tags,
  List<Genre> fallbackGenres = const [],
  Uint8List? cover,
}) {
  final genre = (release.genres.isNotEmpty ? release.genres : fallbackGenres)
      .firstOrNull
      ?.name;

  return [
    for (final MapEntry(key: entry, value: track) in assignment.entries)
      _proposalFor(
        entry,
        track,
        release: release,
        fields: fields,
        current: tags[entry.file.path] ?? FileTags.unwritable,
        genre: genre,
        cover: cover,
      ),
  ];
}

FileProposal _proposalFor(
  MusicEntry entry,
  ReleaseTrack? track, {
  required ReleaseDetail release,
  required Set<AutofillField> fields,
  required FileTags current,
  required String? genre,
  required Uint8List? cover,
}) {
  if (current.writable.isEmpty) {
    return FileProposal(entry: entry, track: track, blockedBecause: ProposalBlock.unwritableFormat);
  }
  if (track == null) {
    return FileProposal(entry: entry, blockedBecause: ProposalBlock.noMatch);
  }

  final proposed = <AutofillField, Object?>{
    AutofillField.title: track.title,
    AutofillField.artist: track.artist,
    AutofillField.albumArtist: release.release.artist,
    AutofillField.album: release.release.title,
    AutofillField.trackNumber: track.position,
    AutofillField.trackTotal: release.tracksOnDisc(track.disc),
    AutofillField.discNumber: track.disc,
    AutofillField.discTotal: release.discCount,
    AutofillField.year: release.release.year,
    AutofillField.genre: genre,
    AutofillField.cover: cover,
  };

  final changes = <FieldChange>[];
  final notWritable = <AutofillField>{};

  for (final field in AutofillField.values) {
    if (!fields.contains(field)) continue;
    if (!current.writable.contains(field)) {
      notWritable.add(field);
      continue;
    }

    final after = proposed[field];
    // Nothing to propose — no genre anywhere, no year, no cover — is not a
    // proposal to remove what the file has.
    if (after == null || (after is String && after.trim().isEmpty)) continue;

    final before = field == AutofillField.cover ? current.cover : current.values[field];
    if (_same(before, after)) continue;

    changes.add(FieldChange(field: field, before: before, after: after));
  }

  return FileProposal(entry: entry, track: track, changes: changes, notWritable: notWritable);
}

bool _same(Object? before, Object? after) {
  if (before is String && after is String) return before.trim() == after.trim();
  if (before is Uint8List && after is Uint8List) {
    if (before.length != after.length) return false;
    for (var i = 0; i < before.length; i++) {
      if (before[i] != after[i]) return false;
    }

    return true;
  }

  return before == after;
}
```

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/features/autofill/domain` then `flutter analyze`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add lib/features/autofill/domain/proposals.dart test/features/autofill/domain/proposals_test.dart
git commit -m "feat: propose tag changes from a matched release"
```

---

### Task 5: MusicBrainz — queries and parsing

**Files:**
- Create: `lib/features/autofill/data/musicbrainz_source.dart`
- Test: `test/features/autofill/data/musicbrainz_source_test.dart`, `test/support/musicbrainz_fixtures.dart`

**Interfaces:**
- Consumes: Task 1's domain types.
- Produces: `class MusicBrainzSource implements MetadataSource { MusicBrainzSource({http.Client? client, String? version, Duration spacing = const Duration(seconds: 1), Duration retryAfter = const Duration(seconds: 2), Duration timeout = const Duration(seconds: 15), Future<void> Function(Duration)? wait, DateTime Function()? clock}); void close(); static String userAgentFor(String? version); static String escape(String term); }`.

- [ ] **Step 1: Write the fixtures** — `test/support/musicbrainz_fixtures.dart`, shaped exactly like MusicBrainz's JSON (trimmed to the fields read):

```dart
/// MusicBrainz answers, as the service shapes them, trimmed to the fields
/// this application reads. Invented ids; real field names.
library;

/// `GET release?query=…`
const Map<String, Object?> releaseSearch = {
  'count': 2,
  'releases': [
    {
      'id': 'rel-1',
      'score': 100,
      'title': 'OK Computer',
      'status': 'Official',
      'date': '1997-05-21',
      'country': 'GB',
      'disambiguation': '',
      'track-count': 12,
      'artist-credit': [
        {'name': 'Radiohead', 'joinphrase': '', 'artist': {'id': 'a1', 'name': 'Radiohead'}},
      ],
      'release-group': {'id': 'rg-1', 'primary-type': 'Album', 'secondary-types': <String>[]},
      'media': [
        {'format': 'CD', 'track-count': 12},
      ],
    },
    {
      'id': 'rel-2',
      'score': 92,
      'title': 'OK Computer OKNOTOK 1997 2017',
      'status': 'Official',
      'date': '2017-06-23',
      'country': 'XW',
      'disambiguation': 'remaster',
      'track-count': 23,
      'artist-credit': [
        {'name': 'Radiohead', 'joinphrase': ''},
      ],
      'release-group': {'id': 'rg-2', 'primary-type': 'Album'},
      'media': [
        {'format': 'Digital Media', 'track-count': 23},
      ],
    },
  ],
};

/// `GET release/rel-1?inc=recordings+artist-credits+genres+release-groups+media`
const Map<String, Object?> releaseLookup = {
  'id': 'rel-1',
  'title': 'OK Computer',
  'status': 'Official',
  'date': '1997-05-21',
  'country': 'GB',
  'artist-credit': [
    {'name': 'Radiohead', 'joinphrase': ''},
  ],
  'release-group': {'id': 'rg-1', 'primary-type': 'Album', 'secondary-types': <String>[]},
  'genres': [
    {'name': 'art rock', 'count': 4},
    {'name': 'alternative rock', 'count': 9},
  ],
  'media': [
    {
      'position': 1,
      'format': 'CD',
      'track-count': 2,
      'tracks': [
        {
          'position': 1,
          'number': '1',
          'title': 'Airbag',
          'length': 284000,
          'artist-credit': [
            {'name': 'Radiohead', 'joinphrase': ''},
          ],
          'recording': {'id': 'rec-1'},
        },
        {
          'position': 2,
          'number': '2',
          'title': 'Paranoid Android',
          'length': null,
          'recording': {
            'id': 'rec-2',
            'artist-credit': [
              {'name': 'Radiohead', 'joinphrase': ''},
            ],
          },
        },
      ],
    },
  ],
};

/// `GET release-group/rg-1?inc=genres`
const Map<String, Object?> releaseGroupLookup = {
  'id': 'rg-1',
  'genres': [
    {'name': 'rock', 'count': 3},
  ],
};

/// `GET recording?query=…`
const Map<String, Object?> recordingSearch = {
  'recordings': [
    {
      'id': 'rec-3',
      'score': 98,
      'title': 'Lucky',
      'length': 259000,
      'artist-credit': [
        {'name': 'Radiohead', 'joinphrase': ''},
      ],
      'releases': [
        {
          'id': 'rel-1',
          'title': 'OK Computer',
          'status': 'Official',
          'date': '1997-05-21',
          'track-count': 12,
          'release-group': {'id': 'rg-1', 'primary-type': 'Album', 'secondary-types': <String>[]},
          'media': [
            {
              'position': 1,
              'format': 'CD',
              'track-count': 12,
              'track-offset': 10,
              'track': [
                {'id': 't', 'number': '11', 'title': 'Lucky', 'length': 259000},
              ],
            },
          ],
        },
      ],
    },
  ],
};
```

- [ ] **Step 2: Write the failing tests** — `test/features/autofill/data/musicbrainz_source_test.dart`:

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:orpheus/features/autofill/data/musicbrainz_source.dart';
import 'package:orpheus/features/autofill/domain/metadata_source.dart';

import '../../../support/musicbrainz_fixtures.dart';

/// Asking MusicBrainz, against recorded answers rather than the service.
void main() {
  late List<http.Request> requests;

  MusicBrainzSource sourceAnswering(http.Response Function(http.Request request) answer) {
    requests = [];

    return MusicBrainzSource(
      client: MockClient((request) async {
        requests.add(request);
        return answer(request);
      }),
      version: '1.3.0',
      // No real waiting in a test: the spacing has its own tests.
      wait: (_) async {},
    );
  }

  http.Response json(Object body) => http.Response(
    jsonEncode(body),
    200,
    headers: const {'content-type': 'application/json; charset=utf-8'},
  );

  test('GivenARecordQuery_WhenReleasesAreSearched_ThenTheyAreParsedWithEverythingRankingNeeds', () async {
    final source = sourceAnswering((_) => json(releaseSearch));

    final found = await source.searchReleases(const ReleaseQuery(album: 'OK Computer', artist: 'Radiohead'));

    expect(found, hasLength(2));
    final first = found.first;
    expect(first.id, 'rel-1');
    expect(first.title, 'OK Computer');
    expect(first.artist, 'Radiohead');
    expect(first.trackCount, 12);
    expect(first.status, 'Official');
    expect(first.primaryType, 'Album');
    expect(first.format, 'CD');
    expect(first.country, 'GB');
    expect(first.score, 100);
    expect(found[1].disambiguation, 'remaster');
  });

  test('GivenAnyRequest_WhenItIsSent_ThenItNamesOrpheusAndAsksForJson', () async {
    final source = sourceAnswering((_) => json(releaseSearch));

    await source.searchReleases(const ReleaseQuery(album: 'OK Computer'));

    final request = requests.single;
    expect(request.headers['User-Agent'], 'Orpheus/1.3.0 ( https://github.com/artur-rios/orpheus )');
    expect(request.url.host, 'musicbrainz.org');
    expect(request.url.path, '/ws/2/release');
    expect(request.url.queryParameters['fmt'], 'json');
    expect(request.url.queryParameters['limit'], '10');
  });

  test('GivenNamesWithLuceneSyntaxInThem_WhenSearched_ThenTheyAreEscapedRatherThanInterpreted', () async {
    // Review focus: AC/DC, parentheses, quotes.
    final source = sourceAnswering((_) => json(const {'releases': <Object>[]}));

    await source.searchReleases(const ReleaseQuery(album: 'Back in Black (Remastered)', artist: 'AC/DC'));

    final query = requests.single.url.queryParameters['query']!;
    expect(query, r'release:"Back in Black \(Remastered\)" AND artist:"AC\/DC"');
    expect(MusicBrainzSource.escape('"Heroes"'), r'\"Heroes\"');
  });

  test('GivenTheOwnersOwnWords_WhenSearched_ThenTheyAreSentAsTheyWereTyped', () async {
    final source = sourceAnswering((_) => json(const {'releases': <Object>[]}));

    await source.searchReleases(const ReleaseQuery(text: 'radiohead ok computer'));

    expect(requests.single.url.queryParameters['query'], 'radiohead ok computer');
  });

  test('GivenAReleaseId_WhenItIsLookedUp_ThenItsTracksGenresAndGroupAreParsed', () async {
    final source = sourceAnswering((_) => json(releaseLookup));

    final detail = await source.release('rel-1');

    expect(requests.single.url.path, '/ws/2/release/rel-1');
    expect(requests.single.url.queryParameters['inc'], 'recordings+artist-credits+genres+release-groups+media');
    expect(detail.release.title, 'OK Computer');
    expect(detail.releaseGroupId, 'rg-1');
    expect(detail.tracks, hasLength(2));
    expect(detail.tracks.first.title, 'Airbag');
    expect(detail.tracks.first.disc, 1);
    expect(detail.tracks.first.position, 1);
    expect(detail.tracks.first.length, const Duration(milliseconds: 284000));
    expect(detail.tracks.first.recordingId, 'rec-1');
    // A track with no credit of its own takes its recording's.
    expect(detail.tracks[1].artist, 'Radiohead');
    expect(detail.tracks[1].length, isNull);
    // Most voted first, whatever order the service gave.
    expect([for (final g in detail.genres) g.name], ['alternative rock', 'art rock']);
  });

  test('GivenAReleaseGroup_WhenItsGenresAreAsked_ThenTheyAreParsed', () async {
    final source = sourceAnswering((_) => json(releaseGroupLookup));

    final genres = await source.releaseGroupGenres('rg-1');

    expect(requests.single.url.path, '/ws/2/release-group/rg-1');
    expect(genres.single.name, 'rock');
  });

  test('GivenATrackQueryWithALength_WhenRecordingsAreSearched_ThenTheLengthNarrowsItAndAppearancesAreParsed', () async {
    final source = sourceAnswering((_) => json(recordingSearch));

    final found = await source.searchRecordings(
      const RecordingQuery(title: 'Lucky', artist: 'Radiohead', duration: Duration(seconds: 259)),
    );

    expect(
      requests.single.url.queryParameters['query'],
      'recording:"Lucky" AND artist:"Radiohead" AND dur:[256000 TO 262000]',
    );
    final appearance = found.single.appearances.single;
    expect(appearance.release.id, 'rel-1');
    expect(appearance.release.primaryType, 'Album');
    expect(appearance.disc, 1);
    // track-offset is zero-based.
    expect(appearance.position, 11);
  });

  test('GivenAReleaseWithACover_WhenItIsFetched_ThenItsBytesComeBackFromTheCoverArtArchive', () async {
    final source = sourceAnswering((_) => http.Response.bytes([1, 2, 3], 200));

    final cover = await source.frontCover('rel-1');

    expect(cover, Uint8List.fromList([1, 2, 3]));
    expect(requests.single.url.toString(), 'https://coverartarchive.org/release/rel-1/front-500');
  });

  test('GivenAReleaseWithNoCover_WhenItIsFetched_ThenThereIsNone', () async {
    final source = sourceAnswering((_) => http.Response('', 404));

    expect(await source.frontCover('rel-1'), isNull);
  });

  test('GivenAnAnswerThatIsNotJson_WhenItArrives_ThenItIsReportedAsMalformed', () async {
    final source = sourceAnswering((_) => http.Response('<html>', 200));

    await expectLater(
      source.searchReleases(const ReleaseQuery(album: 'x')),
      throwsA(isA<MetadataSourceException>().having((e) => e.kind, 'kind', MetadataSourceFailure.malformed)),
    );
  });
}
```

- [ ] **Step 3: Run to verify failure**

Run: `flutter test test/features/autofill/data/musicbrainz_source_test.dart`
Expected: compilation error — the source does not exist.

- [ ] **Step 4: Write the implementation** — `lib/features/autofill/data/musicbrainz_source.dart`:

```dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import '../domain/metadata_source.dart';
import '../domain/release.dart';

/// [MetadataSource] over MusicBrainz, and the Cover Art Archive for covers.
///
/// No key and no account. What MusicBrainz asks in return is an honest
/// User-Agent and no more than one request a second, and both are kept here:
/// the one instance the provider binds holds the throttle, so two autofills in
/// a row cannot add up to more than the service allows.
///
/// What is sent is what an owner would type into the site's own search box:
/// a record's title and artist, or a track's title, artist and length. Not a
/// path, not a file, not anything that persists between requests.
class MusicBrainzSource implements MetadataSource {
  /// Creates the source.
  ///
  /// [wait] and [clock] are seams for the throttle's tests; nothing else
  /// passes them.
  MusicBrainzSource({
    http.Client? client,
    String? version,
    this.spacing = const Duration(seconds: 1),
    this.retryAfter = const Duration(seconds: 2),
    this.timeout = const Duration(seconds: 15),
    Future<void> Function(Duration delay)? wait,
    DateTime Function()? clock,
  }) : _client = client ?? http.Client(),
       userAgent = userAgentFor(version),
       _wait = wait ?? Future<void>.delayed,
       _clock = clock ?? DateTime.now;

  static final Logger _log = Logger('autofill');

  static final Uri _base = Uri.https('musicbrainz.org', '/ws/2/');

  final http.Client _client;
  final Future<void> Function(Duration delay) _wait;
  final DateTime Function() _clock;

  /// The least time between two requests.
  final Duration spacing;

  /// How long to wait before the one retry a 503 earns.
  final Duration retryAfter;

  /// How long a request may take.
  final Duration timeout;

  /// What this application calls itself, as MusicBrainz requires.
  final String userAgent;

  /// When the last request went out, or `null` before the first.
  DateTime? _last;

  /// The queue every request waits its turn in, so the spacing holds however
  /// many callers there are.
  Future<void> _turn = Future<void>.value();

  /// The User-Agent for [version].
  static String userAgentFor(String? version) =>
      'Orpheus/${version ?? 'unknown'} ( https://github.com/artur-rios/orpheus )';

  /// [term] with every character Lucene would read as syntax escaped.
  static String escape(String term) =>
      term.replaceAllMapped(RegExp(r'[+\-&|!(){}\[\]^"~*?:\\/]'), (m) => '\\${m[0]}');

  /// Lets go of the connections.
  void close() => _client.close();

  @override
  Future<List<ReleaseCandidate>> searchReleases(ReleaseQuery query) async {
    final body = await _json('release', {
      'query': query.text ?? _releaseLucene(query),
      'limit': '10',
    });

    return [
      for (final release in _list(body['releases']))
        if (release is Map<String, dynamic>) _candidateFrom(release),
    ];
  }

  @override
  Future<ReleaseDetail> release(String id) async {
    final body = await _json('release/$id', {
      'inc': 'recordings+artist-credits+genres+release-groups+media',
    });

    final tracks = <ReleaseTrack>[];
    for (final medium in _list(body['media'])) {
      if (medium is! Map<String, dynamic>) continue;
      final disc = (medium['position'] as num?)?.toInt() ?? 1;
      for (final track in _list(medium['tracks'])) {
        if (track is! Map<String, dynamic>) continue;
        final recording = track['recording'];
        final recordingMap = recording is Map<String, dynamic> ? recording : const <String, dynamic>{};
        final credit = _credits(track['artist-credit']);
        tracks.add(
          ReleaseTrack(
            disc: disc,
            position: (track['position'] as num?)?.toInt() ?? tracks.length + 1,
            title: track['title'] as String? ?? '',
            artistCredit: credit.isNotEmpty ? credit : _credits(recordingMap['artist-credit']),
            length: _length(track['length']),
            recordingId: recordingMap['id'] as String?,
          ),
        );
      }
    }

    final group = body['release-group'];

    return ReleaseDetail(
      release: _candidateFrom(body, trackCount: tracks.length),
      tracks: tracks,
      genres: _genres(body['genres']),
      releaseGroupId: group is Map<String, dynamic> ? group['id'] as String? : null,
    );
  }

  @override
  Future<List<Genre>> releaseGroupGenres(String id) async {
    final body = await _json('release-group/$id', {'inc': 'genres'});

    return _genres(body['genres']);
  }

  @override
  Future<List<RecordingMatch>> searchRecordings(RecordingQuery query) async {
    final body = await _json('recording', {
      'query': query.text ?? _recordingLucene(query),
      'limit': '10',
    });

    return [
      for (final recording in _list(body['recordings']))
        if (recording is Map<String, dynamic>) _recordingFrom(recording),
    ];
  }

  @override
  Future<Uint8List?> frontCover(String releaseId) async {
    final response = await _send(Uri.https('coverartarchive.org', '/release/$releaseId/front-500'));
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw const MetadataSourceException(MetadataSourceFailure.unreachable);
    }

    return response.bodyBytes;
  }

  String _releaseLucene(ReleaseQuery query) => [
    if (query.album case final album? when album.trim().isNotEmpty) 'release:"${escape(album.trim())}"',
    if (query.artist case final artist? when artist.trim().isNotEmpty) 'artist:"${escape(artist.trim())}"',
  ].join(' AND ');

  String _recordingLucene(RecordingQuery query) {
    final duration = query.duration;

    return [
      if (query.title case final title? when title.trim().isNotEmpty) 'recording:"${escape(title.trim())}"',
      if (query.artist case final artist? when artist.trim().isNotEmpty) 'artist:"${escape(artist.trim())}"',
      if (duration != null)
        'dur:[${duration.inMilliseconds - 3000} TO ${duration.inMilliseconds + 3000}]',
    ].join(' AND ');
  }

  Future<Map<String, dynamic>> _json(String path, Map<String, String> parameters) async {
    final uri = _base.resolve(path).replace(queryParameters: {...parameters, 'fmt': 'json'});
    final response = await _send(uri);
    if (response.statusCode != 200) {
      _log.info('musicbrainz answered ${response.statusCode} for $path');
      throw const MetadataSourceException(MetadataSourceFailure.unreachable);
    }

    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) return decoded;
    } on FormatException {
      // Answered below.
    }

    throw const MetadataSourceException(MetadataSourceFailure.malformed);
  }

  /// Sends one request in its turn, with the one retry a 503 earns.
  Future<http.Response> _send(Uri uri) async {
    var response = await _spaced(uri);
    if (response.statusCode == 503) {
      await _wait(retryAfter);
      response = await _spaced(uri);
      if (response.statusCode == 503) {
        throw const MetadataSourceException(MetadataSourceFailure.rateLimited);
      }
    }

    return response;
  }

  Future<http.Response> _spaced(Uri uri) {
    final done = Completer<http.Response>();

    _turn = _turn.then((_) async {
      final last = _last;
      if (last != null) {
        final since = _clock().difference(last);
        if (since < spacing) await _wait(spacing - since);
      }
      _last = _clock();

      try {
        done.complete(
          await _client.get(uri, headers: {'User-Agent': userAgent, 'Accept': 'application/json'}).timeout(timeout),
        );
      } on Object catch (error) {
        _log.info('musicbrainz could not be reached', error);
        done.completeError(const MetadataSourceException(MetadataSourceFailure.unreachable));
      }
    });

    return done.future;
  }

  static List<Object?> _list(Object? value) => value is List ? value : const [];

  static List<ArtistCredit> _credits(Object? value) => [
    for (final credit in _list(value))
      if (credit is Map<String, dynamic>)
        ArtistCredit(
          name: credit['name'] as String? ?? '',
          joinPhrase: credit['joinphrase'] as String? ?? '',
        ),
  ];

  static Duration? _length(Object? value) =>
      value is num ? Duration(milliseconds: value.toInt()) : null;

  static List<Genre> _genres(Object? value) => [
    for (final genre in _list(value))
      if (genre is Map<String, dynamic>)
        Genre(name: genre['name'] as String? ?? '', votes: (genre['count'] as num?)?.toInt() ?? 0),
  ]..sort((a, b) => b.votes.compareTo(a.votes));

  static ReleaseCandidate _candidateFrom(Map<String, dynamic> release, {int? trackCount}) {
    final group = release['release-group'];
    final groupMap = group is Map<String, dynamic> ? group : const <String, dynamic>{};
    final media = _list(release['media']);
    final firstMedium = media.firstOrNull;
    final disambiguation = release['disambiguation'] as String?;

    return ReleaseCandidate(
      id: release['id'] as String? ?? '',
      title: release['title'] as String? ?? '',
      artistCredit: _credits(release['artist-credit']),
      trackCount: (release['track-count'] as num?)?.toInt() ?? trackCount ?? 0,
      date: release['date'] as String?,
      country: release['country'] as String?,
      status: release['status'] as String?,
      primaryType: groupMap['primary-type'] as String?,
      secondaryTypes: [for (final t in _list(groupMap['secondary-types'])) if (t is String) t],
      format: firstMedium is Map<String, dynamic> ? firstMedium['format'] as String? : null,
      disambiguation: disambiguation == null || disambiguation.isEmpty ? null : disambiguation,
      score: (release['score'] as num?)?.toInt() ?? 0,
    );
  }

  static RecordingMatch _recordingFrom(Map<String, dynamic> recording) {
    final appearances = <RecordingAppearance>[];
    for (final release in _list(recording['releases'])) {
      if (release is! Map<String, dynamic>) continue;
      final medium = _list(release['media']).firstOrNull;
      if (medium is! Map<String, dynamic>) continue;
      appearances.add(
        RecordingAppearance(
          release: _candidateFrom(release),
          disc: (medium['position'] as num?)?.toInt() ?? 1,
          // `track-offset` counts from zero.
          position: ((medium['track-offset'] as num?)?.toInt() ?? 0) + 1,
        ),
      );
    }

    return RecordingMatch(
      recordingId: recording['id'] as String? ?? '',
      title: recording['title'] as String? ?? '',
      artistCredit: _credits(recording['artist-credit']),
      appearances: appearances,
      length: _length(recording['length']),
      score: (recording['score'] as num?)?.toInt() ?? 0,
    );
  }
}
```

Note: `Uri.replace(queryParameters:)` encodes `+` in `inc` as `%2B`; the test reads `queryParameters['inc']`, which decodes it back, and MusicBrainz accepts either.

- [ ] **Step 5: Run to verify pass**

Run: `flutter test test/features/autofill/data/musicbrainz_source_test.dart` then `flutter analyze`
Expected: all pass.

- [ ] **Step 6: Commit**

```bash
git add lib/features/autofill/data/musicbrainz_source.dart test/features/autofill/data/musicbrainz_source_test.dart test/support/musicbrainz_fixtures.dart
git commit -m "feat: look records up on musicbrainz"
```

---

### Task 6: MusicBrainz — spacing, retry and failure

**Files:**
- Test: `test/features/autofill/data/musicbrainz_source_test.dart` (append a group)
- Modify only if a test fails: `lib/features/autofill/data/musicbrainz_source.dart`

**Interfaces:**
- Consumes: Task 5's `MusicBrainzSource` constructor seams `wait`, `clock`, `spacing`, `retryAfter`.
- Produces: nothing new.

- [ ] **Step 1: Write the tests** — append inside `main()`:

```dart
  group('the service limits', () {
    test('GivenTwoRequestsBackToBack_WhenTheySend_ThenTheSecondWaitsOutTheRestOfTheSecond', () async {
      var now = DateTime.utc(2026);
      final waits = <Duration>[];
      final source = MusicBrainzSource(
        client: MockClient((_) async {
          now = now.add(const Duration(milliseconds: 200));
          return http.Response(jsonEncode(releaseGroupLookup), 200);
        }),
        clock: () => now,
        wait: (delay) async {
          waits.add(delay);
          now = now.add(delay);
        },
      );

      await source.releaseGroupGenres('a');
      await source.releaseGroupGenres('b');

      expect(waits, [const Duration(milliseconds: 800)]);
    });

    test('GivenTwoCallersAtOnce_WhenBothAsk_ThenTheirRequestsStillGoOutASecondApart', () async {
      var now = DateTime.utc(2026);
      final sentAt = <DateTime>[];
      final source = MusicBrainzSource(
        client: MockClient((_) async {
          sentAt.add(now);
          return http.Response(jsonEncode(releaseGroupLookup), 200);
        }),
        clock: () => now,
        wait: (delay) async => now = now.add(delay),
      );

      await Future.wait([source.releaseGroupGenres('a'), source.releaseGroupGenres('b')]);

      expect(sentAt[1].difference(sentAt[0]), greaterThanOrEqualTo(const Duration(seconds: 1)));
    });

    test('GivenTheServiceAsksForFewerRequestsOnce_WhenTheRetryIsAnswered_ThenTheAnswerComesBack', () async {
      var calls = 0;
      final source = MusicBrainzSource(
        client: MockClient((_) async {
          calls++;
          return calls == 1 ? http.Response('', 503) : http.Response(jsonEncode(releaseGroupLookup), 200);
        }),
        wait: (_) async {},
      );

      final genres = await source.releaseGroupGenres('rg-1');

      expect(calls, 2);
      expect(genres.single.name, 'rock');
    });

    test('GivenTheServiceKeepsAskingForFewerRequests_WhenTheRetryFailsToo_ThenItIsReportedAsRateLimited', () async {
      final source = MusicBrainzSource(
        client: MockClient((_) async => http.Response('', 503)),
        wait: (_) async {},
      );

      await expectLater(
        source.releaseGroupGenres('rg-1'),
        throwsA(isA<MetadataSourceException>().having((e) => e.kind, 'kind', MetadataSourceFailure.rateLimited)),
      );
    });

    test('GivenNoNetwork_WhenAskedAnything_ThenItIsReportedAsUnreachable', () async {
      final source = MusicBrainzSource(
        client: MockClient((_) async => throw http.ClientException('no route to host')),
        wait: (_) async {},
      );

      await expectLater(
        source.searchReleases(const ReleaseQuery(album: 'x')),
        throwsA(isA<MetadataSourceException>().having((e) => e.kind, 'kind', MetadataSourceFailure.unreachable)),
      );
    });

    test('GivenAFailedRequest_WhenTheNextOneIsAsked_ThenTheQueueStillMoves', () async {
      var calls = 0;
      final source = MusicBrainzSource(
        client: MockClient((_) async {
          calls++;
          if (calls == 1) throw http.ClientException('dropped');
          return http.Response(jsonEncode(releaseGroupLookup), 200);
        }),
        wait: (_) async {},
      );

      await expectLater(source.releaseGroupGenres('a'), throwsA(isA<MetadataSourceException>()));
      expect((await source.releaseGroupGenres('b')).single.name, 'rock');
    });
  });
```

- [ ] **Step 2: Run them**

Run: `flutter test test/features/autofill/data/musicbrainz_source_test.dart`
Expected: PASS with Task 5's implementation. If *GivenTwoCallersAtOnce* fails, the `_turn` chain is not being awaited in order — fix `_spaced` so each request's body runs inside the `_turn.then` callback, as written in Task 5. If *GivenAFailedRequest* hangs, the error is escaping the `_turn` chain: keep the `try/catch` inside the callback so `_turn` itself never completes with an error.

- [ ] **Step 3: Commit**

```bash
git add test/features/autofill/data/musicbrainz_source_test.dart lib/features/autofill/data/musicbrainz_source.dart
git commit -m "test: keep musicbrainz to one request a second"
```

---

### Task 7: Tag fixtures and reading what a file holds

**Files:**
- Create: `test/support/tag_fixtures/make_fixtures.sh`, `test/support/tag_fixtures/README.md`, the generated `test/support/tag_fixtures/*.{mp3,m4a,wav}` files, `lib/features/autofill/data/audio_metadata_tag_writer.dart`
- Modify: `.gitattributes` (mark the fixtures binary)
- Test: `test/features/autofill/data/audio_metadata_tag_writer_test.dart`

**Interfaces:**
- Consumes: Task 1's `TagWriter`, `FileTags`, `AutofillField`, `canWriteTagsTo`; `readTags` is **not** used here (it maps to `TrackMetadata`, which has no disc total); `audio_metadata_reader`'s `readAllMetadata`.
- Produces: `class AudioMetadataTagWriter implements TagWriter { const AudioMetadataTagWriter(); }` with `inspect` implemented (write lands in Task 8); `static Set<AutofillField> fieldsFor(String path)`.

- [ ] **Step 1: Generate the fixtures**

`test/support/tag_fixtures/make_fixtures.sh`:

```bash
#!/usr/bin/env bash
# Regenerates the tagged audio fixtures the tag writer is tested against.
#
# Half a second of silence each, so the files are a few kilobytes, carrying
# the tags the preservation tests check survive a write: the fields an
# autofill writes, and the ones it must never lose — a comment, a custom
# field, and on the M4A an album artist the writer's model does not hold.
#
# Needs ffmpeg. The output is committed; run this only to change it.
set -euo pipefail
cd "$(dirname "$0")"

common=(-f lavfi -i anullsrc=r=44100:cl=mono -t 0.5 -y)
tags=(
  -metadata title="Airbag"
  -metadata artist="Radiohed"
  -metadata album="OK Computer"
  -metadata track="1/12"
  -metadata date="1997"
  -metadata genre="Rock"
  -metadata comment="kept"
)

ffmpeg -hide_banner -loglevel error "${common[@]}" -c:a libmp3lame -b:a 32k \
  -id3v2_version 4 "${tags[@]}" -metadata album_artist="Radiohead" \
  -metadata disc="1/1" -metadata CUSTOM="kept" tagged.mp3

ffmpeg -hide_banner -loglevel error "${common[@]}" -c:a aac -b:a 32k \
  "${tags[@]}" -metadata album_artist="Radiohead" -metadata disc="1/1" tagged.m4a

ffmpeg -hide_banner -loglevel error "${common[@]}" -c:a pcm_s16le \
  "${tags[@]}" tagged.wav

ffmpeg -hide_banner -loglevel error "${common[@]}" -c:a libvorbis \
  "${tags[@]}" tagged.ogg
```

Run it (Git Bash on Windows, or Linux):

```bash
bash test/support/tag_fixtures/make_fixtures.sh
ls -l test/support/tag_fixtures
```

Expected: `tagged.mp3`, `tagged.m4a`, `tagged.wav`, `tagged.ogg`, each under 20 KB. Append to `.gitattributes`:

```
*.mp3 binary
*.m4a binary
*.wav binary
*.ogg binary
```

`test/support/tag_fixtures/README.md` — two sentences: what the files are, and that `make_fixtures.sh` regenerates them with ffmpeg. FLAC is built in code by `test/support/flac_fixture.dart` and needs no file here.

- [ ] **Step 2: Write the failing tests** — `test/features/autofill/data/audio_metadata_tag_writer_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/autofill/data/audio_metadata_tag_writer.dart';
import 'package:orpheus/features/autofill/domain/autofill_field.dart';
import 'package:path/path.dart' as p;

import '../../../support/flac_fixture.dart';

/// Reading and writing a real file's tags, in a temporary directory.
void main() {
  late Directory root;
  const writer = AudioMetadataTagWriter();

  setUp(() async => root = await Directory.systemTemp.createTemp('orpheus-tags'));
  tearDown(() async {
    if (root.existsSync()) await root.delete(recursive: true);
  });

  /// A copy of the fixture [name] in this test's directory.
  String copyOf(String name) {
    final target = p.join(root.path, name);
    File(p.join('test', 'support', 'tag_fixtures', name)).copySync(target);

    return target;
  }

  String flac(Map<String, String> tags) {
    final target = p.join(root.path, 'a.flac');
    File(target).writeAsBytesSync(taggedFlac(tags: tags));

    return target;
  }

  group('inspect', () {
    test('GivenAnMp3_WhenInspected_ThenItsTagsAndEveryFieldAreAvailable', () async {
      final tags = await writer.inspect(copyOf('tagged.mp3'));

      expect(tags.values[AutofillField.title], 'Airbag');
      expect(tags.values[AutofillField.artist], 'Radiohed');
      expect(tags.values[AutofillField.albumArtist], 'Radiohead');
      expect(tags.values[AutofillField.trackNumber], 1);
      expect(tags.values[AutofillField.trackTotal], 12);
      expect(tags.values[AutofillField.year], 1997);
      expect(tags.writable, AutofillField.values.toSet());
    });

    test('GivenAFlac_WhenInspected_ThenItsTagsAreReadIncludingTheAlbumArtist', () async {
      final tags = await writer.inspect(flac({'TITLE': 'Airbag', 'ALBUMARTIST': 'Radiohead', 'DISCTOTAL': '2'}));

      expect(tags.values[AutofillField.title], 'Airbag');
      expect(tags.values[AutofillField.albumArtist], 'Radiohead');
      expect(tags.values[AutofillField.discTotal], 2);
      expect(tags.writable, AutofillField.values.toSet());
    });

    test('GivenAWav_WhenInspected_ThenOnlyTheFieldsItsFormatHoldsAreWritable', () async {
      final tags = await writer.inspect(copyOf('tagged.wav'));

      expect(tags.writable, isNot(contains(AutofillField.albumArtist)));
      expect(tags.writable, isNot(contains(AutofillField.discNumber)));
      expect(tags.writable, contains(AutofillField.title));
    });

    test('GivenAnOgg_WhenInspected_ThenNothingIsWritable', () async {
      expect((await writer.inspect(copyOf('tagged.ogg'))).writable, isEmpty);
    });

    test('GivenAFileThatIsNotThere_WhenInspected_ThenNothingIsWritable', () async {
      expect((await writer.inspect(p.join(root.path, 'gone.mp3'))).writable, isEmpty);
    });
  });
}
```

- [ ] **Step 3: Run to verify failure**

Run: `flutter test test/features/autofill/data/audio_metadata_tag_writer_test.dart`
Expected: compilation error — the writer does not exist.

- [ ] **Step 4: Write `inspect`** — `lib/features/autofill/data/audio_metadata_tag_writer.dart`:

```dart
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import '../../library/domain/audio_file.dart';
import '../domain/autofill_field.dart';
import '../domain/tag_writer.dart';

/// [TagWriter] over `audio_metadata_reader`, which this application already
/// reads every tag through.
///
/// Every field is mapped by hand rather than through the package's common
/// setters: those have no album artist, and quietly do nothing for a field a
/// format cannot hold — which on a review screen would be a change the owner
/// confirmed and that never happened. A field a format cannot hold is instead
/// left out of [FileTags.writable], and the screen says so.
///
/// File work runs on an isolate: a cover is hundreds of kilobytes, and an
/// album is a dozen of them.
class AudioMetadataTagWriter implements TagWriter {
  /// Creates the writer.
  const AudioMetadataTagWriter();

  static final Logger _log = Logger('autofill');

  /// The fields the format of [path] can hold.
  static Set<AutofillField> fieldsFor(String path) {
    if (!canWriteTagsTo(path)) return const {};

    return switch (p.extension(path).toLowerCase()) {
      '.m4a' || '.mp4' => AutofillField.values.toSet()..remove(AutofillField.albumArtist),
      '.wav' => {
        AutofillField.title,
        AutofillField.artist,
        AutofillField.album,
        AutofillField.trackNumber,
        AutofillField.year,
        AutofillField.genre,
        AutofillField.cover,
      },
      _ => AutofillField.values.toSet(),
    };
  }

  @override
  Future<FileTags> inspect(String path) async {
    final writable = fieldsFor(path);
    if (writable.isEmpty) return FileTags.unwritable;

    try {
      return await Isolate.run(() => _inspect(path, writable));
    } on Object catch (error) {
      _log.info('the tags of $path could not be read', error);

      return FileTags.unwritable;
    }
  }

  @override
  Future<WriteOutcome> write(
    String path,
    Map<AutofillField, Object?> values, {
    required AudioFile expected,
  }) => throw UnimplementedError('Task 8');
}

FileTags _inspect(String path, Set<AutofillField> writable) {
  final tags = readAllMetadata(File(path));

  final values = switch (tags) {
    Mp3Metadata() => {
      AutofillField.title: tags.songName,
      AutofillField.artist: tags.leadPerformer,
      AutofillField.albumArtist: tags.bandOrOrchestra,
      AutofillField.album: tags.album,
      AutofillField.trackNumber: tags.trackNumber,
      AutofillField.trackTotal: tags.trackTotal,
      AutofillField.discNumber: tags.discNumber ?? _first(tags.partOfSet),
      AutofillField.discTotal: tags.totalDics ?? _second(tags.partOfSet),
      AutofillField.year: tags.year,
      AutofillField.genre: tags.genres.firstOrNull,
    },
    Mp4Metadata() => {
      AutofillField.title: tags.title,
      AutofillField.artist: tags.artist,
      AutofillField.album: tags.album,
      AutofillField.trackNumber: tags.trackNumber,
      AutofillField.trackTotal: tags.totalTracks,
      AutofillField.discNumber: tags.discNumber,
      AutofillField.discTotal: tags.totalDiscs,
      AutofillField.year: tags.year?.year,
      AutofillField.genre: tags.genre,
    },
    VorbisMetadata() => {
      AutofillField.title: tags.title.firstOrNull,
      AutofillField.artist: tags.artist.firstOrNull,
      AutofillField.albumArtist: tags.albumArtist.firstOrNull,
      AutofillField.album: tags.album.firstOrNull,
      AutofillField.trackNumber: tags.trackNumber.firstOrNull,
      AutofillField.trackTotal: tags.trackTotal,
      AutofillField.discNumber: tags.discNumber,
      AutofillField.discTotal: tags.discTotal,
      AutofillField.year: tags.date.firstOrNull?.year,
      AutofillField.genre: tags.genres.firstOrNull,
    },
    RiffMetadata() => {
      AutofillField.title: tags.title,
      AutofillField.artist: tags.artist,
      AutofillField.album: tags.album,
      AutofillField.trackNumber: tags.trackNumber,
      AutofillField.year: tags.year?.year,
      AutofillField.genre: tags.genre,
    },
    ApeMetadata() => {
      AutofillField.title: tags.title,
      AutofillField.artist: tags.artist,
      AutofillField.albumArtist: tags.albumArtist,
      AutofillField.album: tags.album,
      AutofillField.trackNumber: tags.trackNumber,
      AutofillField.trackTotal: tags.trackTotal,
      AutofillField.discNumber: tags.discNumber,
      AutofillField.discTotal: tags.discTotal,
      AutofillField.year: tags.date?.year,
      AutofillField.genre: tags.genres.firstOrNull,
    },
  };

  final pictures = switch (tags) {
    Mp3Metadata() => tags.pictures,
    Mp4Metadata() => [?tags.picture],
    VorbisMetadata() => tags.pictures,
    RiffMetadata() => tags.pictures,
    ApeMetadata() => tags.pictures,
  };

  return FileTags(
    writable: writable,
    values: values,
    cover: _front(pictures),
  );
}

Uint8List? _front(List<Picture> pictures) {
  for (final picture in pictures) {
    if (picture.pictureType == PictureType.coverFront) return picture.bytes;
  }

  return pictures.firstOrNull?.bytes;
}

int? _first(String? partOfSet) => int.tryParse((partOfSet ?? '').split('/').first.trim());

int? _second(String? partOfSet) {
  final parts = (partOfSet ?? '').split('/');

  return parts.length < 2 ? null : int.tryParse(parts[1].trim());
}
```

If `readAllMetadata` answers the `.ogg` fixture as `VorbisMetadata`, the `fieldsFor` check has already returned `FileTags.unwritable` before it is read — which is the point of checking the extension first.

- [ ] **Step 5: Run to verify pass**

Run: `flutter test test/features/autofill/data/audio_metadata_tag_writer_test.dart` then `flutter analyze`
Expected: all `inspect` tests pass. If the MP3 album artist reads `null`, check with `ffprobe test/support/tag_fixtures/tagged.mp3` that ffmpeg wrote `TPE2`; if the reader exposes it under another field, map that field and note it in the commit body.

- [ ] **Step 6: Commit**

```bash
git add .gitattributes test/support/tag_fixtures lib/features/autofill/data/audio_metadata_tag_writer.dart test/features/autofill/data/audio_metadata_tag_writer_test.dart
git commit -m "feat: read what a file's tags hold for autofill"
```

---

### Task 8: Writing tags, and the preservation gate

**Files:**
- Modify: `lib/features/autofill/data/audio_metadata_tag_writer.dart` (implement `write`)
- Test: `test/features/autofill/data/audio_metadata_tag_writer_test.dart` (append groups)

**Interfaces:**
- Consumes: Task 7's writer and fixtures; `AudioFile`.
- Produces: a working `write`, and — the gate — `fieldsFor` returning `{}` for any format whose preservation test fails.

- [ ] **Step 1: Write the failing tests** — append inside `main()`:

```dart
  AudioFile asCatalogued(String path) {
    final stat = File(path).statSync();

    return AudioFile(path: path, sizeInBytes: stat.size, modifiedAt: stat.modified);
  }

  final everything = <AutofillField, Object?>{
    AutofillField.title: 'Paranoid Android',
    AutofillField.artist: 'Radiohead',
    AutofillField.albumArtist: 'Radiohead',
    AutofillField.album: 'OK Computer (Remastered)',
    AutofillField.trackNumber: 2,
    AutofillField.trackTotal: 12,
    AutofillField.discNumber: 1,
    AutofillField.discTotal: 1,
    AutofillField.year: 1997,
    AutofillField.genre: 'Alternative Rock',
    AutofillField.cover: onePixelPng(),
  };

  group('write', () {
    for (final name in ['tagged.mp3', 'tagged.m4a', 'tagged.wav', 'a.flac']) {
      test('GivenA${p.extension(name)}File_WhenEveryFieldItHoldsIsWritten_ThenEachReadsBack', () async {
        final path = name == 'a.flac'
            ? flac({'TITLE': 'Airbag', 'ARTIST': 'Radiohed', 'COMMENT': 'kept'})
            : copyOf(name);
        final writable = AudioMetadataTagWriter.fieldsFor(path);
        final values = {for (final field in writable) field: everything[field]};

        final outcome = await writer.write(path, values, expected: asCatalogued(path));
        final after = await writer.inspect(path);

        expect(outcome, WriteOutcome.written);
        for (final field in writable) {
          if (field == AutofillField.cover) {
            expect(after.cover, everything[AutofillField.cover], reason: '$name cover');
          } else {
            expect(after.values[field], everything[field], reason: '$name ${field.name}');
          }
        }
      });
    }
  });

  group('the preservation gate', () {
    // A format is only writable if a write leaves every tag it was not asked
    // to change exactly as it was — including the ones the package's model
    // does not hold. These read the file back with ffprobe-independent means:
    // the raw bytes must still carry the kept values.
    for (final name in ['tagged.mp3', 'tagged.m4a', 'tagged.wav', 'a.flac']) {
      test('GivenA${p.extension(name)}FileWithTagsTheAutofillDoesNotTouch_WhenOneFieldIsWritten_ThenTheyAreAllStillThere', () async {
        final path = name == 'a.flac'
            ? flac({'TITLE': 'Airbag', 'COMMENT': 'kept', 'CUSTOM': 'kept'})
            : copyOf(name);
        final before = await writer.inspect(path);

        await writer.write(path, {AutofillField.title: 'Paranoid Android'}, expected: asCatalogued(path));

        final after = await writer.inspect(path);
        for (final field in AutofillField.values.where((f) => f != AutofillField.title)) {
          expect(after.values[field], before.values[field], reason: '$name ${field.name}');
        }
        expect(after.cover, before.cover, reason: '$name cover');
        // The tags no field covers: a comment on every format, and on the M4A
        // the album artist (aART) the writer's model cannot hold.
        final raw = latin1.decode(File(path).readAsBytesSync(), allowInvalid: true);
        expect(raw, contains('kept'), reason: '$name comment');
        if (name == 'tagged.m4a') expect(raw, contains('aART'), reason: 'm4a album artist');
      });
    }
  });

  group('refusals', () {
    test('GivenAFileChangedSinceItWasRead_WhenWritten_ThenItIsLeftAlone', () async {
      final path = copyOf('tagged.mp3');
      final catalogued = asCatalogued(path);
      // Another tag editor gets there first.
      File(path).writeAsBytesSync([...File(path).readAsBytesSync(), 0]);

      final outcome = await writer.write(path, {AutofillField.title: 'X'}, expected: catalogued);

      expect(outcome, WriteOutcome.changedSinceRead);
      expect((await writer.inspect(path)).values[AutofillField.title], 'Airbag');
    });

    test('GivenAnOgg_WhenWritten_ThenItIsUnsupportedAndUntouched', () async {
      final path = copyOf('tagged.ogg');
      final bytes = File(path).readAsBytesSync();

      final outcome = await writer.write(path, {AutofillField.title: 'X'}, expected: asCatalogued(path));

      expect(outcome, WriteOutcome.unsupported);
      expect(File(path).readAsBytesSync(), bytes);
    });

    test('GivenAFileThatIsGone_WhenWritten_ThenItIsReportedAsChanged', () async {
      final path = copyOf('tagged.mp3');
      final catalogued = asCatalogued(path);
      File(path).deleteSync();

      expect(
        await writer.write(path, {AutofillField.title: 'X'}, expected: catalogued),
        WriteOutcome.changedSinceRead,
      );
    });
  });
```

Add the imports this needs: `dart:convert` (`latin1`), `AudioFile`, `WriteOutcome` from `tag_writer.dart`.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/autofill/data/audio_metadata_tag_writer_test.dart`
Expected: the new tests FAIL with `UnimplementedError: Task 8`.

- [ ] **Step 3: Implement `write`** — replace the stub in `AudioMetadataTagWriter`:

```dart
  @override
  Future<WriteOutcome> write(
    String path,
    Map<AutofillField, Object?> values, {
    required AudioFile expected,
  }) async {
    final writable = fieldsFor(path);
    if (writable.isEmpty) return WriteOutcome.unsupported;
    if (values.keys.any((field) => !writable.contains(field))) {
      return WriteOutcome.unsupported;
    }

    try {
      return await Isolate.run(() => _write(path, values, expected));
    } on Object catch (error) {
      _log.warning('the tags of $path could not be written', error);

      return WriteOutcome.failed;
    }
  }
```

and add below `_inspect`:

```dart
WriteOutcome _write(
  String path,
  Map<AutofillField, Object?> values,
  AudioFile expected,
) {
  final file = File(path);

  // The same file the owner reviewed, or nothing: an edit another program
  // made since is not one to overwrite with a proposal made before it.
  final FileStat stat;
  try {
    if (!file.existsSync()) return WriteOutcome.changedSinceRead;
    stat = file.statSync();
  } on FileSystemException {
    return WriteOutcome.denied;
  }
  if (stat.size != expected.sizeInBytes ||
      stat.modified.millisecondsSinceEpoch != expected.modifiedAt.millisecondsSinceEpoch) {
    return WriteOutcome.changedSinceRead;
  }

  try {
    updateMetadata(file, (tags) => _apply(tags, values));
  } on FileSystemException catch (error) {
    return _outcomeOf(error);
  }

  return WriteOutcome.written;
}

/// What a refused write was.
///
/// Windows answers a file another process holds open — the track playing,
/// which libmpv has open — with a sharing violation (32) or, for the rename
/// over it, access denied (5) while the file itself is writable. Elsewhere a
/// permission error is a permission error.
WriteOutcome _outcomeOf(FileSystemException error) {
  final code = error.osError?.errorCode;
  if (Platform.isWindows && (code == 32 || code == 33)) return WriteOutcome.inUse;
  if (Platform.isWindows && code == 5) return WriteOutcome.inUse;
  if (code == 13 || code == 1 || code == 30) return WriteOutcome.denied;

  return WriteOutcome.failed;
}

void _apply(ParserTag tags, Map<AutofillField, Object?> values) {
  String? text(AutofillField field) => values[field] as String?;
  int? number(AutofillField field) => values[field] as int?;
  bool has(AutofillField field) => values.containsKey(field);
  final cover = values[AutofillField.cover] as Uint8List?;
  final picture = cover == null ? null : Picture(cover, _mimeOf(cover), PictureType.coverFront);

  switch (tags) {
    case Mp3Metadata m:
      if (has(AutofillField.title)) m.songName = text(AutofillField.title);
      if (has(AutofillField.artist)) m.leadPerformer = text(AutofillField.artist);
      if (has(AutofillField.albumArtist)) m.bandOrOrchestra = text(AutofillField.albumArtist);
      if (has(AutofillField.album)) m.album = text(AutofillField.album);
      if (has(AutofillField.trackNumber)) m.trackNumber = number(AutofillField.trackNumber);
      if (has(AutofillField.trackTotal)) m.trackTotal = number(AutofillField.trackTotal);
      if (has(AutofillField.discNumber) || has(AutofillField.discTotal)) {
        final disc = has(AutofillField.discNumber) ? number(AutofillField.discNumber) : (m.discNumber ?? _first(m.partOfSet));
        final total = has(AutofillField.discTotal) ? number(AutofillField.discTotal) : (m.totalDics ?? _second(m.partOfSet));
        m.discNumber = disc;
        m.totalDics = total;
        m.partOfSet = disc == null ? null : (total == null ? '$disc' : '$disc/$total');
      }
      if (has(AutofillField.year)) m.year = number(AutofillField.year);
      if (has(AutofillField.genre)) m.genres = [?text(AutofillField.genre)];
      if (picture != null) {
        m.pictures = [picture, ...m.pictures.where((p) => p.pictureType != PictureType.coverFront)];
      }
    case Mp4Metadata m:
      if (has(AutofillField.title)) m.title = text(AutofillField.title);
      if (has(AutofillField.artist)) m.artist = text(AutofillField.artist);
      if (has(AutofillField.album)) m.album = text(AutofillField.album);
      if (has(AutofillField.trackNumber)) m.trackNumber = number(AutofillField.trackNumber);
      if (has(AutofillField.trackTotal)) m.totalTracks = number(AutofillField.trackTotal);
      if (has(AutofillField.discNumber)) m.discNumber = number(AutofillField.discNumber);
      if (has(AutofillField.discTotal)) m.totalDiscs = number(AutofillField.discTotal);
      if (has(AutofillField.year)) {
        final year = number(AutofillField.year);
        m.year = year == null ? null : DateTime(year);
      }
      if (has(AutofillField.genre)) m.genre = text(AutofillField.genre);
      if (picture != null) m.picture = picture;
    case VorbisMetadata m:
      if (has(AutofillField.title)) m.title = [?text(AutofillField.title)];
      if (has(AutofillField.artist)) m.artist = [?text(AutofillField.artist)];
      if (has(AutofillField.albumArtist)) m.albumArtist = [?text(AutofillField.albumArtist)];
      if (has(AutofillField.album)) m.album = [?text(AutofillField.album)];
      if (has(AutofillField.trackNumber)) m.trackNumber = [?number(AutofillField.trackNumber)];
      if (has(AutofillField.trackTotal)) m.trackTotal = number(AutofillField.trackTotal);
      if (has(AutofillField.discNumber)) m.discNumber = number(AutofillField.discNumber);
      if (has(AutofillField.discTotal)) m.discTotal = number(AutofillField.discTotal);
      if (has(AutofillField.year)) {
        final year = number(AutofillField.year);
        m.date = year == null ? [] : [DateTime(year)];
      }
      if (has(AutofillField.genre)) m.genres = [?text(AutofillField.genre)];
      if (picture != null) {
        m.pictures = [picture, ...m.pictures.where((p) => p.pictureType != PictureType.coverFront)];
      }
    case RiffMetadata m:
      if (has(AutofillField.title)) m.title = text(AutofillField.title);
      if (has(AutofillField.artist)) m.artist = text(AutofillField.artist);
      if (has(AutofillField.album)) m.album = text(AutofillField.album);
      if (has(AutofillField.trackNumber)) m.trackNumber = number(AutofillField.trackNumber);
      if (has(AutofillField.year)) {
        final year = number(AutofillField.year);
        m.year = year == null ? null : DateTime(year);
      }
      if (has(AutofillField.genre)) m.genre = text(AutofillField.genre);
      if (picture != null) {
        m.pictures = [picture, ...m.pictures.where((p) => p.pictureType != PictureType.coverFront)];
      }
    case ApeMetadata m:
      if (has(AutofillField.title)) m.title = text(AutofillField.title);
      if (has(AutofillField.artist)) m.artist = text(AutofillField.artist);
      if (has(AutofillField.albumArtist)) m.albumArtist = text(AutofillField.albumArtist);
      if (has(AutofillField.album)) m.album = text(AutofillField.album);
      if (has(AutofillField.trackNumber)) m.trackNumber = number(AutofillField.trackNumber);
      if (has(AutofillField.trackTotal)) m.trackTotal = number(AutofillField.trackTotal);
      if (has(AutofillField.discNumber)) m.discNumber = number(AutofillField.discNumber);
      if (has(AutofillField.discTotal)) m.discTotal = number(AutofillField.discTotal);
      if (has(AutofillField.year)) {
        final year = number(AutofillField.year);
        m.date = year == null ? null : DateTime(year);
      }
      if (has(AutofillField.genre)) m.genres = [?text(AutofillField.genre)];
      if (picture != null) {
        m.pictures = [picture, ...m.pictures.where((p) => p.pictureType != PictureType.coverFront)];
      }
  }
}

String _mimeOf(Uint8List bytes) =>
    bytes.length > 3 && bytes[0] == 0x89 && bytes[1] == 0x50 ? 'image/png' : 'image/jpeg';
```

Check the `Picture` constructor's parameter order against `/d/pub-cache/hosted/pub.dev/audio_metadata_reader-1.8.0/lib/src/metadata/base.dart` (`grep -n "class Picture" -A12`) before running; the README shows `Picture(bytes, mimetype, PictureType.coverFront)`.

- [ ] **Step 4: Run, and apply the gate**

Run: `flutter test test/features/autofill/data/audio_metadata_tag_writer_test.dart`

For each format, one of:
- **All pass** → leave it in `fieldsFor`.
- **A field round-trip fails** (e.g. M4A track total) → remove that field from the format's set in `fieldsFor`, and drop it from that format's round-trip expectation by virtue of `fieldsFor` (the test reads the set). Re-run.
- **The preservation test fails** (e.g. the M4A loses `aART`, or the comment) → the format is lossy: make `fieldsFor` return `const {}` for its extension, remove it from `writableExtensions` in `tag_writer.dart`, update Task 1's `canWriteTagsTo` test accordingly, and keep the preservation test as a `skip:`ped test whose reason names what is lost, so it reruns when the package is upgraded.

Record the final matrix in the commit body. Then run `flutter analyze` and the whole suite.

- [ ] **Step 5: Commit**

```bash
git add lib/features/autofill test/features/autofill
git commit -F - <<'EOF'
feat: write tags without losing the rest

Write through audio_metadata_reader's updateMetadata on an isolate,
refusing a file that changed since it was read. A format is writable
only where a write leaves every other tag in place.

Writable after the gate: one line per format, as Step 4 found it,
e.g. "mp3: all; m4a: all but album artist; wav: title, artist, album,
track no., year, genre, cover".
EOF
```

---

### Task 9: Plumbing — providers, write access, `rescanSoon`, test doubles

**Files:**
- Modify: `lib/core/di/providers.dart`, `lib/features/library/domain/library_access.dart`, `lib/features/library/data/permission_library_access.dart`, `lib/features/library/application/library_folders_controller.dart` (`LibraryAccessController`), `lib/features/library/application/scan_controller.dart`, `test/support/fakes.dart` (`FakeLibraryAccess`), `test/support/test_container.dart`
- Create: `test/support/fake_autofill.dart`
- Test: `test/features/library/application/scan_controller_test.dart` (append), `test/features/library/application/library_folders_controller_test.dart` (append)

**Interfaces:**
- Consumes: Tasks 1, 5, 8.
- Produces:
  - `LibraryAccess.requestWrite() → Future<LibraryAccessDecision>`.
  - `LibraryAccessController.ensureWritable() → Future<LibraryAccessDecision>`.
  - `ScanController.rescanSoon() → Future<void>`.
  - Providers: `metadataSourceProvider` (`Provider<MetadataSource>`), `tagWriterProvider` (`Provider<TagWriter>`).
  - Test doubles: `ScriptedMetadataSource`, `FakeTagWriter`; `Harness({ScriptedMetadataSource? metadata, FakeTagWriter? tagWriter})` with fields `metadata` and `tagWriter`; `FakeLibraryAccess.writeDecision` and `writeRequests`.

- [ ] **Step 1: Write the failing tests**

Append to `test/features/library/application/scan_controller_test.dart`:

```dart
  test(
    'GivenAScanIsRunning_WhenARescanIsAskedForSoon_ThenAnotherRunsWhenItEnds',
    () async {
      // Tags were written while a scan was walking: it may already have passed
      // the files, and the library must not keep their old tags.
      final scanner = ScriptedScanner([
        ScanCompleted(catalog: scanned, report: report),
      ]);
      final harness = harnessWith(scanner);
      final controller = harness.read(scanControllerProvider.notifier);

      final first = controller.scan();
      await Future<void>.delayed(Duration.zero);
      expect(harness.read(scanControllerProvider).isRunning, isTrue);
      await controller.rescanSoon();
      await first.timeout(const Duration(seconds: 5));

      expect(scanner.requests, hasLength(2));
    },
  );

  test(
    'GivenNoScanIsRunning_WhenARescanIsAskedForSoon_ThenOneRunsWithoutAskingForAccess',
    () async {
      final access = FakeLibraryAccess();
      final scanner = ScriptedScanner([
        ScanCompleted(catalog: scanned, report: report),
      ]);
      final harness = harnessWith(scanner, access: access);

      await harness.read(scanControllerProvider.notifier).rescanSoon();

      expect(scanner.requests, hasLength(1));
      expect(access.requests, 0);
    },
  );
```

Append to `test/features/library/application/library_folders_controller_test.dart`:

```dart
  test(
    'GivenTheOwnerAllowsWriting_WhenWriteAccessIsEnsured_ThenItIsGranted',
    () async {
      final access = FakeLibraryAccess();
      final harness = Harness(access: access);

      final decision = await harness
          .read(libraryAccessControllerProvider.notifier)
          .ensureWritable();

      expect(decision, LibraryAccessDecision.granted);
      expect(access.writeRequests, 1);
    },
  );

  test(
    'GivenTheOwnerRefusesWriting_WhenWriteAccessIsEnsured_ThenTheRefusalIsAnswered',
    () async {
      final access = FakeLibraryAccess()
        ..writeDecision = LibraryAccessDecision.deniedPermanently;
      final harness = Harness(access: access);

      expect(
        await harness.read(libraryAccessControllerProvider.notifier).ensureWritable(),
        LibraryAccessDecision.deniedPermanently,
      );
    },
  );
```

(Add the `LibraryAccessDecision` import if the file lacks it.)

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/library/application`
Expected: compilation errors — `rescanSoon`, `ensureWritable`, `writeDecision`, `writeRequests` undefined.

- [ ] **Step 3: Implement**

`lib/features/library/domain/library_access.dart` — add to `LibraryAccess`:

```dart
  /// Asks to be allowed to change the owner's audio files, and answers
  /// whether it is.
  ///
  /// Asked for at one moment only: an autofill whose changes the owner has
  /// just confirmed. On the desktops there is nothing to ask.
  Future<LibraryAccessDecision> requestWrite();
```

`lib/features/library/data/permission_library_access.dart` — add:

```dart
  @override
  Future<LibraryAccessDecision> requestWrite() async {
    if (!platform.needsStoragePermission) return LibraryAccessDecision.granted;

    // Android 11 and later: changing a file this application did not create
    // takes all-files access, which is a settings screen rather than a
    // dialog. Below Android 11 the plugin answers it as restricted, and the
    // old write permission — declared up to API 29 — is what is asked for.
    final everything = await Permission.manageExternalStorage.request();
    if (everything.isGranted) return LibraryAccessDecision.granted;
    if (!everything.isRestricted) {
      _log.info('writing to audio files was refused');
      return LibraryAccessDecision.denied;
    }

    final storage = await Permission.storage.request();
    if (storage.isGranted) return LibraryAccessDecision.granted;

    return storage.isPermanentlyDenied
        ? LibraryAccessDecision.deniedPermanently
        : LibraryAccessDecision.denied;
  }
```

`LibraryAccessController` in `library_folders_controller.dart` — add:

```dart
  /// Asks to be allowed to change the owner's audio files.
  ///
  /// Not recorded in [state], which is about reading: a refusal to let tags be
  /// written says nothing about whether the library can be scanned.
  Future<LibraryAccessDecision> ensureWritable() =>
      ref.read(libraryAccessProvider).requestWrite();
```

`ScanController` in `scan_controller.dart` — add below `scan`:

```dart
  /// Scans again because files under the library were just changed by this
  /// application — an autofill writing tags.
  ///
  /// A scan already running may have passed those files, so it is owed another
  /// one whatever the folders say; otherwise one starts now. Access is not
  /// asked for: a library whose files were just written is one this process
  /// can read.
  Future<void> rescanSoon() async {
    if (state.isRunning || _asking) {
      _again = true;
      return;
    }

    await scan(askForAccess: false);
  }
```

`lib/core/di/providers.dart` — add imports and bindings (beside `remoteLyricsSourceProvider`, with doc comments in the file's voice):

```dart
import '../../features/autofill/data/audio_metadata_tag_writer.dart';
import '../../features/autofill/data/musicbrainz_source.dart';
import '../../features/autofill/domain/metadata_source.dart';
import '../../features/autofill/domain/tag_writer.dart';

/// Where autofilled tags come from.
///
/// One instance for the run, because it holds the throttle MusicBrainz asks
/// for: two of them would each keep to one request a second, and together
/// make two. Every test overrides it.
final metadataSourceProvider = Provider<MetadataSource>((ref) {
  final source = MusicBrainzSource(
    version: ref.watch(runningVersionProvider)?.toString(),
  );
  ref.onDispose(source.close);
  return source;
});

/// What reads and writes a file's tags for an autofill.
///
/// The one binding in this graph that writes into an audio file. Every test
/// overrides it.
final tagWriterProvider = Provider<TagWriter>(
  (ref) => const AudioMetadataTagWriter(),
);
```

`test/support/fakes.dart` — extend `FakeLibraryAccess`:

```dart
  /// What a request to write answers.
  LibraryAccessDecision writeDecision = LibraryAccessDecision.granted;

  /// How many times writing was asked for.
  int writeRequests = 0;

  @override
  Future<LibraryAccessDecision> requestWrite() async {
    writeRequests++;

    return writeDecision;
  }
```

`test/support/fake_autofill.dart`:

```dart
import 'dart:typed_data';

import 'package:orpheus/features/autofill/domain/autofill_field.dart';
import 'package:orpheus/features/autofill/domain/metadata_source.dart';
import 'package:orpheus/features/autofill/domain/release.dart';
import 'package:orpheus/features/autofill/domain/tag_writer.dart';
import 'package:orpheus/features/library/domain/audio_file.dart';

/// A [MetadataSource] answering what the test scripted, and recording what it
/// was asked.
class ScriptedMetadataSource implements MetadataSource {
  /// Releases each search answers.
  List<ReleaseCandidate> candidates = const [];

  /// Each release by id.
  Map<String, ReleaseDetail> releases = const {};

  /// Release-group genres by id.
  Map<String, List<Genre>> groupGenres = const {};

  /// Recordings each recording search answers.
  List<RecordingMatch> recordings = const [];

  /// Covers by release id.
  Map<String, Uint8List> covers = const {};

  /// What every call throws instead, where a test wants a failure.
  MetadataSourceFailure? failure;

  /// Held until completed, where a test wants a lookup in flight.
  Future<void>? hold;

  /// The release queries asked, in order.
  final List<ReleaseQuery> releaseQueries = [];

  /// The release ids looked up, in order.
  final List<String> lookedUp = [];

  /// The covers fetched, by release id.
  final List<String> coversFetched = [];

  Future<void> _gate() async {
    await hold;
    final thrown = failure;
    if (thrown != null) throw MetadataSourceException(thrown);
  }

  @override
  Future<List<ReleaseCandidate>> searchReleases(ReleaseQuery query) async {
    releaseQueries.add(query);
    await _gate();
    return candidates;
  }

  @override
  Future<ReleaseDetail> release(String id) async {
    lookedUp.add(id);
    await _gate();
    return releases[id]!;
  }

  @override
  Future<List<Genre>> releaseGroupGenres(String id) async {
    await _gate();
    return groupGenres[id] ?? const [];
  }

  @override
  Future<List<RecordingMatch>> searchRecordings(RecordingQuery query) async {
    await _gate();
    return recordings;
  }

  @override
  Future<Uint8List?> frontCover(String releaseId) async {
    coversFetched.add(releaseId);
    await _gate();
    return covers[releaseId];
  }
}

/// A [TagWriter] over a map of files, recording every write.
class FakeTagWriter implements TagWriter {
  /// What each path holds, and can hold.
  final Map<String, FileTags> files = {};

  /// What a write to a path answers instead of writing, where a test wants a
  /// refusal.
  final Map<String, WriteOutcome> refusals = {};

  /// Every write, in order: the path and what was written.
  final List<(String, Map<AutofillField, Object?>)> writes = [];

  @override
  Future<FileTags> inspect(String path) async => files[path] ?? FileTags.unwritable;

  @override
  Future<WriteOutcome> write(
    String path,
    Map<AutofillField, Object?> values, {
    required AudioFile expected,
  }) async {
    final refused = refusals[path];
    if (refused != null) return refused;

    writes.add((path, values));
    final current = files[path];
    if (current != null) {
      files[path] = FileTags(
        writable: current.writable,
        values: {...current.values, ...values}..remove(AutofillField.cover),
        cover: values[AutofillField.cover] as Uint8List? ?? current.cover,
      );
    }

    return WriteOutcome.written;
  }
}
```

`test/support/test_container.dart` — add constructor parameters `ScriptedMetadataSource? metadata, FakeTagWriter? tagWriter`, initialisers `metadata = metadata ?? ScriptedMetadataSource()`, `tagWriter = tagWriter ?? FakeTagWriter()`, fields `final ScriptedMetadataSource metadata; final FakeTagWriter tagWriter;`, the import of `fake_autofill.dart`, and two overrides beside the release source ones:

```dart
        // The third thing that reaches a network, and the one thing in this
        // application that writes into an audio file. No test does either.
        metadataSourceProvider.overrideWithValue(this.metadata),
        tagWriterProvider.overrideWithValue(this.tagWriter),
```

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/features/library` then `flutter analyze` then `flutter test`
Expected: all pass. Any other class implementing `LibraryAccess` (search: `grep -rn "implements LibraryAccess" lib test`) must gain `requestWrite`.

- [ ] **Step 5: Commit**

```bash
git add lib/core/di/providers.dart lib/features/library test/support test/features/library
git commit -m "feat: bind autofill and ask before writing files"
```

---

### Task 10: The autofill controller

**Files:**
- Create: `lib/features/autofill/application/autofill_controller.dart`
- Modify: `lib/core/di/providers.dart` (add `autofillControllerProvider`)
- Test: `test/features/autofill/application/autofill_controller_test.dart`

**Interfaces:**
- Consumes: Tasks 1–4 (domain), 9 (`metadataSourceProvider`, `tagWriterProvider`, `ensureWritable`, `rescanSoon`), `audioPlaybackControllerProvider` (current track), `settingsStoreProvider`.
- Produces:
  - `enum AutofillStage { idle, searching, reviewing, writing, finished, failed }`
  - `enum AutofillKind { record, track }`
  - `class AutofillState { AutofillStage stage; AutofillKind kind; Set<AutofillField> fields; String query; List<ReleaseCandidate> candidates; ReleaseDetail? release; List<FileProposal> proposals; int written; int total; Map<String, WriteOutcome> outcomes; MetadataSourceFailure? failure; LibraryAccessDecision? refusal; bool coverMissing; int get acceptedCount; int get filesWithChanges; }`
  - `class AutofillController extends Notifier<AutofillState>` with `static const String fieldsSettingsKey = 'autofillFields'`, `Set<AutofillField> rememberedFields()`, `Future<void> start(List<MusicEntry> entries, Set<AutofillField> fields, {required AutofillKind kind})`, `Future<void> search(String text)`, `Future<void> chooseRelease(String id)`, `void toggle(String path, AutofillField field)`, `void toggleFile(String path, bool accepted)`, `void toggleAll(bool accepted)`, `Future<void> write()`, `void cancel()`, `Future<void> retry()`.
  - `final autofillControllerProvider = NotifierProvider<AutofillController, AutofillState>(AutofillController.new, isAutoDispose: true);`

- [ ] **Step 1: Write the failing tests** — `test/features/autofill/application/autofill_controller_test.dart`:

```dart
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/core/di/providers.dart';
import 'package:orpheus/features/autofill/application/autofill_controller.dart';
import 'package:orpheus/features/autofill/domain/autofill_field.dart';
import 'package:orpheus/features/autofill/domain/metadata_source.dart';
import 'package:orpheus/features/autofill/domain/release.dart';
import 'package:orpheus/features/autofill/domain/tag_writer.dart';
import 'package:orpheus/features/library/domain/library_access.dart';

import '../../../support/entries.dart';
import '../../../support/fakes.dart';
import '../../../support/test_container.dart';

/// Search, review, write, rescan — with every edge doubled.
void main() {
  final record = [
    entry(id: 'ok1', title: 'Airbag', artist: 'Radiohed', album: 'OK Computer', track: 1),
    entry(id: 'ok2', title: 'Paranoid Android', artist: 'Radiohed', album: 'OK Computer', track: 2),
  ];

  const candidate = ReleaseCandidate(
    id: 'rel-1',
    title: 'OK Computer',
    artistCredit: [ArtistCredit(name: 'Radiohead')],
    trackCount: 2,
    status: 'Official',
    date: '1997',
  );
  const other = ReleaseCandidate(
    id: 'rel-2',
    title: 'OK Computer (Remastered)',
    artistCredit: [ArtistCredit(name: 'Radiohead')],
    trackCount: 2,
    status: 'Official',
    date: '2009',
  );

  ReleaseDetail detailOf(ReleaseCandidate release) => ReleaseDetail(
    release: release,
    tracks: const [
      ReleaseTrack(disc: 1, position: 1, title: 'Airbag', artistCredit: [ArtistCredit(name: 'Radiohead')]),
      ReleaseTrack(disc: 1, position: 2, title: 'Paranoid Android', artistCredit: [ArtistCredit(name: 'Radiohead')]),
    ],
  );

  Harness harnessFor({FakeLibraryAccess? access, ScriptedScanner? scanner}) {
    final harness = Harness(
      library: record,
      access: access,
      scanner: scanner,
      settings: InMemorySettingsStore(libraryFolders: const ['/music']),
    );
    harness.metadata
      ..candidates = const [candidate, other]
      ..releases = {'rel-1': detailOf(candidate), 'rel-2': detailOf(other)};
    for (final e in record) {
      harness.tagWriter.files[e.file.path] = FileTags(
        writable: AutofillField.values.toSet(),
        values: {AutofillField.title: e.title, AutofillField.artist: 'Radiohed', AutofillField.album: 'OK Computer'},
      );
    }

    return harness;
  }

  AutofillController controllerOf(Harness harness) {
    // Kept alive for the test, as the review screen keeps it alive.
    harness.container.listen(autofillControllerProvider, (_, _) {});

    return harness.read(autofillControllerProvider.notifier);
  }

  AutofillState stateOf(Harness harness) => harness.read(autofillControllerProvider);

  test('GivenARecord_WhenAnAutofillStarts_ThenTheBestReleaseIsChosenAndOnlyRealChangesAreProposed', () async {
    final harness = harnessFor();

    await controllerOf(harness).start(record, {AutofillField.artist}, kind: AutofillKind.record);

    final state = stateOf(harness);
    expect(state.stage, AutofillStage.reviewing);
    expect(state.release?.release.id, 'rel-1');
    expect(harness.metadata.lookedUp, ['rel-1']);
    expect(state.acceptedCount, 2);
    expect(state.filesWithChanges, 2);
    expect(state.query, 'OK Computer Radiohed');
  });

  test('GivenTheOwnerPicksAnotherRelease_WhenItIsChosen_ThenItIsFetchedAndTheProposalsRebuilt', () async {
    final harness = harnessFor();
    final controller = controllerOf(harness);
    await controller.start(record, {AutofillField.album}, kind: AutofillKind.record);
    expect(stateOf(harness).acceptedCount, 0);

    await controller.chooseRelease('rel-2');

    expect(stateOf(harness).release?.release.id, 'rel-2');
    expect(stateOf(harness).acceptedCount, 2);
  });

  test('GivenTheOwnerUnticksAChange_WhenTheyWrite_ThenOnlyTheTickedOnesAreWrittenAndTheLibraryRescanned', () async {
    final harness = harnessFor();
    final controller = controllerOf(harness);
    await controller.start(record, {AutofillField.artist}, kind: AutofillKind.record);
    controller.toggle(record.first.file.path, AutofillField.artist);

    await controller.write();

    expect(harness.tagWriter.writes, hasLength(1));
    expect(harness.tagWriter.writes.single.$1, record[1].file.path);
    expect(harness.tagWriter.writes.single.$2, {AutofillField.artist: 'Radiohead'});
    expect(stateOf(harness).stage, AutofillStage.finished);
    expect(stateOf(harness).outcomes[record[1].file.path], WriteOutcome.written);
  });

  test('GivenNoNetwork_WhenAnAutofillStarts_ThenItFailsAsUnreachable', () async {
    final harness = harnessFor();
    harness.metadata.failure = MetadataSourceFailure.unreachable;

    await controllerOf(harness).start(record, {AutofillField.artist}, kind: AutofillKind.record);

    expect(stateOf(harness).stage, AutofillStage.failed);
    expect(stateOf(harness).failure, MetadataSourceFailure.unreachable);
  });

  test('GivenNothingIsFound_WhenAnAutofillStarts_ThenItReviewsNothingWithTheQueryEditable', () async {
    final harness = harnessFor();
    harness.metadata.candidates = const [];

    await controllerOf(harness).start(record, {AutofillField.artist}, kind: AutofillKind.record);

    expect(stateOf(harness).stage, AutofillStage.reviewing);
    expect(stateOf(harness).release, isNull);
    expect(stateOf(harness).candidates, isEmpty);
  });

  test('GivenTheOwnersOwnWords_WhenTheySearchAgain_ThenTheirWordsAreSent', () async {
    final harness = harnessFor();
    final controller = controllerOf(harness);
    await controller.start(record, {AutofillField.artist}, kind: AutofillKind.record);

    await controller.search('radiohead ok computer');

    expect(harness.metadata.releaseQueries.last.text, 'radiohead ok computer');
  });

  test('GivenTheOwnerRefusesWriteAccess_WhenTheyWrite_ThenNothingIsWrittenAndTheRefusalIsShown', () async {
    final access = FakeLibraryAccess()..writeDecision = LibraryAccessDecision.denied;
    final harness = harnessFor(access: access);
    final controller = controllerOf(harness);
    await controller.start(record, {AutofillField.artist}, kind: AutofillKind.record);

    await controller.write();

    expect(harness.tagWriter.writes, isEmpty);
    expect(stateOf(harness).stage, AutofillStage.reviewing);
    expect(stateOf(harness).refusal, LibraryAccessDecision.denied);
  });

  test('GivenOneFileIsRefused_WhenWritten_ThenTheOthersAreWrittenAndItCanBeRetried', () async {
    final harness = harnessFor();
    harness.tagWriter.refusals[record.first.file.path] = WriteOutcome.inUse;
    final controller = controllerOf(harness);
    await controller.start(record, {AutofillField.artist}, kind: AutofillKind.record);

    await controller.write();
    expect(stateOf(harness).outcomes[record.first.file.path], WriteOutcome.inUse);
    expect(stateOf(harness).outcomes[record[1].file.path], WriteOutcome.written);

    harness.tagWriter.refusals.clear();
    await controller.retry();

    expect(stateOf(harness).outcomes[record.first.file.path], WriteOutcome.written);
    expect(harness.tagWriter.writes, hasLength(2));
  });

  test('GivenTheCoverIsChosen_WhenTheReleaseHasOne_ThenItIsFetchedOnceAndProposedForEveryFile', () async {
    final harness = harnessFor();
    harness.metadata.covers = {'rel-1': Uint8List.fromList([9, 9])};

    await controllerOf(harness).start(record, {AutofillField.cover}, kind: AutofillKind.record);

    expect(harness.metadata.coversFetched, ['rel-1']);
    expect(stateOf(harness).acceptedCount, 2);
  });

  test('GivenTheCoverWillNotDownload_WhenProposed_ThenTheOtherChangesStandAndTheOwnerIsTold', () async {
    final harness = harnessFor();
    final controller = controllerOf(harness);
    harness.metadata.covers = const {};

    await controller.start(record, {AutofillField.cover, AutofillField.artist}, kind: AutofillKind.record);

    expect(stateOf(harness).coverMissing, isTrue);
    expect(stateOf(harness).acceptedCount, 2);
  });

  test('GivenTheOwnerClosesTheScreenMidLookup_WhenTheAnswerArrives_ThenNothingThrows', () async {
    // Review focus: an auto-disposed controller must not write state after
    // it is gone.
    final harness = harnessFor();
    final held = Completer<void>();
    harness.metadata.hold = held.future;
    final subscription = harness.container.listen(autofillControllerProvider, (_, _) {});
    final controller = harness.read(autofillControllerProvider.notifier);

    final started = controller.start(record, {AutofillField.artist}, kind: AutofillKind.record);
    subscription.close();
    await Future<void>.delayed(Duration.zero);
    held.complete();

    await expectLater(started, completes);
  });

  test('GivenAChoiceOfFields_WhenAnAutofillStarts_ThenItIsRememberedForTheNextOne', () async {
    final harness = harnessFor();

    await controllerOf(harness).start(record, {AutofillField.genre, AutofillField.cover}, kind: AutofillKind.record);

    expect(
      AutofillField.decode(harness.settings.getString(AutofillController.fieldsSettingsKey)),
      {AutofillField.genre, AutofillField.cover},
    );
  });

  test('GivenWritesFinish_WhenTheyDo_ThenTheLibraryIsRescanned', () async {
    final scanner = ScriptedScanner([
      ScanCompleted(
        catalog: MusicCatalog(entries: albumArtistsAcross(record)),
        report: const ScanReport(tracks: 2, added: 0, updated: 2, removed: 0, reused: 0),
      ),
    ]);
    final harness = harnessFor(scanner: scanner);
    final controller = controllerOf(harness);
    await controller.start(record, {AutofillField.artist}, kind: AutofillKind.record);

    await controller.write();
    await Future<void>.delayed(Duration.zero);

    expect(scanner.requests, hasLength(1));
  });
}
```

Add to the imports: `package:orpheus/core/settings/in_memory_settings_store.dart`, `package:orpheus/features/library/domain/library_scan.dart`, `.../music_catalog.dart` and `.../music_grouping.dart`.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/autofill/application/autofill_controller_test.dart`
Expected: compilation errors — the controller does not exist.

- [ ] **Step 3: Implement** — `lib/features/autofill/application/autofill_controller.dart`:

```dart
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../../core/di/providers.dart';
import '../../library/domain/library_access.dart';
import '../../library/domain/music_entry.dart';
import '../domain/autofill_field.dart';
import '../domain/matching.dart';
import '../domain/metadata_source.dart';
import '../domain/proposals.dart';
import '../domain/release.dart';
import '../domain/tag_writer.dart';

/// Where an autofill is.
enum AutofillStage {
  /// Not started.
  idle,

  /// Looking the record up.
  searching,

  /// Showing the owner what would change.
  reviewing,

  /// Writing what they confirmed.
  writing,

  /// Done; [AutofillState.outcomes] says how each file went.
  finished,

  /// The lookup could not run; [AutofillState.failure] says why.
  failed,
}

/// What an autofill was started on.
enum AutofillKind {
  /// A record, matched as a release.
  record,

  /// A lone track, matched as a recording.
  track,
}

/// One autofill session.
class AutofillState {
  /// Creates a state.
  const AutofillState({
    this.stage = AutofillStage.idle,
    this.kind = AutofillKind.record,
    this.fields = const {},
    this.query = '',
    this.candidates = const [],
    this.release,
    this.proposals = const [],
    this.written = 0,
    this.total = 0,
    this.outcomes = const {},
    this.failure,
    this.refusal,
    this.coverMissing = false,
  });

  /// Where it is.
  final AutofillStage stage;

  /// What it was started on.
  final AutofillKind kind;

  /// The tags the owner chose.
  final Set<AutofillField> fields;

  /// The search as the owner can see and edit it.
  final String query;

  /// Every release on offer, best first.
  final List<ReleaseCandidate> candidates;

  /// The release proposed from, or `null` where nothing was found.
  final ReleaseDetail? release;

  /// What would change, file by file.
  final List<FileProposal> proposals;

  /// How many files have been written so far.
  final int written;

  /// How many are being written.
  final int total;

  /// How each written file went, by path.
  final Map<String, WriteOutcome> outcomes;

  /// Why the lookup failed, where it did.
  final MetadataSourceFailure? failure;

  /// Why nothing was written, where the owner refused access.
  final LibraryAccessDecision? refusal;

  /// Whether the cover was chosen and the release had none to give.
  final bool coverMissing;

  /// How many changes are ticked.
  int get acceptedCount =>
      proposals.fold(0, (sum, proposal) => sum + proposal.acceptedCount);

  /// How many files have a ticked change.
  int get filesWithChanges =>
      proposals.where((proposal) => proposal.acceptedCount > 0).length;

  /// A copy with the given changes. [failure] and [refusal] clear unless
  /// passed: each describes one moment.
  AutofillState copyWith({
    AutofillStage? stage,
    AutofillKind? kind,
    Set<AutofillField>? fields,
    String? query,
    List<ReleaseCandidate>? candidates,
    ReleaseDetail? release,
    bool clearRelease = false,
    List<FileProposal>? proposals,
    int? written,
    int? total,
    Map<String, WriteOutcome>? outcomes,
    MetadataSourceFailure? failure,
    LibraryAccessDecision? refusal,
    bool? coverMissing,
  }) => AutofillState(
    stage: stage ?? this.stage,
    kind: kind ?? this.kind,
    fields: fields ?? this.fields,
    query: query ?? this.query,
    candidates: candidates ?? this.candidates,
    release: clearRelease ? null : release ?? this.release,
    proposals: proposals ?? this.proposals,
    written: written ?? this.written,
    total: total ?? this.total,
    outcomes: outcomes ?? this.outcomes,
    failure: failure,
    refusal: refusal,
    coverMissing: coverMissing ?? this.coverMissing,
  );
}

/// Looks a record or a track up, proposes its tags, and writes the ones the
/// owner confirms.
///
/// Auto-disposed: it lives exactly as long as the review screen watching it.
/// Every await is followed by a check that it still does, because the owner
/// can close the screen while MusicBrainz is still answering.
class AutofillController extends Notifier<AutofillState> {
  static final Logger _log = Logger('autofill');

  /// The settings key the last choice of tags is kept under.
  static const String fieldsSettingsKey = 'autofillFields';

  List<MusicEntry> _entries = const [];
  Map<String, FileTags> _tags = const {};
  String? _recordingId;
  bool _cancelled = false;

  @override
  AutofillState build() => const AutofillState();

  /// The tags the owner chose last time, or the defaults.
  Set<AutofillField> rememberedFields() => AutofillField.decode(
    ref.read(settingsStoreProvider).getString(fieldsSettingsKey),
  );

  /// Starts an autofill of [entries] for [fields].
  Future<void> start(
    List<MusicEntry> entries,
    Set<AutofillField> fields, {
    required AutofillKind kind,
  }) async {
    _entries = entries;
    unawaited(_remember(fields));

    final text = kind == AutofillKind.record
        ? _join(releaseQueryFor(entries).album, releaseQueryFor(entries).artist)
        : _join(recordingQueryFor(entries.single).title, recordingQueryFor(entries.single).artist);

    state = AutofillState(stage: AutofillStage.searching, kind: kind, fields: fields, query: text);

    final writer = ref.read(tagWriterProvider);
    final tags = <String, FileTags>{};
    for (final entry in entries) {
      tags[entry.file.path] = await writer.inspect(entry.file.path);
      if (!ref.mounted) return;
    }
    _tags = tags;

    await _lookUp(null);
  }

  /// Searches again with the owner's own [text].
  Future<void> search(String text) async {
    state = state.copyWith(stage: AutofillStage.searching, query: text);
    await _lookUp(text.trim().isEmpty ? null : text.trim());
  }

  /// Proposes from the candidate [id] instead.
  Future<void> chooseRelease(String id) async {
    state = state.copyWith(stage: AutofillStage.searching);
    await _propose(id);
  }

  /// Ticks or unticks one change.
  void toggle(String path, AutofillField field) => _edit(
    (proposal) => proposal.entry.file.path != path
        ? proposal
        : proposal.withChanges([
            for (final change in proposal.changes)
              change.field == field ? change.withAccepted(!change.accepted) : change,
          ]),
  );

  /// Ticks or unticks every change of one file.
  void toggleFile(String path, bool accepted) => _edit(
    (proposal) => proposal.entry.file.path != path
        ? proposal
        : proposal.withChanges([for (final c in proposal.changes) c.withAccepted(accepted)]),
  );

  /// Ticks or unticks every change.
  void toggleAll(bool accepted) => _edit(
    (proposal) => proposal.withChanges([for (final c in proposal.changes) c.withAccepted(accepted)]),
  );

  /// Writes every ticked change, then rescans.
  Future<void> write() => _writeFiles(
    [for (final p in state.proposals) if (p.acceptedCount > 0) p],
  );

  /// Writes again the files that were in use or failed.
  Future<void> retry() => _writeFiles([
    for (final p in state.proposals)
      if (p.acceptedCount > 0 &&
          (state.outcomes[p.entry.file.path] == WriteOutcome.inUse ||
              state.outcomes[p.entry.file.path] == WriteOutcome.failed))
        p,
  ], keep: state.outcomes);

  /// Stops after the file being written.
  void cancel() => _cancelled = true;

  Future<void> _lookUp(String? text) async {
    final source = ref.read(metadataSourceProvider);

    try {
      if (state.kind == AutofillKind.record) {
        final query = releaseQueryFor(_entries);
        final found = await source.searchReleases(
          text == null ? query : ReleaseQuery(text: text),
        );
        if (!ref.mounted) return;

        final ranked = rankCandidates(found, fileCount: _entries.length, album: query.album, artist: query.artist);
        state = state.copyWith(candidates: ranked);
        if (ranked.isEmpty) {
          state = state.copyWith(stage: AutofillStage.reviewing, clearRelease: true, proposals: const []);
          return;
        }

        await _propose(ranked.first.id);
      } else {
        final query = recordingQueryFor(_entries.single);
        final found = await source.searchRecordings(
          text == null ? query : RecordingQuery(text: text),
        );
        if (!ref.mounted) return;

        final appearances = rankAppearances(found, title: query.title, artist: query.artist);
        _recordingId = found.firstOrNull?.recordingId;
        final ranked = [for (final a in appearances) a.release];
        state = state.copyWith(candidates: ranked);
        if (ranked.isEmpty) {
          state = state.copyWith(stage: AutofillStage.reviewing, clearRelease: true, proposals: const []);
          return;
        }

        await _propose(ranked.first.id);
      }
    } on MetadataSourceException catch (error) {
      if (!ref.mounted) return;
      state = state.copyWith(stage: AutofillStage.failed, failure: error.kind);
    }
  }

  Future<void> _propose(String releaseId) async {
    final source = ref.read(metadataSourceProvider);

    try {
      final detail = await source.release(releaseId);
      if (!ref.mounted) return;

      var fallback = const <Genre>[];
      final groupId = detail.releaseGroupId;
      if (state.fields.contains(AutofillField.genre) && detail.genres.isEmpty && groupId != null) {
        fallback = await source.releaseGroupGenres(groupId);
        if (!ref.mounted) return;
      }

      Uint8List? cover;
      if (state.fields.contains(AutofillField.cover)) {
        try {
          cover = await source.frontCover(releaseId);
        } on MetadataSourceException catch (error) {
          _log.info('the cover could not be fetched', error);
        }
        if (!ref.mounted) return;
      }

      final assignment = state.kind == AutofillKind.track
          ? _assignLoneTrack(detail)
          : assignTracks(_entries, detail);

      state = state.copyWith(
        stage: AutofillStage.reviewing,
        release: detail,
        coverMissing: state.fields.contains(AutofillField.cover) && cover == null,
        proposals: proposalsFor(
          assignment: assignment,
          release: detail,
          fields: state.fields,
          tags: _tags,
          fallbackGenres: fallback,
          cover: cover,
        ),
      );
    } on MetadataSourceException catch (error) {
      if (!ref.mounted) return;
      state = state.copyWith(stage: AutofillStage.failed, failure: error.kind);
    }
  }

  /// The lone track's place on [detail]: the recording it was matched as,
  /// else whatever the record-wide rules find.
  Map<MusicEntry, ReleaseTrack?> _assignLoneTrack(ReleaseDetail detail) {
    final entry = _entries.single;
    final byRecording = detail.tracks.where((t) => t.recordingId != null && t.recordingId == _recordingId).firstOrNull;

    return byRecording != null ? {entry: byRecording} : assignTracks(_entries, detail);
  }

  Future<void> _writeFiles(List<FileProposal> chosen, {Map<String, WriteOutcome> keep = const {}}) async {
    if (chosen.isEmpty) return;

    final access = await ref.read(libraryAccessControllerProvider.notifier).ensureWritable();
    if (!ref.mounted) return;
    if (!access.isGranted) {
      state = state.copyWith(stage: AutofillStage.reviewing, refusal: access);
      return;
    }

    // The track playing last: on Windows the player holds it open and the
    // write may be refused, and everything else should be done by then.
    final playing = ref.read(audioPlaybackControllerProvider).current?.path;
    final ordered = [
      ...chosen.where((p) => p.entry.file.path != playing),
      ...chosen.where((p) => p.entry.file.path == playing),
    ];

    _cancelled = false;
    final outcomes = {...keep};
    state = state.copyWith(stage: AutofillStage.writing, written: 0, total: ordered.length, outcomes: outcomes);

    final writer = ref.read(tagWriterProvider);
    var done = 0;
    var any = false;
    for (final proposal in ordered) {
      if (_cancelled) break;

      final path = proposal.entry.file.path;
      final outcome = await writer.write(
        path,
        {for (final c in proposal.changes) if (c.accepted) c.field: c.after},
        expected: proposal.entry.file,
      );
      outcomes[path] = outcome;
      any = any || outcome == WriteOutcome.written;
      done++;
      if (!ref.mounted) break;
      state = state.copyWith(written: done, outcomes: {...outcomes});
    }

    if (any) unawaited(ref.read(scanControllerProvider.notifier).rescanSoon());
    if (!ref.mounted) return;

    state = state.copyWith(stage: AutofillStage.finished, outcomes: {...outcomes});
  }

  void _edit(FileProposal Function(FileProposal proposal) edit) {
    state = state.copyWith(proposals: [for (final p in state.proposals) edit(p)]);
  }

  Future<void> _remember(Set<AutofillField> fields) async {
    try {
      await ref.read(settingsStoreProvider).setString(fieldsSettingsKey, AutofillField.encode(fields));
    } on Object catch (error) {
      _log.fine('the autofill choice could not be saved', error);
    }
  }

  static String _join(String? a, String? b) => [?a, ?b].where((s) => s.trim().isNotEmpty).join(' ');
}
```

Add to `providers.dart`:

```dart
import '../../features/autofill/application/autofill_controller.dart';

/// One autofill session, from search to written files.
///
/// Auto-disposed: it lives as long as the review screen watching it, so a
/// closed screen is a forgotten session.
final autofillControllerProvider =
    NotifierProvider<AutofillController, AutofillState>(
      AutofillController.new,
      isAutoDispose: true,
    );
```

The `rescanSoon` call is deliberately not awaited: the rescan can take a while and is reported by the scan strip, not by this screen.

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/features/autofill/application` then `flutter analyze` then `flutter test`
Expected: all pass. If `ref.mounted` is unavailable in this Riverpod version, check `ref` on a `Notifier` in `flutter_riverpod 3.4.3` for the equivalent (`ref.mounted` exists from Riverpod 3.0); do not catch `StateError` as a substitute.

- [ ] **Step 5: Commit**

```bash
git add lib/features/autofill/application lib/core/di/providers.dart test/features/autofill/application
git commit -m "feat: drive an autofill from search to write"
```

---

### Task 11: Strings, the field dialog and the entry points

**Files:**
- Modify: `lib/core/l10n/app_en.arb`, `lib/core/l10n/app_pt.arb` (then `flutter gen-l10n`), `lib/features/playback/presentation/music_rows.dart`
- Create: `lib/features/autofill/presentation/autofill_field_names.dart`, `lib/features/autofill/presentation/autofill_fields_dialog.dart`, `lib/features/autofill/presentation/autofill_launcher.dart`
- Test: `test/features/autofill/presentation/autofill_fields_dialog_test.dart`

**Interfaces:**
- Consumes: Task 10's controller (`rememberedFields`), Task 1's `canWriteTagsTo`.
- Produces: `String autofillFieldName(AppLocalizations l10n, AutofillField field)`; `class AutofillFieldsDialog { static Future<Set<AutofillField>?> ask(BuildContext context, {required Set<AutofillField> initial, required bool anyWritable}); }`; `Future<void> startAutofill(BuildContext context, WidgetRef ref, List<MusicEntry> entries, {required AutofillKind kind})` — Task 12 provides `AutofillScreen`, so the launcher's `Navigator.push` of it is added in Task 12, Step 4.

- [ ] **Step 1: Add the strings** — to `app_en.arb` (and the same keys in `app_pt.arb` with the Portuguese below), each with an `@` entry carrying a `description`:

| Key | English | Portuguese (pt-BR) | Placeholders |
| --- | --- | --- | --- |
| `autofillAction` | `Autofill tags…` | `Preencher tags…` | |
| `autofillFieldsTitle` | `Fill which tags?` | `Preencher quais tags?` | |
| `autofillFind` | `Find` | `Buscar` | |
| `autofillNothingWritable` | `Orpheus can only change the tags of MP3, FLAC, M4A, WAV and APE files.` | `O Orpheus só altera tags de arquivos MP3, FLAC, M4A, WAV e APE.` | |
| `autofillCoverNote` | `Downloads the cover from the Cover Art Archive and stores it in each file.` | `Baixa a capa do Cover Art Archive e a guarda em cada arquivo.` | |
| `autofillFieldTitle` | `Title` | `Título` | |
| `autofillFieldArtist` | `Artist` | `Artista` | |
| `autofillFieldAlbumArtist` | `Album artist` | `Artista do álbum` | |
| `autofillFieldAlbum` | `Album` | `Álbum` | |
| `autofillFieldTrackNumber` | `Track number` | `Número da faixa` | |
| `autofillFieldTrackTotal` | `Track total` | `Total de faixas` | |
| `autofillFieldDiscNumber` | `Disc number` | `Número do disco` | |
| `autofillFieldDiscTotal` | `Disc total` | `Total de discos` | |
| `autofillFieldYear` | `Year` | `Ano` | |
| `autofillFieldGenre` | `Genre` | `Gênero` | |
| `autofillFieldCover` | `Cover art` | `Capa` | |
| `autofillSearching` | `Looking this up on MusicBrainz…` | `Buscando no MusicBrainz…` | |
| `autofillUnreachable` | `MusicBrainz could not be reached.` | `Não foi possível acessar o MusicBrainz.` | |
| `autofillRateLimited` | `MusicBrainz is busy. Try again in a moment.` | `O MusicBrainz está ocupado. Tente de novo em instantes.` | |
| `autofillTryAgain` | `Try again` | `Tentar de novo` | |
| `autofillNothingFound` | `Nothing found on MusicBrainz.` | `Nada encontrado no MusicBrainz.` | |
| `autofillSearchLabel` | `Search MusicBrainz` | `Buscar no MusicBrainz` | |
| `autofillSearchAgain` | `Search again` | `Buscar de novo` | |
| `autofillDifferentRelease` | `Different release` | `Outro lançamento` | |
| `autofillWrite` | `Write {changes, plural, =1{1 change} other{{changes} changes}} to {files, plural, =1{1 file} other{{files} files}}` | `Gravar {changes, plural, =1{1 alteração} other{{changes} alterações}} em {files, plural, =1{1 arquivo} other{{files} arquivos}}` | `changes: int`, `files: int` |
| `autofillTickAll` | `Tick all` | `Marcar tudo` | |
| `autofillUntickAll` | `Untick all` | `Desmarcar tudo` | |
| `autofillNoChanges` | `Already matches` | `Já está igual` | |
| `autofillNoMatch` | `No match on this release` | `Sem correspondência neste lançamento` | |
| `autofillUnwritable` | `Orpheus can't change this kind of file` | `O Orpheus não altera este tipo de arquivo` | |
| `autofillNotWritableFields` | `This kind of file can't hold: {fields}` | `Este tipo de arquivo não comporta: {fields}` | `fields: String` |
| `autofillCoverMissing` | `This release has no cover on the Cover Art Archive.` | `Este lançamento não tem capa no Cover Art Archive.` | |
| `autofillWriting` | `Writing {done} of {total}…` | `Gravando {done} de {total}…` | `done: int`, `total: int` |
| `autofillCancel` | `Cancel` | `Cancelar` | |
| `autofillClose` | `Close` | `Fechar` | |
| `autofillWritten` | `{count, plural, =0{No files were updated.} =1{1 file updated.} other{{count} files updated.}}` | `{count, plural, =0{Nenhum arquivo atualizado.} =1{1 arquivo atualizado.} other{{count} arquivos atualizados.}}` | `count: int` |
| `autofillOutcomeChanged` | `Changed since Orpheus read it — not written` | `Alterado desde a leitura — não gravado` | |
| `autofillOutcomeInUse` | `In use by playback — try again once it has moved on` | `Em uso pela reprodução — tente de novo depois` | |
| `autofillOutcomeDenied` | `Orpheus isn't allowed to change it` | `O Orpheus não tem permissão para alterá-lo` | |
| `autofillOutcomeFailed` | `Could not be written` | `Não foi possível gravar` | |
| `autofillOutcomeUnsupported` | `Orpheus can't change this kind of file` | `O Orpheus não altera este tipo de arquivo` | |
| `autofillAccessRefused` | `Orpheus needs permission to change your music files. Nothing was written.` | `O Orpheus precisa de permissão para alterar seus arquivos de música. Nada foi gravado.` | |
| `autofillOpenSettings` | `Open settings` | `Abrir configurações` | |

Each `@key` description says where the string appears (e.g. `"The action that fills a record's tags from MusicBrainz."`). Then run:

```bash
flutter gen-l10n
flutter test test/core/l10n
```

Expected: generation succeeds; the parity test passes. If gen-l10n rejects the two plurals in `autofillWrite`, split it into `autofillWriteChanges` (`Write {changes, plural, …}`) and `autofillToFiles` (`to {files, plural, …}`) and join them in the widget with a space.

- [ ] **Step 2: Write the failing widget tests** — `test/features/autofill/presentation/autofill_fields_dialog_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/autofill/domain/autofill_field.dart';
import 'package:orpheus/features/autofill/presentation/autofill_fields_dialog.dart';

import '../../../support/pump.dart';
import '../../../support/test_container.dart';

/// Choosing which tags to fill.
void main() {
  Set<AutofillField>? chosen;

  Future<void> open(WidgetTester tester, {Set<AutofillField>? initial, bool anyWritable = true}) async {
    chosen = null;
    await tester.pumpHarness(
      Harness(),
      Builder(
        builder: (context) => TextButton(
          onPressed: () async => chosen = await AutofillFieldsDialog.ask(
            context,
            initial: initial ?? AutofillField.defaults,
            anyWritable: anyWritable,
          ),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('GivenTheDefaults_WhenTheDialogOpens_ThenEveryTagButTheCoverIsTicked', (tester) async {
    await open(tester);

    CheckboxListTile tile(String label) =>
        tester.widget<CheckboxListTile>(find.widgetWithText(CheckboxListTile, label));
    expect(tile('Artist').value, isTrue);
    expect(tile('Cover art').value, isFalse);
  });

  testWidgets('GivenTheOwnerTicksTheCover_WhenTheyFind_ThenTheirChoiceComesBack', (tester) async {
    await open(tester, initial: {AutofillField.artist});

    await tester.tap(find.widgetWithText(CheckboxListTile, 'Cover art'));
    await tester.pump();
    await tester.tap(find.text('Find'));
    await tester.pumpAndSettle();

    expect(chosen, {AutofillField.artist, AutofillField.cover});
  });

  testWidgets('GivenEveryTagIsUnticked_WhenTheDialogShows_ThenFindIsDisabled', (tester) async {
    await open(tester, initial: {AutofillField.artist});

    await tester.tap(find.widgetWithText(CheckboxListTile, 'Artist'));
    await tester.pump();

    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Find')).onPressed, isNull);
  });

  testWidgets('GivenNoFileCanBeWritten_WhenTheDialogOpens_ThenItSaysSoAndOffersNothingToFind', (tester) async {
    await open(tester, anyWritable: false);

    expect(find.textContaining('MP3, FLAC, M4A, WAV and APE'), findsOneWidget);
    expect(find.text('Find'), findsNothing);
  });
}
```

Check `test/support/pump.dart` for the exact `pumpHarness` signature first; it is what the update prompt tests use.

- [ ] **Step 3: Run to verify failure**

Run: `flutter test test/features/autofill/presentation`
Expected: compilation errors.

- [ ] **Step 4: Implement**

`lib/features/autofill/presentation/autofill_field_names.dart`:

```dart
import '../../../core/l10n/generated/app_localizations.dart';
import '../domain/autofill_field.dart';

/// [field] as the owner reads it.
String autofillFieldName(AppLocalizations l10n, AutofillField field) => switch (field) {
  AutofillField.title => l10n.autofillFieldTitle,
  AutofillField.artist => l10n.autofillFieldArtist,
  AutofillField.albumArtist => l10n.autofillFieldAlbumArtist,
  AutofillField.album => l10n.autofillFieldAlbum,
  AutofillField.trackNumber => l10n.autofillFieldTrackNumber,
  AutofillField.trackTotal => l10n.autofillFieldTrackTotal,
  AutofillField.discNumber => l10n.autofillFieldDiscNumber,
  AutofillField.discTotal => l10n.autofillFieldDiscTotal,
  AutofillField.year => l10n.autofillFieldYear,
  AutofillField.genre => l10n.autofillFieldGenre,
  AutofillField.cover => l10n.autofillFieldCover,
};
```

`lib/features/autofill/presentation/autofill_fields_dialog.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../domain/autofill_field.dart';
import 'autofill_field_names.dart';

/// The checklist an autofill starts from.
class AutofillFieldsDialog extends StatefulWidget {
  const AutofillFieldsDialog._({required this.initial, required this.anyWritable});

  /// What is ticked when it opens.
  final Set<AutofillField> initial;

  /// Whether any file in the selection can be written. Where none can, the
  /// dialog says so and there is nothing to find: looking a record up only
  /// to say its files cannot be changed would be a request for nothing.
  final bool anyWritable;

  /// Asks which tags to fill; `null` when the owner cancels.
  static Future<Set<AutofillField>?> ask(
    BuildContext context, {
    required Set<AutofillField> initial,
    required bool anyWritable,
  }) => showDialog<Set<AutofillField>>(
    context: context,
    builder: (_) => AutofillFieldsDialog._(initial: initial, anyWritable: anyWritable),
  );

  @override
  State<AutofillFieldsDialog> createState() => _AutofillFieldsDialogState();
}

class _AutofillFieldsDialogState extends State<AutofillFieldsDialog> {
  late final Set<AutofillField> _chosen = {...widget.initial};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (!widget.anyWritable) {
      return AlertDialog(
        title: Text(l10n.autofillFieldsTitle),
        content: Text(l10n.autofillNothingWritable),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.autofillClose)),
        ],
      );
    }

    return AlertDialog(
      title: Text(l10n.autofillFieldsTitle),
      content: SizedBox(
        width: 360,
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final field in AutofillField.values)
              CheckboxListTile(
                dense: true,
                value: _chosen.contains(field),
                title: Text(autofillFieldName(l10n, field)),
                subtitle: field == AutofillField.cover ? Text(l10n.autofillCoverNote) : null,
                onChanged: (ticked) => setState(
                  () => ticked == true ? _chosen.add(field) : _chosen.remove(field),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.autofillCancel)),
        FilledButton(
          onPressed: _chosen.isEmpty ? null : () => Navigator.pop(context, {..._chosen}),
          child: Text(l10n.autofillFind),
        ),
      ],
    );
  }
}
```

`lib/features/autofill/presentation/autofill_launcher.dart` (completed in Task 12):

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../library/domain/music_entry.dart';
import '../application/autofill_controller.dart';
import '../domain/autofill_field.dart';
import '../domain/tag_writer.dart';
import 'autofill_fields_dialog.dart';

/// Asks which tags to fill, then opens the review screen for [entries].
Future<void> startAutofill(
  BuildContext context,
  WidgetRef ref,
  List<MusicEntry> entries, {
  required AutofillKind kind,
}) async {
  if (entries.isEmpty) return;

  // From the settings rather than from the controller: the controller is
  // auto-disposed, and the session it holds starts on the review screen.
  final remembered = AutofillField.decode(
    ref.read(settingsStoreProvider).getString(AutofillController.fieldsSettingsKey),
  );
  final fields = await AutofillFieldsDialog.ask(
    context,
    initial: remembered,
    anyWritable: entries.any((entry) => canWriteTagsTo(entry.file.path)),
  );
  if (fields == null || !context.mounted) return;

  // Task 12: push AutofillScreen(entries: entries, fields: fields, kind: kind).
}
```

`lib/features/playback/presentation/music_rows.dart`:
- In `_GroupActions.build`, for `kind == MusicGroupKind.album` only, add after the shuffle button:

```dart
        if (kind == MusicGroupKind.album)
          IconButton(
            tooltip: l10n.autofillAction,
            icon: const Icon(Icons.auto_fix_high_outlined),
            onPressed: () => unawaited(
              startAutofill(context, ref, group.entries, kind: AutofillKind.record),
            ),
          ),
```

- In `MusicRowMenu`'s `menuChildren`, after the last shuffle item:

```dart
        MenuItemButton(
          leadingIcon: const Icon(Icons.auto_fix_high_outlined),
          onPressed: () => unawaited(
            startAutofill(context, ref, [entry], kind: AutofillKind.track),
          ),
          child: Text(l10n.autofillAction),
        ),
```

with the imports of `autofill_launcher.dart` and `autofill_controller.dart` (for `AutofillKind`).

- [ ] **Step 5: Run to verify pass**

Run: `flutter test test/features/autofill/presentation test/features/playback/presentation test/core` then `flutter analyze` then `flutter test`
Expected: all pass (existing music-row tests still find their buttons; if one counts `IconButton`s in a group row, update its count and say why in the test).

- [ ] **Step 6: Commit**

```bash
git add lib/core/l10n lib/features/autofill/presentation lib/features/playback/presentation/music_rows.dart test/features/autofill/presentation
git commit -m "feat: offer autofill on records and tracks"
```

---

### Task 12: The review screen

**Files:**
- Create: `lib/features/autofill/presentation/autofill_screen.dart`
- Modify: `lib/features/autofill/presentation/autofill_launcher.dart` (push the screen)
- Test: `test/features/autofill/presentation/autofill_screen_test.dart`

**Interfaces:**
- Consumes: Task 10's state and actions, Task 11's strings and `autofillFieldName`.
- Produces: `class AutofillScreen extends ConsumerStatefulWidget { const AutofillScreen({required List<MusicEntry> entries, required Set<AutofillField> fields, required AutofillKind kind}); }`.

- [ ] **Step 1: Write the failing widget tests** — `test/features/autofill/presentation/autofill_screen_test.dart`. Copy into it, from Task 10's test file, the imports, `record`, `candidate`, `other`, `detailOf` and `harnessFor` (test fixtures, deliberately not shared code), add imports of `autofill_screen.dart` and `../../../support/pump.dart`, and put the tests below inside `main()`:

```dart
  Future<void> openScreen(WidgetTester tester, Harness harness, Set<AutofillField> fields) async {
    await tester.pumpHarness(
      harness,
      AutofillScreen(entries: record, fields: fields, kind: AutofillKind.record),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('GivenAMatch_WhenTheScreenShows_ThenEachChangeReadsOldToNewAndTheButtonCountsThem', (tester) async {
    final harness = harnessFor();

    await openScreen(tester, harness, {AutofillField.artist});

    expect(find.text('OK Computer'), findsWidgets);
    expect(find.text('Radiohed'), findsNWidgets(2));
    expect(find.text('Radiohead'), findsWidgets);
    expect(find.text('Write 2 changes to 2 files'), findsOneWidget);
  });

  testWidgets('GivenTheOwnerUnticksAChange_WhenTheyDo_ThenTheButtonCountsOneFewer', (tester) async {
    final harness = harnessFor();
    await openScreen(tester, harness, {AutofillField.artist});

    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();

    expect(find.text('Write 1 change to 1 file'), findsOneWidget);
  });

  testWidgets('GivenEveryChangeUnticked_WhenTheScreenShows_ThenWritingIsDisabled', (tester) async {
    final harness = harnessFor();
    await openScreen(tester, harness, {AutofillField.artist});

    await tester.tap(find.text('Untick all'));
    await tester.pump();

    final button = tester.widget<FilledButton>(find.ancestor(of: find.textContaining('Write'), matching: find.byType(FilledButton)));
    expect(button.onPressed, isNull);
  });

  testWidgets('GivenAnUnwritableFile_WhenTheScreenShows_ThenItIsNamedWithTheReasonAndHasNoCheckbox', (tester) async {
    final harness = harnessFor();
    harness.tagWriter.files[record.first.file.path] = FileTags.unwritable;

    await openScreen(tester, harness, {AutofillField.artist});

    expect(find.text("Orpheus can't change this kind of file"), findsOneWidget);
    expect(find.byType(Checkbox), findsNWidgets(1));
  });

  testWidgets('GivenTheOwnerWrites_WhenItFinishes_ThenTheSummarySaysHowManyAndNamesTheRefused', (tester) async {
    final harness = harnessFor();
    harness.tagWriter.refusals[record.first.file.path] = WriteOutcome.inUse;
    await openScreen(tester, harness, {AutofillField.artist});

    await tester.tap(find.text('Write 2 changes to 2 files'));
    await tester.pumpAndSettle();

    expect(find.text('1 file updated.'), findsOneWidget);
    expect(find.textContaining('In use by playback'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('GivenMusicBrainzCannotBeReached_WhenTheScreenShows_ThenItSaysSoAndOffersToTryAgain', (tester) async {
    final harness = harnessFor();
    harness.metadata.failure = MetadataSourceFailure.unreachable;

    await openScreen(tester, harness, {AutofillField.artist});

    expect(find.text('MusicBrainz could not be reached.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('GivenOtherCandidates_WhenTheOwnerPicksOne_ThenTheProposalsFollowIt', (tester) async {
    final harness = harnessFor();
    await openScreen(tester, harness, {AutofillField.album});

    await tester.tap(find.text('Different release'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('OK Computer (Remastered)').last);
    await tester.pumpAndSettle();

    expect(harness.metadata.lookedUp.last, 'rel-2');
    expect(find.text('Write 2 changes to 2 files'), findsOneWidget);
  });
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/autofill/presentation/autofill_screen_test.dart`
Expected: compilation error — `AutofillScreen` does not exist.

- [ ] **Step 3: Implement** — `lib/features/autofill/presentation/autofill_screen.dart`:

```dart
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../library/domain/library_access.dart';
import '../../library/domain/music_entry.dart';
import '../application/autofill_controller.dart';
import '../domain/autofill_field.dart';
import '../domain/metadata_source.dart';
import '../domain/proposals.dart';
import '../domain/release.dart';
import '../domain/tag_writer.dart';
import 'autofill_field_names.dart';

/// Where the owner sees every change an autofill would make, and confirms it.
class AutofillScreen extends ConsumerStatefulWidget {
  /// Creates the screen for [entries].
  const AutofillScreen({required this.entries, required this.fields, required this.kind, super.key});

  /// The files to fill.
  final List<MusicEntry> entries;

  /// The tags the owner chose.
  final Set<AutofillField> fields;

  /// A record or a lone track.
  final AutofillKind kind;

  @override
  ConsumerState<AutofillScreen> createState() => _AutofillScreenState();
}

class _AutofillScreenState extends ConsumerState<AutofillScreen> {
  final TextEditingController _query = TextEditingController();

  @override
  void initState() {
    super.initState();
    // After the first frame, so the controller is being watched — kept alive —
    // before the lookup starts.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        ref.read(autofillControllerProvider.notifier).start(widget.entries, widget.fields, kind: widget.kind),
      );
    });
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(autofillControllerProvider);
    final controller = ref.read(autofillControllerProvider.notifier);

    ref.listen(autofillControllerProvider.select((s) => s.query), (_, query) {
      if (_query.text != query) _query.text = query;
    });

    return Scaffold(
      appBar: AppBar(title: Text(l10n.autofillAction)),
      body: switch (state.stage) {
        AutofillStage.idle || AutofillStage.searching => _Waiting(text: l10n.autofillSearching),
        AutofillStage.failed => _Failed(
          failure: state.failure,
          onRetry: () => unawaited(controller.search(_query.text)),
        ),
        AutofillStage.writing => _Waiting(text: l10n.autofillWriting(state.written, state.total)),
        AutofillStage.finished => _Summary(state: state, onRetry: () => unawaited(controller.retry())),
        AutofillStage.reviewing => _Review(state: state, query: _query),
      },
      bottomNavigationBar: switch (state.stage) {
        AutofillStage.reviewing => _WriteBar(state: state),
        AutofillStage.writing => Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: OutlinedButton(onPressed: controller.cancel, child: Text(l10n.autofillCancel)),
        ),
        AutofillStage.finished => Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: FilledButton(onPressed: () => Navigator.pop(context), child: Text(l10n.autofillClose)),
        ),
        _ => null,
      },
    );
  }
}

class _Waiting extends StatelessWidget {
  const _Waiting({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: AppSpacing.md),
        Text(text),
      ],
    ),
  );
}

class _Failed extends StatelessWidget {
  const _Failed({required this.failure, required this.onRetry});

  final MetadataSourceFailure? failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(failure == MetadataSourceFailure.rateLimited ? l10n.autofillRateLimited : l10n.autofillUnreachable),
          const SizedBox(height: AppSpacing.md),
          FilledButton(onPressed: onRetry, child: Text(l10n.autofillTryAgain)),
        ],
      ),
    );
  }
}

class _Review extends ConsumerWidget {
  const _Review({required this.state, required this.query});

  final AutofillState state;
  final TextEditingController query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final controller = ref.read(autofillControllerProvider.notifier);
    final release = state.release;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: query,
                decoration: InputDecoration(labelText: l10n.autofillSearchLabel),
                onSubmitted: (text) => unawaited(controller.search(text)),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            TextButton(
              onPressed: () => unawaited(controller.search(query.text)),
              child: Text(l10n.autofillSearchAgain),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (release == null)
          Text(l10n.autofillNothingFound, style: theme.textTheme.titleMedium)
        else ...[
          _ReleaseHeader(release: release.release, candidates: state.candidates),
          if (state.refusal != null) _Refusal(decision: state.refusal!),
          if (state.coverMissing)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(l10n.autofillCoverMissing, style: theme.textTheme.bodySmall),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => controller.toggleAll(state.acceptedCount == 0),
              child: Text(state.acceptedCount == 0 ? l10n.autofillTickAll : l10n.autofillUntickAll),
            ),
          ),
          for (final proposal in state.proposals) _ProposalCard(proposal: proposal),
        ],
      ],
    );
  }
}

class _ReleaseHeader extends ConsumerWidget {
  const _ReleaseHeader({required this.release, required this.candidates});

  final ReleaseCandidate release;
  final List<ReleaseCandidate> candidates;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Card(
      child: ListTile(
        title: Text(release.title, style: theme.textTheme.titleMedium),
        subtitle: Text(_describe(release)),
        trailing: candidates.length < 2
            ? null
            : MenuAnchor(
                menuChildren: [
                  for (final candidate in candidates)
                    MenuItemButton(
                      onPressed: () => unawaited(
                        ref.read(autofillControllerProvider.notifier).chooseRelease(candidate.id),
                      ),
                      child: Text('${candidate.title} — ${_describe(candidate)}'),
                    ),
                ],
                builder: (context, menu, _) => TextButton(
                  onPressed: () => menu.isOpen ? menu.close() : menu.open(),
                  child: Text(l10n.autofillDifferentRelease),
                ),
              ),
      ),
    );
  }
}

/// A release's artist, year, country, format and disambiguation, as one line.
String _describe(ReleaseCandidate release) => [
  release.artist,
  if (release.year case final year?) '$year',
  ?release.country,
  ?release.format,
  ?release.disambiguation,
].where((part) => part.isNotEmpty).join(' · ');

class _Refusal extends ConsumerWidget {
  const _Refusal({required this.decision});

  final LibraryAccessDecision decision;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(child: Text(l10n.autofillAccessRefused, style: TextStyle(color: theme.colorScheme.error))),
          if (decision == LibraryAccessDecision.deniedPermanently)
            TextButton(
              onPressed: () => unawaited(ref.read(libraryAccessControllerProvider.notifier).openSettings()),
              child: Text(l10n.autofillOpenSettings),
            ),
        ],
      ),
    );
  }
}

class _ProposalCard extends ConsumerWidget {
  const _ProposalCard({required this.proposal});

  final FileProposal proposal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final controller = ref.read(autofillControllerProvider.notifier);
    final path = proposal.entry.file.path;
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    final note = switch (proposal.blockedBecause) {
      ProposalBlock.unwritableFormat => l10n.autofillUnwritable,
      ProposalBlock.noMatch => l10n.autofillNoMatch,
      null when proposal.changes.isEmpty => l10n.autofillNoChanges,
      null => null,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(proposal.entry.file.name, style: theme.textTheme.titleSmall),
            if (note != null) Text(note, style: muted),
            if (proposal.notWritable.isNotEmpty)
              Text(
                l10n.autofillNotWritableFields(
                  [for (final f in proposal.notWritable) autofillFieldName(l10n, f)].join(', '),
                ),
                style: muted,
              ),
            for (final change in proposal.changes)
              CheckboxListTile(
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                value: change.accepted,
                onChanged: (_) => controller.toggle(path, change.field),
                title: Text(autofillFieldName(l10n, change.field)),
                subtitle: change.field == AutofillField.cover
                    ? _CoverChange(before: change.before as Uint8List?, after: change.after as Uint8List?)
                    : Row(
                        children: [
                          Flexible(child: Text(_shown(change.before), style: muted)),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                            child: Icon(Icons.arrow_forward, size: 14),
                          ),
                          Flexible(child: Text(_shown(change.after))),
                        ],
                      ),
              ),
          ],
        ),
      ),
    );
  }

  static String _shown(Object? value) => value == null ? '—' : '$value';
}

class _CoverChange extends StatelessWidget {
  const _CoverChange({required this.before, required this.after});

  final Uint8List? before;
  final Uint8List? after;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      _thumb(before),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        child: Icon(Icons.arrow_forward, size: 14),
      ),
      _thumb(after),
    ],
  );

  Widget _thumb(Uint8List? bytes) => SizedBox.square(
    dimension: 48,
    child: bytes == null
        ? const Icon(Icons.album_outlined)
        : Image.memory(bytes, fit: BoxFit.cover, errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined)),
  );
}

class _WriteBar extends ConsumerWidget {
  const _WriteBar({required this.state});

  final AutofillState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: FilledButton(
          onPressed: state.acceptedCount == 0
              ? null
              : () => unawaited(ref.read(autofillControllerProvider.notifier).write()),
          child: Text(l10n.autofillWrite(state.acceptedCount, state.filesWithChanges)),
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.state, required this.onRetry});

  final AutofillState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final written = state.outcomes.values.where((o) => o == WriteOutcome.written).length;
    final refused = {
      for (final MapEntry(:key, :value) in state.outcomes.entries)
        if (value != WriteOutcome.written) key: value,
    };
    final retryable = refused.values.any((o) => o == WriteOutcome.inUse || o == WriteOutcome.failed);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Text(l10n.autofillWritten(written), style: theme.textTheme.titleMedium),
        for (final MapEntry(key: path, value: outcome) in refused.entries)
          ListTile(
            dense: true,
            title: Text(path.split(RegExp(r'[/\\]')).last),
            subtitle: Text(switch (outcome) {
              WriteOutcome.changedSinceRead => l10n.autofillOutcomeChanged,
              WriteOutcome.inUse => l10n.autofillOutcomeInUse,
              WriteOutcome.denied => l10n.autofillOutcomeDenied,
              WriteOutcome.unsupported => l10n.autofillOutcomeUnsupported,
              _ => l10n.autofillOutcomeFailed,
            }),
          ),
        if (retryable)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(onPressed: onRetry, child: Text(l10n.autofillTryAgain)),
          ),
      ],
    );
  }
}
```

Check `AppSpacing` (`lib/core/theme/app_spacing.dart`) for the exact names (`xs`, `sm`, `md`) before running; use the ones that exist.

- [ ] **Step 4: Finish the launcher** — replace the `// Task 12` comment in `autofill_launcher.dart` with:

```dart
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => AutofillScreen(entries: entries, fields: fields, kind: kind),
    ),
  );
```

and import `package:flutter/material.dart` and `autofill_screen.dart`.

- [ ] **Step 5: Run to verify pass**

Run: `flutter test test/features/autofill test/core` then `flutter analyze` then `flutter test`
Expected: all pass, including the colour-literal guard (only theme colours are used above).

- [ ] **Step 6: Commit**

```bash
git add lib/features/autofill/presentation test/features/autofill/presentation
git commit -m "feat: review every autofill change before writing"
```

---

### Task 13: Documents, manifest and CI

**Files:**
- Modify: `docs/requirements/Vision Document.md`, `docs/requirements/System Requirements Document.md`, `docs/requirements/Use Case Specification Document.md`, `README.md`, `android/app/src/main/AndroidManifest.xml`, `.github/workflows/verify.yml`, `.github/workflows/release.yml`, `CHANGELOG.md`

**Interfaces:**
- Consumes: the behaviour Tasks 1–12 built.
- Produces: no code.

- [ ] **Step 1: Vision Document** — in the positioning table row **Our product**, replace "reads only what it was pointed at, never writes to an audio file, and reaches a network for one optional convenience and nothing else" with "reads only what it was pointed at, writes to an audio file only to change its tags when the owner confirms each change, and reaches a network only for conveniences the owner starts or can turn off". Replace **C-02** with: *No network access beyond the lyrics lookup (`FR-LY-13`) and the update check, which the owner can turn off, and the MusicBrainz and Cover Art Archive lookups an autofill makes only when the owner starts one (`FR-AF-02`). No playback depends on any of them.* Replace **C-03** with: *The owner's audio files are opened for reading, and written only to change their metadata — never renamed, moved, deleted or re-encoded — and only for changes the owner has confirmed (`FR-AF-05`).*

- [ ] **Step 2: System Requirements** — add a section `### 2.x Autofill (AF)` after the lyrics section, in the same table format:

| ID | Requirement |
| --- | --- |
| **FR-AF-01** | The owner must be able to start an autofill on a record or on a single track, and choose which of title, artist, album artist, album, track number and total, disc number and total, year, genre and cover it may change; the choice must persist, and cover must be unticked until chosen. |
| **FR-AF-02** | The application must look the record up on MusicBrainz (and the cover on the Cover Art Archive) only when the owner starts an autofill, identify itself, and send at most one request a second. |
| **FR-AF-03** | The best-matching release must be preselected, every other candidate must be selectable, and the search must be editable. |
| **FR-AF-04** | Every proposed change must be shown per file as the current value and the new one, each with its own confirmation; values that would not change must not be shown. |
| **FR-AF-05** | Only confirmed changes may be written, only into the file's metadata, and a file changed since it was read must not be written. A format that cannot be written without losing other metadata must not be offered. |
| **FR-AF-06** | Written changes must reach the library, and every screen, without the owner starting a scan. |
| **FR-AF-07** | A file that could not be written must be named with the reason, and a file refused because it was in use must be retryable. |
| **FR-AF-08** | On Android, permission to change audio files must be asked for only when the owner confirms an autofill, and a refusal must write nothing. |

- [ ] **Step 3: Use Case Specification** — add **UC-34: Autofill a record's tags** after UC-32, in the document's existing structure (actor, preconditions, main flow, alternative flows, postconditions, requirements). Main flow: owner picks *Autofill tags…* on a record → chooses tags → the release is looked up and proposals shown → owner reviews and unticks what they reject → confirms → files are written and the library updated. Alternative flows: AF-01 a lone track; AF-02 a different release; AF-03 search again; AF-04 nothing found; AF-05 MusicBrainz unreachable; AF-06 no file writable; AF-07 a file changed since read / in use / denied; AF-08 Android permission refused; AF-09 cancel while writing. Add the UC-34 row to the traceability table in §3 mapping to `FR-AF-01`…`FR-AF-08`.

- [ ] **Step 4: README** — replace the bullet *It never touches your audio files…* with:

```markdown
- **It changes your files only when you ask.** No renaming, no moving, no
  deleting, no transcoding. The one change it ever makes to an audio file is to
  its tags, from an autofill whose every change you saw and confirmed — and it
  refuses a file another program changed since it was read. Besides that, it
  writes a `.lrc` next to a track whose words it looked up, a new file and
  never a replacement for one you wrote.
```

In *Almost no network*, change "There are two exceptions" to "There are three exceptions", add "and the MusicBrainz and Cover Art Archive lookups an autofill makes when you start one" to the list, and change "exactly eight permissions" to "exactly nine permissions". Add a short **Autofill** paragraph to the feature list describing the flow, and an architecture note pointing at `features/autofill/` (the preservation gate and the throttle, two sentences each).

- [ ] **Step 5: Android manifest** — after the `READ_EXTERNAL_STORAGE` element, add:

```xml
    <!-- Changing a track's tags, on Android 10 and earlier, and nothing else.
         Asked for at one moment only: the owner has reviewed an autofill's
         changes and confirmed them. On Android 11 and later the same write
         goes through all-files access below, and this is never asked for —
         which is why it is capped at API 29. What is written is the file's
         tags and nothing else: never its audio, its name or its place. -->
    <uses-permission
        android:name="android.permission.WRITE_EXTERNAL_STORAGE"
        android:maxSdkVersion="29"/>
```

Add `android:requestLegacyExternalStorage="true"` to `<application>` with a comment: on Android 10 it is what lets the legacy write permission reach a file by its path. Update the `MANAGE_EXTERNAL_STORAGE` comment: it is also asked for when the owner confirms an autofill on Android 11+, and the "one thing it ever writes" sentence becomes "a .lrc beside a track whose words were looked up, and the tags of files whose autofill the owner confirmed". Update the `INTERNET` comment: "The lyrics lookup, and the autofill lookup" with what each sends (artist and title; record title and artist, or track title, artist and length).

- [ ] **Step 6: CI** — in both `.github/workflows/verify.yml` and `.github/workflows/release.yml`, add `android.permission.WRITE_EXTERNAL_STORAGE` to the `expected-permissions.txt` heredoc in sorted position (after `WAKE_LOCK`), and update any comment that says "eight".

- [ ] **Step 7: CHANGELOG** — under `## [Unreleased]`, add an `### Added` section:

```markdown
### Added

- Autofill tags from MusicBrainz. On a record, or from a track's menu, choose which tags to fill — title, artist, album
  artist, album, track and disc numbers and totals, year, genre, and optionally the cover — and Orpheus finds the
  release, shows every change file by file as old → new, and writes only the ones you leave ticked, into the files and
  the library. Another release or another search is one tap away. Orpheus now changes audio files for this and nothing
  else, and the Android app asks for permission to do it the first time you confirm an autofill.
```

- [ ] **Step 8: Verify and commit**

Run: `flutter analyze` and `flutter test`
Expected: clean and green (docs do not affect them; the manifest is not read by the suite).

```bash
git add docs README.md CHANGELOG.md android/app/src/main/AndroidManifest.xml .github/workflows
git commit -m "docs: allow writing tags, and say how"
```

---

### Task 14: Whole-branch verification

**Files:** none new.

- [ ] **Step 1: Full checks**

```bash
flutter analyze
flutter test
flutter build windows --release
```

Expected: analyzer clean; every test passes (note the count against the 545 before this work); the build succeeds.

- [ ] **Step 2: Drive it in the real app** — using a **copy** of a small album in a scratch folder registered as a library folder (never the owner's own music):

1. Launch `build\windows\x64\runner\Release\orpheus.exe`, add the scratch folder, wait for the scan.
2. Open the album, press the autofill button, keep the defaults, *Find*.
3. Confirm the release, the old → new rows, and that unticking changes the button's counts.
4. *Write*; confirm the summary, then that the library shows the new tags after the rescan.
5. Re-open the files in another tag editor (or `ffprobe`) and confirm the changed tags and that untouched tags survived.
6. Start an autofill on the track that is playing; confirm *in use by playback* and that *Try again* works after skipping to another track.

Report anything that differs, with what was seen.

- [ ] **Step 3: Push and open the pull request** — only when the owner asks; the branch builds on PR #44, so the pull request targets `develop` after #44 merges (or is opened as a draft until then).
