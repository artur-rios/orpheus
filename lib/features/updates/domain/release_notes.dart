import 'dart:convert';

/// Turns a release's notes into something worth putting in a dialog.
///
/// What arrives is Markdown, written for a page on GitHub. This application
/// has no Markdown renderer and is not getting one for a paragraph an owner
/// reads twice a year — but showing the source is worse than showing nothing:
/// the notes of this project open with a downloads table, and a table rendered
/// as its own pipes and dashes is a wall of punctuation where the news should
/// be.
///
/// So the parts that only make sense rendered are dropped, and the parts that
/// read the same either way are kept.
abstract final class ReleaseNotes {
  /// [notes] as plain text, or `null` where nothing legible is left.
  static String? readable(String? notes) {
    if (notes == null) return null;

    final kept = <String>[];
    for (final line in const LineSplitter().convert(notes)) {
      final trimmed = line.trimRight();

      // A table is the one construct that is unreadable unrendered, and the
      // one this project's notes lead with. Both its rows and its `---|---`
      // rule start with a pipe once trimmed.
      if (trimmed.trimLeft().startsWith('|')) continue;

      // A horizontal rule is a line of punctuation with nothing to say.
      if (RegExp(r'^\s*([-*_])\s*(\1\s*){2,}$').hasMatch(trimmed)) continue;

      kept.add(
        trimmed
            // Heading markers, keeping the heading.
            .replaceFirst(RegExp(r'^\s*#{1,6}\s*'), '')
            // Emphasis and code spans, keeping what they wrapped.
            .replaceAll(RegExp(r'\*\*|__|`'), '')
            // A bullet is clearer as one character than as an asterisk.
            // Mapped rather than replaced: Dart's `replaceFirst` takes the
            // replacement literally, so `$1` would arrive on screen as `$1`.
            .replaceFirstMapped(
              RegExp(r'^(\s*)[-*+]\s+'),
              (match) => '${match[1]}• ',
            ),
      );
    }

    final text = kept
        .join('\n')
        // Whatever the dropped lines left behind.
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();

    return text.isEmpty ? null : text;
  }
}
