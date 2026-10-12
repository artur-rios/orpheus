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
  static String encode(Set<AutofillField> fields) => [
    for (final field in values)
      if (fields.contains(field)) field.name,
  ].join(',');

  /// The choice [stored] as [encode] wrote it, or [defaults] where there is
  /// none worth using.
  ///
  /// A name this version does not know — written by a later one — is skipped
  /// rather than failing the read.
  static Set<AutofillField> decode(String? stored) {
    if (stored == null) return defaults;

    final names = stored.split(',').toSet();
    final fields = {
      for (final field in values)
        if (names.contains(field.name)) field,
    };

    return fields.isEmpty ? defaults : fields;
  }
}
