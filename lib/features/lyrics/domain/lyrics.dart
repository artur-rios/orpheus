/// One line of a song, and — where the file says — when it is sung.
class LyricLine {
  /// Creates a line.
  const LyricLine({required this.text, this.at});

  /// The words.
  ///
  /// Empty where the file times a gap rather than a line, which is how an LRC
  /// marks the end of a verse and the instrumental that follows it. Kept
  /// rather than dropped: it is what makes the highlight go out between
  /// verses instead of leaving the last line lit through a solo.
  final String text;

  /// When it is sung, or `null` in lyrics that carry no times at all.
  final Duration? at;

  @override
  bool operator ==(Object other) =>
      other is LyricLine && other.text == text && other.at == at;

  @override
  int get hashCode => Object.hash(text, at);

  @override
  String toString() => 'LyricLine(${at ?? '-'}, $text)';
}

/// The words of one track, as some file on this machine gives them.
///
/// Two shapes, and the difference is the whole feature: [synced] lyrics carry
/// a time per line and follow the music, [plain] ones are a block of text that
/// can only be read. Which of the two an owner gets is decided by what their
/// own file holds, never by this application — there is nowhere to fetch times
/// from, and no attempt is made to guess them by dividing the track's length
/// by the number of lines.
class Lyrics {
  /// Creates lyrics directly. See [synced] and [plain].
  const Lyrics({required this.lines, required this.isSynced});

  /// Timed lyrics, from [lines], ordered by their times.
  ///
  /// Sorted here rather than trusted: an LRC written by hand, or one where a
  /// line was given two times so that a refrain repeats, arrives in whatever
  /// order it was typed in, and everything downstream — the lookup, the
  /// scrolling, the highlight — depends on the order being right.
  factory Lyrics.synced(List<LyricLine> lines) {
    final ordered = [...lines]..sort(
      (a, b) => (a.at ?? Duration.zero).compareTo(b.at ?? Duration.zero),
    );

    return Lyrics(lines: List.unmodifiable(ordered), isSynced: true);
  }

  /// Untimed lyrics, from [lines] of text.
  factory Lyrics.plain(List<String> lines) => Lyrics(
    lines: List.unmodifiable([
      for (final line in lines) LyricLine(text: line),
    ]),
    isSynced: false,
  );

  /// The lines, in the order they are sung.
  final List<LyricLine> lines;

  /// Whether the lines carry times, and so whether they follow the music.
  final bool isSynced;

  /// Whether there is nothing to show.
  bool get isEmpty => lines.isEmpty;

  /// Which line is being sung at [position], or `null` where none is.
  ///
  /// `null` before the first line's time — the count-in, the intro — and for
  /// lyrics that carry no times, which have no line that belongs to a moment.
  ///
  /// A binary search rather than a walk: this is asked on every position
  /// report the engine sends, which is several times a second for as long as
  /// a track plays.
  int? lineIndexAt(Duration position) {
    if (!isSynced || lines.isEmpty) return null;

    var low = 0;
    var high = lines.length - 1;
    int? found;

    while (low <= high) {
      final middle = (low + high) ~/ 2;
      if ((lines[middle].at ?? Duration.zero) <= position) {
        found = middle;
        low = middle + 1;
      } else {
        high = middle - 1;
      }
    }

    return found;
  }
}
