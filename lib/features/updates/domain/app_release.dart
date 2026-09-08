import 'app_version.dart';

/// One file published with a release.
class ReleaseDownload {
  /// Creates a download.
  const ReleaseDownload({required this.name, required this.uri});

  /// The file name, which is what identifies it: `orpheus-setup-1.0.1.exe`.
  final String name;

  /// Where to fetch it.
  final Uri uri;
}

/// A release of this application, as the place that publishes them describes it.
class AppRelease {
  /// Creates a release.
  const AppRelease({
    required this.version,
    required this.downloads,
    this.notes,
  });

  /// Which version it is.
  final AppVersion version;

  /// The files attached to it.
  final List<ReleaseDownload> downloads;

  /// What the release says about itself, where it says anything.
  final String? notes;

  /// The download whose name matches [pattern], or `null` where none does.
  ReleaseDownload? downloadMatching(Pattern pattern) {
    for (final download in downloads) {
      if (download.name.contains(pattern)) return download;
    }

    return null;
  }

  /// The checksum listing published beside the packages.
  ///
  /// Its presence is not optional in practice: [downloadMatching] finds the
  /// installer, and nothing runs an installer this has not been checked
  /// against.
  ReleaseDownload? get checksums => downloadMatching('SHA256SUMS');
}
