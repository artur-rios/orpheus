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
  ///
  /// Lines that share a time keep the order the file gave them, which is what
  /// a bilingual LRC means by writing a line and then its translation under
  /// the same stamp. `List.sort` promises no such thing — past a few dozen
  /// lines it is a quicksort, and it swapped pairs partway down a long song —
  /// so each line's position in the file is the tiebreak, said outright.
  factory Lyrics.synced(List<LyricLine> lines) {
    final positions = [for (var index = 0; index < lines.length; index++) index]
      ..sort((a, b) {
        final byTime = (lines[a].at ?? Duration.zero).compareTo(
          lines[b].at ?? Duration.zero,
        );

        return byTime != 0 ? byTime : a.compareTo(b);
      });

    return Lyrics(
      lines: List.unmodifiable([for (final index in positions) lines[index]]),
      isSynced: true,
    );
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
  /// Where several lines share the time being sung — a line and its
  /// translation — the first of them: the highlight and the scroll land on the
  /// top of the group, and the rest of it follows beneath. Answering the last,
  /// which is where the search below stops, lit the translation and never the
  /// line it translates.
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

    // Back to the first line stamped with the same time. A walk rather than a
    // second search, because such a group is two or three lines long.
    while (found != null &&
        found > 0 &&
        lines[found - 1].at == lines[found].at) {
      found--;
    }

    return found;
  }
}
