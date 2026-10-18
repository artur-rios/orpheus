import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/song_selection.dart';

/// The songs the owner has picked, held where every list and the back handler
/// can reach them.
///
/// Not remembered: a selection is a moment in a list, and a restart has no
/// list to put it back in.
class SongSelectionController extends Notifier<SongSelection> {
  @override
  SongSelection build() => SongSelection.none;

  /// Flips [path] in the list named [scope].
  void toggle(Object scope, String path) => state = state.toggle(scope, path);

  /// Selects from the anchor to [path] within [order].
  void rangeTo(Object scope, String path, List<String> order) =>
      state = state.rangeTo(scope, path, order);

  /// Selects every song in [order].
  void selectAll(Object scope, List<String> order) =>
      state = state.selectAll(scope, order);

  /// Drops the selected songs that [order] no longer holds.
  void retainIn(Object scope, List<String> order) =>
      state = state.retainIn(scope, order);

  /// Ends the selection.
  void clear() => state = SongSelection.none;
}
