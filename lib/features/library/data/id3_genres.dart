import 'dart:typed_data';

// The reader's own ID3v1 genre table. The package does not export it, and
// copying its 192 names here would drift from the names the reader gives the
// same codes everywhere else.
// ignore: implementation_imports
import 'package:audio_metadata_reader/src/constants/id3_genres.dart';

import 'id3v2_frames.dart';

/// The genres of every `TCON` frame (`TCO` in ID3v2.2) in the ID3v2 tag [tag],
/// in the order written and each resolved to a name, or `null` where there is
/// no tag or no such frame.
///
/// The tag-reading package stops an ID3v2.4 genre at its first zero byte, which
/// drops every value after the first, and splits at `/`, which tears *Hip-Hop/
/// Rap* in two. So the scan reads the frame itself. The values come back
/// resolved but not split at `;`, `|` or `,`: that is the library's rule for
/// every format, and it is applied where the formats meet.
List<String>? id3GenreValues(Uint8List tag) {
  final parsed = Id3v2Tag.of(tag);
  if (parsed == null) return null;

  List<String>? genres;

  for (final frame in parsed.frames()) {
    if (frame.id != 'TCON' && frame.id != 'TCO') continue;

    final resolved = genres ??= [];
    for (final value in id3TextValues(frame.data)) {
      resolved.addAll(_resolve(value));
    }
  }

  return genres;
}

/// A value that is only a number: ID3v2.4's way of writing a table code.
final RegExp _bareCode = RegExp(r'^\d+$');

/// One or more references — `(17)`, `(RX)`, `(CR)` — optionally followed by a
/// refinement in words, which is how ID3v2.3 writes a genre.
final RegExp _references = RegExp(r'^((?:\(\d+\)|\(RX\)|\(CR\))+)(.*)$');

/// One reference out of a run of them.
final RegExp _reference = RegExp(r'\((\d+|RX|CR)\)');

/// What one frame value stands for: none, one or several genre names.
///
/// A code the table does not hold is dropped rather than shown as a number,
/// because "999" is not a genre a listener could recognise or search for.
List<String> _resolve(String value) {
  if (_bareCode.hasMatch(value)) return _named(value);

  final match = _references.firstMatch(value);
  if (match != null) {
    // `(17)Rock & Roll` refines the code with its own words, and the words are
    // what the writer meant to show.
    final refinement = match.group(2)!;
    if (refinement.trim().isNotEmpty) return [refinement];

    return [
      for (final reference in _reference.allMatches(match.group(1)!))
        ..._named(reference.group(1)!),
    ];
  }

  // ID3v2.3 escapes a genre that really begins with a parenthesis by doubling
  // it, so `((Ska)` is the genre `(Ska)`.
  if (value.startsWith('((')) return [value.substring(1)];

  return [value];
}

/// The name of reference [reference]: a table code, `RX` or `CR`.
List<String> _named(String reference) => switch (reference) {
  'RX' => const ['Remix'],
  'CR' => const ['Cover'],
  // A number too long to be an int is no code in the table either.
  _ => [?id3GenreName(int.tryParse(reference) ?? -1)],
};
