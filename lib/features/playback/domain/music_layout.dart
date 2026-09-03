/// How the artists and the albums are drawn.
///
/// Two values, because there are two honest ways to read a shelf of records:
/// as a list, which holds more per screen and says whose a record is in words,
/// and as a wall of sleeves, which is how anybody actually finds one they
/// recognise.
///
/// It applies to the artists and the albums alone. Songs and the tracks inside
/// a record stay lists whatever is chosen here: a track is a line of text, and
/// a grid of lines of text is a list with worse density.
enum MusicLayout {
  /// One row per artist or record, with its picture beside it.
  list,

  /// Tiles, where the picture is the tile.
  grid;

  /// The layout [name] names, or `null` when it names none.
  ///
  /// Used to read a stored choice back, where an unrecognised value means the
  /// owner's preference is simply unknown and the default applies.
  static MusicLayout? byName(String? name) {
    for (final layout in MusicLayout.values) {
      if (layout.name == name) return layout;
    }

    return null;
  }
}
