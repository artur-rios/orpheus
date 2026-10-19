import 'audio_file.dart';
import 'music_entry.dart';
import 'track_metadata.dart';

/// Everything a scan found, and when it found it.
///
/// The one document the whole application reads its library from. It is built
/// by the scanner, written to disk as a single file, and held in memory for
/// the run — a library of tens of thousands of tracks is a few megabytes of
/// tags, and every screen in the music area needs all of it to group by.
class MusicCatalog {
  /// Creates a catalog over [entries].
  MusicCatalog({required this.entries, this.scannedAt, this.isStale = false});

  /// The catalog of a library that has never been scanned.
  static final MusicCatalog empty = MusicCatalog(entries: const []);

  /// The tracks, each already told whose record it is on
  /// (`albumArtistsAcross`).
  final List<MusicEntry> entries;

  /// When the scan that produced this ran, or `null` for a catalog that was
  /// never scanned.
  final DateTime? scannedAt;

  /// Whether this was read from a document that was refused: another
  /// version's, or one that cannot be read at all.
  ///
  /// Such a catalog holds nothing, and the library is owed a scan whatever the
  /// owner chose about scanning at launch: one who turned that off would
  /// otherwise upgrade into an empty library and stay in it until they scanned
  /// by hand. A missing document is not stale — a library never scanned is the
  /// owner's to scan — and neither is anything a scan produced.
  final bool isStale;

  /// Whether the library holds nothing.
  bool get isEmpty => entries.isEmpty;

  Map<String, MusicEntry>? _byPath;

  /// The entries by the path that identifies them.
  ///
  /// Built once, lazily: the player asks this question for every track it
  /// opens and every frame the bar draws, and a linear search of the whole
  /// library per frame is what that becomes without an index.
  Map<String, MusicEntry> get byPath =>
      _byPath ??= {for (final entry in entries) entry.file.path: entry};

  /// [file] as the library knows it.
  ///
  /// A file the catalog does not hold answers as an entry with no tags rather
  /// than as `null`: such a file is still playable — it can be handed to the
  /// player from anywhere — and every caller here wants something to name it
  /// by, which "no tags at all" already has a rule for.
  MusicEntry entryFor(AudioFile file) =>
      byPath[file.path] ??
      MusicEntry(file: file, metadata: TrackMetadata.empty);

  /// The entry at [path], or `null` when the library holds none.
  MusicEntry? entryAt(String path) => byPath[path];
}
