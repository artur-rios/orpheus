import 'audio_file.dart';
import 'track_metadata.dart';

/// A tag, trimmed, or `null` when it names nothing.
///
/// The one place blank-or-absent becomes `null` rather than a word — what word
/// to show instead is a presentation decision, which is what `tagOr` in
/// `music_display_name.dart` makes from this. [MusicEntry] uses this same
/// function for its own getters, so there is one trimming rule rather than two
/// that could drift apart.
String? trimmedOrNull(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

/// One audio file and the metadata the library is grouped by.
class MusicEntry {
  /// Creates an entry.
  const MusicEntry({
    required this.file,
    required this.metadata,
    this.albumArtistOfRecord,
  });

  /// The file itself.
  final AudioFile file;

  /// What its tags say.
  final TrackMetadata metadata;

  /// The album it belongs to, or `null` when it names none.
  String? get album => trimmedOrNull(metadata.album);

  /// The artist, or `null` when it names none.
  ///
  /// Who performed *this track*, which is what a track row shows: on a record
  /// with guests, the guest is the answer, and that is the point of the tag.
  /// It is not what the library is grouped by — see [albumArtist].
  String? get artist => trimmedOrNull(metadata.artist);

  /// What the rest of this record says its artist is — see
  /// `albumArtistsAcross`, which is the only thing that sets it.
  ///
  /// `null` for an entry read on its own, outside a library: a single track is
  /// no evidence about the record it came from.
  final String? albumArtistOfRecord;

  /// Who the record is by.
  ///
  /// The one key every grouping and every queue is built from: a compilation
  /// under one album artist is one record rather than one record per
  /// performer, and a guest appearance stays on the host's album.
  ///
  /// Three answers, in order of how much they know:
  ///
  /// 1. this file's own album-artist tag, which is the record answering for
  ///    itself;
  /// 2. what the rest of the record says ([albumArtistOfRecord]) — for a file
  ///    that carries no such tag, which most files do not;
  /// 3. this track's own performer, for a track that belongs to no record the
  ///    library can see.
  ///
  /// The middle one is what keeps a rap album out of the artists list twelve
  /// times over. A record whose tracks are tagged `50 Cent`, `50 Cent feat.
  /// Nate Dogg` and `Eminem, 50 Cent` and carries no album artist anywhere is
  /// one record by one artist, and falling straight through to the performer
  /// listed every guest on it as an artist in their own right.
  String? get albumArtist =>
      trimmedOrNull(metadata.albumArtist) ?? albumArtistOfRecord ?? artist;

  /// The track's title, or `null` when it names none.
  ///
  /// What a row shows. A file whose tags carry no title has no name in this
  /// application's terms — its name on disk is not one.
  String? get title => trimmedOrNull(metadata.title);

  /// How long the track is, where the tags said.
  Duration? get duration => metadata.duration;

  /// A copy of this entry told who the record it belongs to is by.
  MusicEntry withRecordArtist(String? artist) => MusicEntry(
    file: file,
    metadata: metadata,
    albumArtistOfRecord: artist,
  );
}
