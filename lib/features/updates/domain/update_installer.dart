import 'app_release.dart';

/// How far an update got, and what the owner has to do next.
sealed class UpdateOutcome {
  const UpdateOutcome();
}

/// The installer was started, and this application is about to be replaced.
///
/// What follows is a quit: the running executable and the engine's libraries
/// are the files being overwritten, and on Windows they cannot be while a
/// process holds them open.
class UpdateHandedOff extends UpdateOutcome {
  /// Creates the outcome.
  const UpdateHandedOff();
}

/// The package is downloaded and verified, but finishing needs a terminal.
///
/// A Linux installation under a system prefix, which is the one case the
/// application cannot complete for the owner: replacing files under
/// `/usr/local` needs root, and there is no password prompt to raise from a
/// process the desktop launched.
class UpdateNeedsCommand extends UpdateOutcome {
  /// Creates the outcome, naming the [command] to run.
  const UpdateNeedsCommand(this.command);

  /// The command the owner should run, ready to paste.
  final String command;
}

/// Why an update could not be applied.
enum UpdateFailure {
  /// The release carries no package for this platform.
  noPackage,

  /// The download did not finish.
  downloadFailed,

  /// What arrived is not what the release says it published.
  ///
  /// The one failure here that is never a retry: a package whose checksum does
  /// not match the published one is not a slow network, and running it is
  /// exactly the thing this refuses to do.
  checksumMismatch,

  /// The package downloaded and verified, but would not start.
  launchFailed,
}

/// Raised by [UpdateInstaller] when an update cannot be applied.
class UpdateException implements Exception {
  /// Creates an exception carrying [failure].
  const UpdateException(this.failure);

  /// What went wrong.
  final UpdateFailure failure;

  @override
  String toString() => 'UpdateException(${failure.name})';
}

/// Fetches a release's package for this platform and starts it.
abstract interface class UpdateInstaller {
  /// Whether this host can be updated from inside the application at all.
  bool get isSupported;

  /// Downloads [release]'s package, checks it, and starts it.
  ///
  /// [onProgress] is called with a fraction from 0 to 1 where the size is
  /// known, and with `null` where the server did not say how big the file is.
  ///
  /// Throws [UpdateException]. Nothing is started that has not been checked
  /// against the release's own `SHA256SUMS.txt`.
  Future<UpdateOutcome> apply(
    AppRelease release, {
    void Function(double? progress)? onProgress,
  });
}
