/// What the tags in a file say about the track in it.
///
/// Every field is nullable, and every one of them is nullable for the same
/// reason: a tag that is absent is absent. What to *call* a track whose title
/// tag is missing is a presentation decision made once, in
/// `music_display_name.dart`, and never by defaulting to the file's name here.
class TrackMetadata {
  /// Creates metadata.
  const TrackMetadata({
    this.title,
    this.artist,
    this.albumArtist,
    this.album,
    this.genre,
    this.track,
    this.trackTotal,
    this.disc,
    this.year,
    this.duration,
    this.coverId,
  });

  /// The metadata of a file whose tags could not be read, or that carries
  /// none.
  static const TrackMetadata empty = TrackMetadata();

  /// The track's own title.
  final String? title;

  /// Who performed this track — the guest on a record with guests.
  final String? artist;

  /// Whose record it is, where the file itself says.
  ///
  /// Only some tag formats carry this, and half-tagged libraries are the norm
  /// rather than the exception, which is why `albumArtistsAcross` in
  /// `music_grouping.dart` works the answer out across a whole record rather
  /// than trusting this field to be present.
  final String? albumArtist;

  /// The record it belongs to.
  final String? album;

  /// Its genre, where the file names one.
  final String? genre;

  /// Its position on the record.
  final int? track;

  /// How many tracks the record holds.
  final int? trackTotal;

  /// Which disc of a set it is on.
  final int? disc;

  /// The year the record carries.
  final int? year;

  /// How long the track is, where the tags say.
  ///
  /// Read from the file rather than from the engine: a listing shows the
  /// length of every track on screen, and asking the playback engine to open
  /// each one to find out would be a decode per row.
  final Duration? duration;

  /// The cover in the cover store this track's record is pictured by, or
  /// `null` for a track no picture was found for.
  final String? coverId;

  /// A copy with the given changes.
  TrackMetadata copyWith({
    String? title,
    String? artist,
    String? albumArtist,
    String? album,
    String? genre,
    int? track,
    int? trackTotal,
    int? disc,
    int? year,
    Duration? duration,
    String? coverId,
  }) => TrackMetadata(
    title: title ?? this.title,
    artist: artist ?? this.artist,
    albumArtist: albumArtist ?? this.albumArtist,
    album: album ?? this.album,
    genre: genre ?? this.genre,
    track: track ?? this.track,
    trackTotal: trackTotal ?? this.trackTotal,
    disc: disc ?? this.disc,
    year: year ?? this.year,
    duration: duration ?? this.duration,
    coverId: coverId ?? this.coverId,
  );
}
