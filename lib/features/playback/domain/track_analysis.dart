import 'track_energy.dart';

/// What turns a file on disk into the spectrum the sound bars draw.
///
/// A seam, and one worth having: the real implementation decodes audio with
/// libmpv and runs a transform over every window of it, which is the one part
/// of this feature that needs a codec, a temporary file and an isolate. Above
/// this line the application asks for a track's spectrum and gets one, or gets
/// `null` and shows the stand-in, and both paths are testable without any of
/// that.
abstract interface class TrackAnalysis {
  /// The spectrum of the track at [path], or `null` where there is none.
  ///
  /// `null` rather than a throw for every ordinary failure — a file that is
  /// gone, a codec that is missing, a format nothing here can read — because
  /// none of them is something an owner can act on, and all of them have the
  /// same answer on screen: the bars show the stand-in instead.
  Future<MeasuredEnergy?> of(String path);
}
