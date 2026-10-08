import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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
    String? executable,
    this.timeout = const Duration(minutes: 10),
  }) : _client = client ?? http.Client(),
       _platform = platform,
       _downloadDirectory = downloadDirectory ?? Directory.systemTemp.path,
       _executable = executable;

  // ignore_for_file: prefer_initializing_formals

  static final Logger _log = Logger('updates');

  final http.Client _client;
  final HostPlatform _platform;
  final String _downloadDirectory;

  /// The running executable, where a test names one; otherwise the platform's.
  final String? _executable;

  /// How long a request is given to answer, and how long a download may go
  /// without a byte arriving before it is abandoned. Generous: this is tens of
  /// megabytes over whatever connection the owner has, and a slow connection
  /// is not a stalled one.
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

    final bytes = await _download(package.uri, onProgress: onProgress);

    await _verify(release, package: package, bytes: bytes);

    final File file;
    try {
      // A folder of this process's own, made fresh for this download, rather
      // than a predictable name directly in the system's temporary directory.
      // On Linux that directory is shared by every account on the machine: a
      // file another account had put at the name first — or a link to
      // somewhere else — would be the file written to, and it could be
      // swapped again between the checksum and the start. The installer runs
      // as the owner, and is offered to them to run under sudo. A folder from
      // `createTemp` is created anew and, on Linux, readable and writable by
      // its owner alone, so what is verified is what is started.
      final folder = await Directory(
        _downloadDirectory,
      ).createTemp('orpheus-update-');
      file = File(p.join(folder.path, p.basename(package.name)));
      await file.writeAsBytes(bytes, flush: true);
    } on Object catch (error) {
      _log.warning('the update could not be written to disk', error);

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

  Future<Uint8List> _download(
    Uri uri, {
    void Function(double? progress)? onProgress,
  }) async {
    // Over HTTPS or not at all. The checksum is only as trustworthy as the
    // channel it arrives on, and the package is about to be executed.
    if (!uri.isScheme('https')) {
      _log.warning('the update is not offered over HTTPS: $uri');

      throw const UpdateException(UpdateFailure.downloadFailed);
    }

    try {
      final response = await _client.send(http.Request('GET', uri)).timeout(
        timeout,
      );

      if (response.statusCode != 200) {
        _log.warning('the update download answered ${response.statusCode}');

        throw const UpdateException(UpdateFailure.downloadFailed);
      }

      final expected = response.contentLength;
      // A byte buffer rather than a `List<int>`: a growable list of integers
      // holds every byte of a fifty-megabyte installer in a slot of its own,
      // several times the size of the file itself.
      final bytes = BytesBuilder(copy: false);

      // Bounded between chunks as well as before the first: a connection that
      // stops sending without closing would otherwise leave the prompt saying
      // "downloading" for as long as the application stayed open.
      await for (final chunk in response.stream.timeout(timeout)) {
        bytes.add(chunk);
        onProgress?.call(
          expected == null || expected <= 0 ? null : bytes.length / expected,
        );
      }

      return bytes.takeBytes();
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
    if (!listing.uri.isScheme('https')) {
      _log.warning('the checksums are not offered over HTTPS: ${listing.uri}');

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

    final executable = _executable ?? Platform.resolvedExecutable;
    final prefix = p.dirname(p.dirname(p.dirname(executable)));

    if (!_canWrite(p.dirname(executable))) {
      // Quoted for the shell it will be pasted into: a prefix or a temporary
      // directory with a space in it is a path, not two arguments.
      return UpdateNeedsCommand(
        'sudo ${_quoted(installer.path)} --prefix ${_quoted(prefix)}',
      );
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

  /// [value] as one word to a POSIX shell.
  static String _quoted(String value) =>
      "'${value.replaceAll("'", r"'\''")}'";

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
