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

/// Whether [term] is worth searching for.
///
/// A single character matches most of a library, which is a screenful of
/// results that says nothing. Two is where a search starts to mean something.
bool isSearchable(String term) => term.trim().length >= 2;
