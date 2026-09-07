import 'package:path/path.dart' as p;

/// Where this application keeps what it writes.
///
/// Resolved once, before the first frame, and bound into the provider graph —
/// rather than asked of `path_provider` wherever a path is needed, which would
/// be an await in the middle of code that has no business being asynchronous
/// and a different answer in a test than in the application.
class AppDirectories {
  /// Creates the set rooted at [support].
  const AppDirectories(this.support);

  /// The application's own support directory.
  ///
  /// The catalog document lives directly in it.
  final String support;

  /// Where extracted cover pictures are cached.
  String get covers => p.join(support, 'covers');

  /// Where the analysed spectra the sound bars are drawn from are cached.
  ///
  /// Beside the pictures rather than among them: both are caches that an owner
  /// may delete without losing anything but the work of building them again,
  /// and keeping them apart is what makes either one deletable on its own.
  String get energy => p.join(support, 'energy');

  /// Where a decode writes the audio it is about to analyse.
  ///
  /// Apart from [energy], which it used to share. What lands here is one
  /// multi-megabyte WAV per track being analysed and it is deleted the moment
  /// the transform is done, where what lands in [energy] is a hundred
  /// kilobytes per track and is meant to survive; mixing the two put working
  /// files in a cache directory an owner is invited to inspect, and put the
  /// cache within reach of a `clear()` that deletes its whole directory.
  String get scratch => p.join(support, 'scratch');
}
