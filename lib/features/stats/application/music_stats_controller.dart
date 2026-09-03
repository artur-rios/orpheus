import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../library/domain/music_catalog.dart';
import '../domain/music_stats.dart';

/// What the owner listens to, read once per opening of the screen.
///
/// Deliberately not a live view. The screen does not follow the music while it
/// is open: a chart that reordered itself under the reader would be harder to
/// read than one a minute old, and reading it again is one button away.
///
/// Auto-disposed, so leaving the screen and coming back reads again rather
/// than showing what was true the first time it was opened this session.
class MusicStatsController extends AsyncNotifier<MusicStats> {
  @override
  Future<MusicStats> build() async {
    // Read together, from one instant. The totals and the rankings are two
    // halves of one answer, and reading them apart would let a play land
    // between and put a total on screen that disagrees with the lists under it.
    final history = await ref.read(playRecorderProvider).current();
    final catalog = await _catalog();

    return musicStatsFrom(history: history, catalog: catalog);
  }

  /// Reads the statistics again.
  ///
  /// What the "Read again" button does. The screen goes back to its loading
  /// state, which is the honest thing to show while the answer is being worked
  /// out afresh.
  Future<void> readAgain() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(build);
  }

  /// The library, or an empty catalog where it could not be read.
  ///
  /// Statistics do not fail because the library did. Every play still counts
  /// and every total is still true; what is lost is the names to rank them by,
  /// and the track ranking falls back to the files' own names — which is
  /// exactly what it does for a track the catalog never held.
  Future<MusicCatalog> _catalog() async {
    try {
      return await ref.read(musicLibraryControllerProvider.future);
    } on Object {
      return MusicCatalog.empty;
    }
  }
}
