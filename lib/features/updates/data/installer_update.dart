import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import '../../../core/platform/host_platform.dart';
import '../domain/app_release.dart';
import '../domain/update_installer.dart';

/// [UpdateInstaller] that hands the release's own installer the job.
///
/// The application cannot replace itself while it is running. On Windows the
/// executable and the engine's libraries are open and locked by this very
/// process; on Linux they can be unlinked, but the code still executing is the
/// code being replaced. So what this does is fetch the installer that already
/// exists — the one a person would have downloaded by hand — check it, start
/// it, and get out of the way.
///
/// That also means the upgrade is the upgrade that has been tested. Both
/// installers already remove the previous version before laying down the new
/// one, including the targeted sweep that keeps a stale engine library out of
/// the new bundle, and neither touches the owner's catalog, statistics or
/// settings.
///
/// **Nothing is started that has not been verified.** The release publishes a
/// `SHA256SUMS.txt` beside its packages; this fetches it, finds the line for
/// the file it downloaded, and refuses on any mismatch. An executable arriving
/// over a network and being run is the one place in this application where
/// that check is not a nicety.
class InstallerUpdate implements UpdateInstaller {
  /// Creates an installer over [client].
  InstallerUpdate({
    http.Client? client,
    HostPlatform platform = const HostPlatform(),
    String? downloadDirectory,
    this.timeout = const Duration(minutes: 10),
  }) : _client = client ?? http.Client(),
       _platform = platform,
       _downloadDirectory = downloadDirectory ?? Directory.systemTemp.path;

  // ignore_for_file: prefer_initializing_formals

  static final Logger _log = Logger('updates');

  final http.Client _client;
  final HostPlatform _platform;
  final String _downloadDirectory;

  /// How long a download is given. Generous: this is tens of megabytes over
  /// whatever connection the owner has.
  final Duration timeout;

  @override
  bool get isSupported => _platform.isDesktop;

  @override
  Future<UpdateOutcome> apply(
    AppRelease release, {
    void Function(double? progress)? onProgress,
  }) async {
    final package = _packageFor(release);
    if (package == null) throw const UpdateException(UpdateFailure.noPackage);

    final file = File(p.join(_downloadDirectory, package.name));
    final bytes = await _download(package.uri, onProgress: onProgress);

    await _verify(release, package: package, bytes: bytes);

    try {
      await file.writeAsBytes(bytes, flush: true);
    } on Object catch (error) {
      _log.warning('the update could not be written to $file', error);

      throw const UpdateException(UpdateFailure.downloadFailed);
    }

    return _platform.isWindows ? _startOnWindows(file) : _startOnLinux(file);
  }

  /// The package this host installs from, or `null` where the release has none.
  ///
  /// Matched on the file name the release workflow gives it. The portable
  /// archive is deliberately not a candidate: it installs nothing, so replacing
  /// an installed copy with one would leave the owner with two.
  ReleaseDownload? _packageFor(AppRelease release) {
    if (_platform.isWindows) return release.downloadMatching('orpheus-setup-');
    if (_platform.isLinux) return release.downloadMatching('orpheus-installer-');

    return null;
  }

  Future<List<int>> _download(
    Uri uri, {
    void Function(double? progress)? onProgress,
  }) async {
    try {
      final response = await _client.send(http.Request('GET', uri)).timeout(
        timeout,
      );

      if (response.statusCode != 200) {
        _log.warning('the update download answered ${response.statusCode}');

        throw const UpdateException(UpdateFailure.downloadFailed);
      }

      final expected = response.contentLength;
      final bytes = <int>[];

      await for (final chunk in response.stream) {
        bytes.addAll(chunk);
        onProgress?.call(
          expected == null || expected <= 0 ? null : bytes.length / expected,
        );
      }

      return bytes;
    } on UpdateException {
      rethrow;
    } on Object catch (error) {
      _log.warning('the update could not be downloaded from $uri', error);

      throw const UpdateException(UpdateFailure.downloadFailed);
    }
  }

