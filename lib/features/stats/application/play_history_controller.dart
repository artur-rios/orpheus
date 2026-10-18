import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../domain/play_history.dart';

/// The play history as it is now, following every play as it is recorded.
///
/// An [AsyncNotifier] over the one [PlayRecorder] rather than a second copy of
/// the history: it starts from what the recorder holds and takes each history
/// the recorder hears itself record. What reacts to the owner listening — the
/// auto playlists — watches this; the statistics screen keeps reading the
/// recorder once per opening, because a chart that reorders itself under the
/// reader is harder to read than one a minute old.
///
/// Never an error: the recorder answers an empty history for a store it
/// could not read.
class PlayHistoryController extends AsyncNotifier<PlayHistory> {
  @override
  Future<PlayHistory> build() async {
    final recorder = ref.watch(playRecorderProvider);

    // Listened to before the stored history is asked for, so a play recorded
    // while it is being read is not missed: each change is the whole history,
    // so the latest one heard is newer than whatever the read returns.
    PlayHistory? changed;
    final subscription = recorder.changes.listen((history) {
      changed = history;
      state = AsyncData(history);
    });
    ref.onDispose(subscription.cancel);

    final held = await recorder.current();

    return changed ?? held;
  }
}
