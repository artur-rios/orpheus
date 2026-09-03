import 'package:orpheus/features/playback/domain/track_probe.dart';

/// A [TrackProbe] that answers from a set the test controls.
///
/// The default is that everything exists, which is the ordinary case; a test
/// about the skip flow names the files that do not.
class FakeTrackProbe implements TrackProbe {
  /// Creates a probe for which every path exists except [missing].
  FakeTrackProbe({Set<String>? missing}) : missing = missing ?? {};

  /// The paths that will not open.
  final Set<String> missing;

  @override
  bool exists(String path) => !missing.contains(path);
}
