import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../domain/lyrics.dart';

/// One track's words, looked for once and kept while the player shows them.
///
/// Asynchronous because finding them is a file read — a sidecar, or the
/// track's own header — and the screen cannot wait on a disk. It answers
/// `null` for every track this machine holds no words for, which is most of
/// them in most libraries, and the panel says so rather than showing an empty
/// frame.
///
/// Keyed by the track's path and auto-disposed with it, for the reason the
/// spectrum is: a queue moves on, and the words of every track ever played
/// would otherwise be held for the life of the container.
class LyricsController extends AsyncNotifier<Lyrics?> {
  /// Creates the controller for the track at [path].
  LyricsController(this.path);

  /// The track whose words these are.
  final String path;

  @override
  Future<Lyrics?> build() {
    // Read before the first await: the owner who closes the player mid-read
    // disposes this, and reaching for a dependency after that throws.
    final source = ref.read(lyricsSourceProvider);

    return source.of(path);
  }
}
