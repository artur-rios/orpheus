import 'dart:typed_data';

import 'package:orpheus/features/stats/domain/story_share.dart';

/// A [StoryShare] that records rather than opening a share sheet or a file
/// dialog over the suite.
class RecordingStoryShare implements StoryShare {
  /// Creates a recorder.
  RecordingStoryShare({
    this.sharesToApps = false,
    this.outcome = StoryShareOutcome.saved,
  });

  @override
  bool sharesToApps;

  /// What [send] answers.
  StoryShareOutcome outcome;

  /// The pictures it was handed, in order.
  final List<Uint8List> sent = [];

  /// The names they were given.
  final List<String> names = [];

  @override
  Future<StoryShareOutcome> send(
    Uint8List png, {
    required String fileName,
    required String text,
  }) async {
    sent.add(png);
    names.add(fileName);

    return outcome;
  }
}
