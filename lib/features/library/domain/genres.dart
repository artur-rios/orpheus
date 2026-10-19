/// Where one genre tag ends and the next begins: `;`, `|` or `,`.
///
/// `/` is deliberately absent. It is a separator in some tagging habits, but
/// Apple's standard genre names contain it — *Hip-Hop/Rap*, *R&B/Soul* — and
/// splitting on it would tear those into two genres that nobody tagged. That
/// is the owner's decision, so it lives here, once, rather than being left for
/// each format's reader to guess at.
final _separator = RegExp(r'[;|,]');

/// The genres [values] name, in the order they first appear.
///
/// Each value is split on the separators, each part trimmed, and blank parts
/// dropped, so `Rock;` and `, ,` name nothing rather than a genre called
/// nothing. A `null` value names nothing, the same as a blank one.
///
/// A genre that appears again — under any spelling [genreKey] considers the
/// same — is dropped. The first spelling wins: a library that tags `Rock` on
/// most tracks and `rock` on one shows one *Rock*, not two, and the spelling
/// that stays is the one the file reached first.
List<String> splitGenres(Iterable<String?> values) {
  final seen = <String>{};
  final genres = <String>[];

  for (final value in values) {
    if (value == null) continue;

    for (final part in value.split(_separator)) {
      final genre = part.trim();
      if (genre.isEmpty) continue;
      if (!seen.add(genreKey(genre))) continue;

      genres.add(genre);
    }
  }

  return genres;
}

/// The identity of [genre] for matching: trimmed and lower-cased.
///
/// Two genres are the same genre when their keys are equal, so this is the one
/// place "the same genre" is decided. Case and surrounding spaces are the
/// differences tags actually carry between files of one album; anything beyond
/// that — `Hip Hop` against `Hip-Hop` — is a different name, and merging it
/// would be a guess.
String genreKey(String genre) => genre.trim().toLowerCase();
