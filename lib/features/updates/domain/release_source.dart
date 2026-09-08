import 'app_release.dart';

/// Where the application looks to find out whether it is out of date.
///
/// An interface for the same reason the lyrics lookup has one: it is the
/// second and last thing in this application that reaches a network, and a
/// test standing in front of it is what keeps the suite from opening a socket.
abstract interface class ReleaseSource {
  /// The most recent release, or `null` where there is none to report.
  ///
  /// Never throws. A refused connection, a rate limit, an aeroplane and a body
  /// that is not the JSON it claims are all the same `null`: the owner is
  /// running a version that works, and a failed check is not news.
  Future<AppRelease?> latest();

  /// Releases the connections this holds.
  void close();
}
