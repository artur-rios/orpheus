import '../domain/lyrics.dart';

/// Reads the LRC in [text], or answers `null` where it holds no words.
///
/// LRC has no standards body and never had one. What it has is a shape every
/// writer of it agrees on — `[mm:ss.xx]` in front of a line — and a handful of
/// extensions that appear in real files often enough that a reader which
/// choked on them would be a reader that choked on ordinary libraries:
///
/// - Tag lines: `[ti:…]`, `[ar:…]`, `[by:…]`. Skipped, except `[offset:…]`.
/// - Several times on one line, for a refrain sung more than once.
/// - Word-level times inside the line, written `<mm:ss.xx>`, from enhanced
///   LRC. Stripped: this application highlights a line at a time, and a file
///   that carries more detail than that is still a perfectly good file.
/// - A file with no times at all, which is a plain lyrics sheet somebody
///   named `.lrc`. Read as [Lyrics.plain] rather than rejected.
///
/// Nothing here throws. A file that parses to nothing is a file with no
/// lyrics in it, which is a state the screen already has to show for the far
/// more common case of no file at all.
Lyrics? parseLrc(String text) {
  final timed = <LyricLine>[];
  final untimed = <String>[];
  var offset = Duration.zero;

  for (final line in text.split(_lineBreak)) {
    final times = <Duration>[];
    var rest = line.trim();

    // The leading brackets, taken one at a time until something that is not a
    // bracket appears. A closing bracket inside the words themselves is
    // therefore not mistaken for a tag: by then this loop has stopped.
    while (rest.startsWith('[')) {
      final close = rest.indexOf(']');
      if (close < 0) break;

      final inside = rest.substring(1, close);
      final at = _timeOf(inside);

      if (at != null) {
        times.add(at);
      } else if (_tag.hasMatch(inside)) {
        offset = _offsetOf(inside) ?? offset;
      } else {
        // Neither a time nor a tag: a line that happens to open with a
        // bracket. It is words, and it keeps its bracket.
        break;
      }

      rest = rest.substring(close + 1).trimLeft();
    }

    final words = rest.replaceAll(_wordTime, '').trim();

    if (times.isEmpty) {
      if (words.isNotEmpty) untimed.add(words);
      continue;
    }

    for (final at in times) {
      timed.add(LyricLine(text: words, at: at));
    }
  }

  if (timed.isNotEmpty) {
    return Lyrics.synced([
      for (final line in timed)
        LyricLine(text: line.text, at: _shifted(line.at!, offset)),
    ]);
  }

  return untimed.isEmpty ? null : Lyrics.plain(untimed);
}

/// The line endings of all three platforms, and of a file that has been
/// through two of them.
final RegExp _lineBreak = RegExp(r'\r\n|\r|\n');

/// `[mm:ss]`, `[mm:ss.xx]`, `[mm:ss.xxx]`, and the `[mm:ss:xx]` some writers
/// produce instead. Minutes are not bounded at 59: a live recording of a whole
/// side is one track, and `[73:20.00]` is what an honest writer puts in it.
final RegExp _time = RegExp(r'^(\d+):([0-5]?\d)(?:[.:](\d{1,3}))?$');

/// `[ti:…]` and its siblings — a word, a colon, and whatever follows.
final RegExp _tag = RegExp(r'^[A-Za-z_#]+:');

/// The per-word times enhanced LRC writes inside a line.
final RegExp _wordTime = RegExp(r'<\d+:\d{1,2}(?:[.:]\d{1,3})?>');

/// The time [inside] a bracket states, or `null` where it states none.
Duration? _timeOf(String inside) {
  final match = _time.firstMatch(inside.trim());
  if (match == null) return null;

  final fraction = match.group(3);

  return Duration(
    minutes: int.parse(match.group(1)!),
    seconds: int.parse(match.group(2)!),
    // Hundredths are what LRC almost always writes and thousandths what the
    // rest write, so the digits are padded to milliseconds rather than read as
    // a fixed width: `.5` is half a second, `.50` is half a second, and `.500`
    // is half a second.
    milliseconds: fraction == null
        ? 0
        : int.parse(fraction.padRight(3, '0')),
  );
}

/// The correction `[offset:…]` asks for, in milliseconds, or `null` for any
/// other tag.
///
/// A positive offset means the words are wanted *earlier* — it is the value a
/// listener writes when the lines keep arriving after they are sung — so it is
/// taken off the times rather than added to them. That is the reading the
/// format's own description gives, and the one every player that implements
/// the tag at all agrees on.
Duration? _offsetOf(String inside) {
  final colon = inside.indexOf(':');
  if (inside.substring(0, colon).trim().toLowerCase() != 'offset') return null;

  final value = int.tryParse(
    inside.substring(colon + 1).trim().replaceAll('+', ''),
  );

  return value == null ? null : Duration(milliseconds: value);
}

/// [at] corrected by [offset], never before the start of the track.
Duration _shifted(Duration at, Duration offset) {
  final shifted = at - offset;

  return shifted.isNegative ? Duration.zero : shifted;
}
