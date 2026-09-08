import 'package:orpheus/core/platform/app_shutdown.dart';
import 'package:orpheus/features/updates/domain/app_release.dart';
import 'package:orpheus/features/updates/domain/app_version.dart';
import 'package:orpheus/features/updates/domain/release_source.dart';
import 'package:orpheus/features/updates/domain/update_installer.dart';

/// A [ReleaseSource] that answers whatever the test scripted.
class ScriptedReleaseSource implements ReleaseSource {
  /// Creates a source answering [release].
  ScriptedReleaseSource([this.release]);

  /// What a check finds, or `null` for a check that finds nothing.
  AppRelease? release;

  /// How many times it was asked, which is how a test asserts the check is not
  /// made when the preference is off.
  int checks = 0;

  /// Whether the connection was released.
  bool closed = false;

  @override
  Future<AppRelease?> latest() async {
    checks++;

    return release;
  }

  @override
  void close() => closed = true;
}

/// An [UpdateInstaller] that records rather than downloading or starting
/// anything.
class ScriptedUpdateInstaller implements UpdateInstaller {
  /// Creates an installer answering [outcome].
  ScriptedUpdateInstaller({
    this.outcome = const UpdateHandedOff(),
    this.failure,
    this.isSupported = true,
  });

  /// What [apply] answers where it does not throw.
  UpdateOutcome outcome;

  /// What [apply] throws instead of answering, where a test wants a failure.
  UpdateFailure? failure;

  @override
  bool isSupported;

  /// The releases it was asked to apply, in order.
  final List<AppRelease> applied = [];

  /// Fractions to report before answering, so a test can watch the progress.
  List<double?> progress = const [];

  @override
  Future<UpdateOutcome> apply(
    AppRelease release, {
    void Function(double? progress)? onProgress,
  }) async {
    applied.add(release);
    for (final fraction in progress) {
      onProgress?.call(fraction);
    }

    final thrown = failure;
    if (thrown != null) throw UpdateException(thrown);

    return outcome;
  }
}

/// An [AppShutdown] that records rather than closing the test's own window.
class RecordingAppShutdown implements AppShutdown {
  /// How many times the application was asked to quit.
  int quits = 0;

  @override
  Future<void> quit() async => quits++;
}

/// A release, for the tests that need one to offer.
AppRelease release({
  String version = '9.9.9',
  List<String> downloads = const [
    'orpheus-setup-9.9.9.exe',
    'orpheus-installer-9.9.9.sh',
    'SHA256SUMS.txt',
  ],
  String? notes,
}) => AppRelease(
  version: AppVersion.tryParse(version)!,
  downloads: [
    for (final name in downloads)
      ReleaseDownload(
        name: name,
        uri: Uri.parse('https://example.invalid/$name'),
      ),
  ],
  notes: notes,
);