  /// Checks [bytes] against the checksum the release published for [package].
  ///
  /// A release with no `SHA256SUMS.txt`, one that cannot be fetched, and one
  /// that does not name this file are all refusals rather than a shrug. The
  /// alternative to a checksum is not "no checksum", it is running whatever
  /// arrived.
  Future<void> _verify(
    AppRelease release, {
    required ReleaseDownload package,
    required List<int> bytes,
  }) async {
    final listing = release.checksums;
    if (listing == null) {
      _log.warning('the release publishes no checksums');

      throw const UpdateException(UpdateFailure.checksumMismatch);
    }

    final String published;
    try {
      final response = await _client.get(listing.uri).timeout(timeout);
      if (response.statusCode != 200) {
        throw const UpdateException(UpdateFailure.checksumMismatch);
      }
      published = response.body;
    } on UpdateException {
      rethrow;
    } on Object catch (error) {
      _log.warning('the checksums could not be fetched', error);

      throw const UpdateException(UpdateFailure.checksumMismatch);
    }

    final expected = _checksumOf(package.name, in_: published);
    if (expected == null) {
      _log.warning('the checksums do not mention ${package.name}');

      throw const UpdateException(UpdateFailure.checksumMismatch);
    }

    final actual = sha256.convert(bytes).toString();
    if (actual.toLowerCase() != expected.toLowerCase()) {
      _log.severe(
        'the downloaded ${package.name} hashes to $actual, but the release '
        'publishes $expected — it will not be run',
      );

      throw const UpdateException(UpdateFailure.checksumMismatch);
    }
  }

  /// The digest [listing] gives for [name], or `null` where it gives none.
  ///
  /// `sha256sum` format: the digest, whitespace, an optional `*`, the name.
  static String? _checksumOf(String name, {required String in_}) {
    for (final line in const LineSplitter().convert(in_)) {
      final parts = line.trim().split(RegExp(r'\s+'));
      if (parts.length < 2) continue;

      final named = parts.last.replaceFirst(RegExp(r'^\*'), '');
      if (p.basename(named) == name) return parts.first;
    }

    return null;
  }

  /// Starts the Windows setup executable and reports that this must now quit.
  ///
  /// Started with its ordinary wizard rather than silently, and that is not
  /// laziness: the installer removes a previous version from
  /// `NextButtonClick(wpSelectDir)`, which is a wizard-page callback. A silent
  /// run shows no pages, so it would never fire, and the sweep that keeps a
  /// previous release's engine library out of the new bundle would be skipped.
  Future<UpdateOutcome> _startOnWindows(File installer) async {
    try {
      await Process.start(
        installer.path,
        const [],
        mode: ProcessStartMode.detached,
      );

      return const UpdateHandedOff();
    } on Object catch (error) {
      _log.warning('the installer would not start', error);

      throw const UpdateException(UpdateFailure.launchFailed);
    }
  }

  /// Runs the Linux installer where this owner can, and says how where they
  /// cannot.
  ///
  /// The prefix is read from where this executable actually is rather than
  /// guessed: the bundle lives at `<prefix>/lib/orpheus/orpheus`, so the
  /// prefix is three directories up. An installation the owner can write to is
  /// updated in place and this application restarts itself; one under a system
  /// prefix needs root, and there is no password prompt to raise from a
  /// process the desktop launched — so the command is handed back instead.
  Future<UpdateOutcome> _startOnLinux(File installer) async {
    try {
      await Process.run('chmod', ['+x', installer.path]);
    } on Object catch (error) {
      _log.warning('the installer could not be made executable', error);

      throw const UpdateException(UpdateFailure.launchFailed);
    }

    final executable = Platform.resolvedExecutable;
    final prefix = p.dirname(p.dirname(p.dirname(executable)));

    if (!_canWrite(p.dirname(executable))) {
      return UpdateNeedsCommand('sudo ${installer.path} --prefix $prefix');
    }

    try {
      // Positional arguments rather than an interpolated command line: a
      // prefix holding a space or a quote is a path, not a syntax error.
      await Process.start(
        '/bin/sh',
        ['-c', r'"$0" --prefix "$1" && exec "$2"', installer.path, prefix, executable],
        mode: ProcessStartMode.detached,
      );

      return const UpdateHandedOff();
    } on Object catch (error) {
      _log.warning('the installer would not start', error);

      throw const UpdateException(UpdateFailure.launchFailed);
    }
  }

  /// Whether this process may write into [directory].
  ///
  /// Asked by trying, because that is the only answer that is true: a
  /// directory can be unwritable for ownership, for a mount option, or for a
  /// policy none of which are visible in its mode bits.
  static bool _canWrite(String directory) {
    final probe = File(p.join(directory, '.orpheus-update-probe'));
    try {
      probe.writeAsStringSync('');
      probe.deleteSync();

      return true;
    } on Object {
      return false;
    }
  }
}
