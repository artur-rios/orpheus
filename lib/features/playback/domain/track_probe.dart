/// Whether a queued file is still there to be opened.
///
/// A seam of its own, and a small one, because it is what the skip flow turns
/// on: a queue steps over a track it cannot open and names it, and a test that
/// wanted to check that behaviour would otherwise have to make a real file
/// disappear between one call and the next.
abstract interface class TrackProbe {
  /// Whether [path] exists and can be read.
  bool exists(String path);
}
