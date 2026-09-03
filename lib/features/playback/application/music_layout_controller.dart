import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../../core/di/providers.dart';
import '../domain/music_layout.dart';

/// How the music area draws its artists and albums.
///
/// Remembered: an owner who browses their records as a wall of sleeves means
/// it next time too.
class MusicLayoutController extends Notifier<MusicLayout> {
  static final Logger _log = Logger('playback');

  /// The settings key the choice is stored under.
  static const String settingsKey = 'musicLayout';

  /// What the music area shows before anyone chooses.
  ///
  /// The list, because it is the denser of the two and says more per row — the
  /// grid is the deliberate choice, not the one an owner is given without
  /// asking.
  static const MusicLayout fallback = MusicLayout.list;

  @override
  MusicLayout build() =>
      MusicLayout.byName(ref.read(settingsStoreProvider).getString(settingsKey)) ??
      fallback;

  /// Applies [layout] now and remembers it.
  ///
  /// The state moves whether or not the write lands: a preference that could
  /// not be saved still applies for this session.
  Future<void> choose(MusicLayout layout) async {
    state = layout;

    try {
      await ref.read(settingsStoreProvider).setString(settingsKey, layout.name);
    } on Object catch (error) {
      _log.warning('a music layout applied but could not be saved', error);
    }
  }
}
