import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../../core/di/providers.dart';
import '../domain/app_release.dart';
import '../domain/app_version.dart';
import '../domain/update_installer.dart';

/// Where the update flow has got to.
enum UpdateStage {
  /// Nothing found, nothing asked, nothing to say.
  idle,

  /// A newer release exists and the owner has not answered yet.
  available,

  /// Fetching it.
  downloading,

  /// Verified, and the installer is running. This application is quitting.
  handedOff,

  /// Verified, but finishing it needs a command the owner must run.
  needsCommand,

  /// It did not work, and [UpdateState.failure] says how.
  failed,
}

/// What the update prompt is showing.
class UpdateState {
  /// Creates a state.
  const UpdateState({
    this.stage = UpdateStage.idle,
    this.release,
    this.progress,
    this.failure,
    this.command,
  });

  /// How far along it is.
  final UpdateStage stage;

  /// The release being offered, where there is one.
  final AppRelease? release;

  /// The fraction downloaded, or `null` where the size is not known.
  final double? progress;

  /// Why it failed, where it did.
  final UpdateFailure? failure;

  /// The command that finishes the job, where one is needed.
  final String? command;

  /// A copy with the given changes.
  UpdateState copyWith({
    UpdateStage? stage,
    AppRelease? release,
    double? progress,
    bool clearProgress = false,
    UpdateFailure? failure,
    String? command,
  }) => UpdateState(
    stage: stage ?? this.stage,
    release: release ?? this.release,
    progress: clearProgress ? null : progress ?? this.progress,
    failure: failure ?? this.failure,
    command: command ?? this.command,
  );
}

/// Finds new releases, and applies the one the owner accepts.
///
/// The check is quiet by design. It runs once, after the first frame, and
/// anything that is not "there is a newer version" leaves the state at
/// [UpdateStage.idle] and shows the owner nothing — a failed check is not
/// news, and a music player is not the place to be told the network is down.
class UpdateController extends Notifier<UpdateState> {
  static final Logger _log = Logger('updates');

  @override
  UpdateState build() => const UpdateState();

  /// Looks for a newer release, if the owner has left that switched on.
  ///
  /// Returns without asking anything where the platform installs its own
  /// packages, where the preference is off, where the check fails, where the
  /// newest release is the one already running, or where it is one the owner
  /// has already said no to.
  Future<void> checkAtStartup() async {
    final settings = ref.read(settingsStoreProvider);
    if (!settings.checksForUpdatesOnStartup) return;
    if (!ref.read(updateInstallerProvider).isSupported) return;

    await check(quiet: true);
  }

  /// Looks for a newer release.
  ///
  /// [quiet] is what separates the startup check from one the owner asked for:
  /// a skipped version stays skipped when nobody asked, and is offered again
  /// when somebody did.
  Future<void> check({bool quiet = false}) async {
    final current = ref.read(runningVersionProvider);
    if (current == null) {
      _log.fine('the running version is not known; not checking for updates');

      return;
    }

    final release = await ref.read(releaseSourceProvider).latest();
    if (release == null) return;

    if (!release.version.isAfter(current)) {
      _log.fine('the newest release, ${release.version}, is not after $current');

      return;
    }

    if (quiet) {
      final skipped = ref.read(settingsStoreProvider).skippedUpdateVersion;
      if (skipped == release.version.toString()) return;
    }

    state = UpdateState(stage: UpdateStage.available, release: release);
  }

  /// Downloads the offered release, checks it, and starts its installer.
  Future<void> download() async {
    final release = state.release;
    if (release == null || state.stage == UpdateStage.downloading) return;

    state = state.copyWith(
      stage: UpdateStage.downloading,
      clearProgress: true,
    );

    try {
      final outcome = await ref
          .read(updateInstallerProvider)
          .apply(
            release,
            onProgress: (progress) {
              // The controller can outlive the download when the owner closes
              // the prompt, and a state written after that is a state nobody
              // is showing.
              if (state.stage == UpdateStage.downloading) {
                state = state.copyWith(progress: progress);
              }
            },
          );

      switch (outcome) {
        case UpdateHandedOff():
          state = state.copyWith(stage: UpdateStage.handedOff);
          await ref.read(appShutdownProvider).quit();
        case UpdateNeedsCommand(:final command):
          state = state.copyWith(
            stage: UpdateStage.needsCommand,
            command: command,
          );
      }
    } on UpdateException catch (error) {
      _log.warning('the update was not applied: ${error.failure.name}');
      state = state.copyWith(
        stage: UpdateStage.failed,
        failure: error.failure,
      );
    } on Object catch (error) {
      _log.warning('the update was not applied', error);
      state = state.copyWith(
        stage: UpdateStage.failed,
        failure: UpdateFailure.downloadFailed,
      );
    }
  }

  /// Closes the prompt, leaving the release to be offered again next launch.
  void dismiss() => state = const UpdateState();

  /// Closes the prompt and does not offer this version again.
  Future<void> skip() async {
    final release = state.release;
    state = const UpdateState();
    if (release == null) return;

    try {
      await ref
          .read(settingsStoreProvider)
          .setSkippedUpdateVersion(release.version.toString());
    } on Object catch (error) {
      // Not worth telling the owner about: the cost of a failed write here is
      // being asked once more next launch.
      _log.fine('the skipped version could not be recorded', error);
    }
  }
}

/// The version this build calls itself, or `null` where it will not say.
///
/// Resolved once, in `main`, because it is a platform channel call and the
/// startup check should not be the thing waiting on one.
final runningVersionProvider = Provider<AppVersion?>((ref) => null);
