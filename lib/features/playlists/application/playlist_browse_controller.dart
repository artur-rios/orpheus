import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../domain/auto_playlists.dart';

/// Which playlist the owner has open, or `null` while they are looking at the
/// list of them.
///
/// Held here rather than in the view so that Back can go from one to the other
/// from anywhere, and so that the tab remembers where it was when the owner
/// comes back to it.
class PlaylistBrowseController extends Notifier<String?> {
  @override
  String? build() {
    // Turning the auto playlists off closes one that is open, rather than
    // leaving it to reappear when they are turned back on.
    ref.listen(
      preferencesControllerProvider.select((state) => state.showsAutoPlaylists),
      (_, shown) {
        final open = state;
        if (!shown && open != null && isAutoPlaylistId(open)) state = null;
      },
    );

    return null;
  }

  /// Opens the playlist [id].
  void open(String id) => state = id;

  /// Goes back to the list of playlists.
  void close() => state = null;
}
