import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
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

  /// How many song lists of each name are on screen.
  ///
  /// Kept beside the selection rather than in it: it changes as lists come
  /// and go, and nothing should rebuild for that.
  final Map<Object, int> _shown = {};

  /// A song list named [scope] is on screen.
  void attach(Object scope) => _shown[scope] = (_shown[scope] ?? 0) + 1;

  /// A song list named [scope] has left the screen.
  void detach(Object scope) {
    final left = (_shown[scope] ?? 0) - 1;
    if (left > 0) {
      _shown[scope] = left;
    } else {
      _shown.remove(scope);
    }
  }

  /// Ends a selection made in [scope] when no list of that name is on screen
  /// any more: the owner left it — for a view or an area with no songs in
  /// it — and coming back is not picking up where they were.
  ///
  /// Kept while the library is loading, though: the list gave way to the
  /// spinner, not to somewhere else, and comes back with the same songs.
  void endIfUnshown(Object scope) {
    if (!ref.mounted || !state.isActiveIn(scope)) return;
    if (_shown.containsKey(scope)) return;
    if (ref.read(musicLibraryControllerProvider).isLoading) return;

    state = SongSelection.none;
  }
}
