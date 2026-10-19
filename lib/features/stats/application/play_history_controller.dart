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

    // Listened to before the stored history is asked for, so no play recorded
    // from here on is missed.
    final subscription = recorder.changes.listen(
      (history) => state = AsyncData(history),
    );
    ref.onDispose(subscription.cancel);

    // Asked twice: the first waits for the read, and plays recorded while it
    // was under way have replaced what the recorder holds since. The recorder
    // holds each new history before it announces it, so the second answer is
    // never older than a change already heard — which the first one, or the
    // last change heard, could be.
    await recorder.current();

    return recorder.current();
  }
}
