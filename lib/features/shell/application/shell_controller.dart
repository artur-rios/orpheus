import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/shell_destination.dart';

/// Which area the shell is showing.
class ShellController extends Notifier<ShellDestination> {
  @override
  ShellDestination build() => ShellDestination.music;

  /// Shows [destination].
  void go(ShellDestination destination) => state = destination;
}

/// What the owner has typed into the search field.
///
/// The shell's rather than the music area's, because the field lives in the
/// bar across the top: a term typed there survives moving between areas, and
/// clearing it is what returns the library to its own listing.
class SearchTermController extends Notifier<String> {
  @override
  String build() => '';

  /// Records [term].
  void type(String term) => state = term;

  /// Clears the field.
  void clear() => state = '';
}

/// What a search term is matched against.
///
/// A name alone is ambiguous in a library: *Heaven* is a song, an album and a
/// genre's worth of bands, and the owner who wants one of them should not have
/// to wade through the others. [all] is the default because it is what a search
/// without a choice has always meant.
enum SearchField {
  /// Every field below.
  all,

  /// The title.
  songs,

  /// The artist and the album artist.
  artists,

  /// The album.
  albums,

  /// Each genre a track carries.
  genres,
}

/// Which [SearchField] the search matches against.
///
/// Held beside the term rather than in the results view because the view is
/// replaced whenever the term is cleared: a choice kept in it would be forgotten
/// between one search and the next. It is not persisted — every launch starts
/// back on *All*, the widest net.
class SearchFieldController extends Notifier<SearchField> {
  @override
  SearchField build() => SearchField.all;

  /// Narrows the search to [field].
  void choose(SearchField field) => state = field;
}

/// Whether [term] is worth searching for.
///
/// A single character matches most of a library, which is a screenful of
/// results that says nothing. Two is where a search starts to mean something.
bool isSearchable(String term) => term.trim().length >= 2;
