import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the player is showing the words instead of the sleeve.
///
/// Held here rather than in the player's own widget so that it survives the
/// screen being closed and opened again: an owner who reads along does so for
/// a record, not for a track, and closing the player to answer something
/// should not put the sleeve back.
///
/// Not written to the settings, deliberately. It is a way of looking at what
/// is playing now, not a preference about how this application should start,
/// and a player that opened on the words of a track a week later would be
/// answering a question nobody asked.
class LyricsVisibilityController extends Notifier<bool> {
  @override
  bool build() => false;

  /// Swaps between the sleeve and the words.
  void toggle() => state = !state;
}
