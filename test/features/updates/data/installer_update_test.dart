import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:orpheus/core/platform/host_platform.dart';
import 'package:orpheus/features/updates/data/installer_update.dart';
import 'package:orpheus/features/updates/domain/app_release.dart';
import 'package:orpheus/features/updates/domain/app_version.dart';
import 'package:orpheus/features/updates/domain/update_installer.dart';
import 'package:path/path.dart' as p;

/// What is downloaded, and what is refused.
///
/// This is the one place in the application that fetches an executable and
/// runs it, so what these assert is mostly the refusals: an installer whose
/// checksum does not match what the release published must never be started,
/// and neither must one the release did not vouch for at all.
void main() {
  final package = utf8.encode('a plausible installer');
  final digest = sha256.convert(package).toString();

  AppRelease releaseOf({List<String> names = const [
    'orpheus-setup-9.9.9.exe',
    'orpheus-installer-9.9.9.sh',
    'SHA256SUMS.txt',
  ]}) => AppRelease(
    version: AppVersion.tryParse('9.9.9')!,
    downloads: [
      for (final name in names)
        ReleaseDownload(
          name: name,
          uri: Uri.parse('https://example.invalid/$name'),
        ),
    ],
  );

  /// A client serving [sums] as the checksum listing and [package] as any
  /// other file.
  http.Client clientServing(String sums) => MockClient((request) async {
    if (request.url.path.endsWith('SHA256SUMS.txt')) {
      return http.Response(sums, 200);
    }

    return http.Response.bytes(package, 200);
  });

  late Directory downloads;

  setUp(() => downloads = Directory.systemTemp.createTempSync('orpheus-test'));
  tearDown(() => downloads.deleteSync(recursive: true));

  /// Every file called [name] anywhere under the download directory.
  List<File> downloaded(String name) => [
    for (final entity in downloads.listSync(recursive: true))
      if (entity is File && entity.uri.pathSegments.last == name) entity,
  ];

  Future<UpdateOutcome> apply(
    http.Client client, {
    HostPlatform platform = const _Windows(),
    AppRelease? release,
  }) => InstallerUpdate(
    client: client,
    platform: platform,
    downloadDirectory: downloads.path,
  ).apply(release ?? releaseOf());

  test(
    'GivenAPackageWhoseChecksumDoesNotMatch_WhenAnUpdateIsApplied_ThenItIsNotRun',
    () async {
      // The whole reason the checksum is fetched. A package that is not what
      // the release published is not a slow network to retry through — it is
      // something that must not be executed, whatever it is.
      final client = clientServing(
        '${'0' * 64}  orpheus-setup-9.9.9.exe\n',
      );

      await expectLater(
        apply(client),
        throwsA(
          isA<UpdateException>().having(
            (error) => error.failure,
            'failure',
            UpdateFailure.checksumMismatch,
          ),
        ),
      );
    },
  );

  test(
    'GivenAReleaseThatPublishesNoChecksums_WhenAnUpdateIsApplied_ThenItIsRefused',
    () async {
      // The alternative to a checksum is not "no checksum". It is running
      // whatever arrived.
      final release = releaseOf(names: const ['orpheus-setup-9.9.9.exe']);

      await expectLater(
        apply(clientServing(''), release: release),
        throwsA(
          isA<UpdateException>().having(
            (error) => error.failure,
            'failure',
            UpdateFailure.checksumMismatch,
          ),
        ),
      );
    },
  );

  test(
    'GivenChecksumsThatDoNotNameThisPackage_WhenAnUpdateIsApplied_ThenItIsRefused',
    () async {
      final client = clientServing('$digest  something-else.exe\n');

      await expectLater(
        apply(client),
        throwsA(
          isA<UpdateException>().having(
            (error) => error.failure,
            'failure',
            UpdateFailure.checksumMismatch,
          ),
        ),
      );
    },
  );

  test(
    'GivenAReleaseWithNoPackageForThisSystem_WhenAnUpdateIsApplied_ThenItSaysSo',
    () async {
      final release = releaseOf(
        names: const ['orpheus-9.9.9-android.apk', 'SHA256SUMS.txt'],
      );

      await expectLater(
        apply(clientServing('$digest  x'), release: release),
        throwsA(
          isA<UpdateException>().having(
            (error) => error.failure,
            'failure',
            UpdateFailure.noPackage,
          ),
        ),
      );
    },
  );

  test(
    'GivenAPortableArchiveBesideTheInstaller_WhenAPackageIsChosen_ThenTheInstallerIsTaken',
    () async {
      // The portable zip installs nothing. Updating an installed copy with one
      // would leave the owner running two.
      final release = releaseOf(
        names: const [
          'orpheus-9.9.9-windows-x64-portable.zip',
          'orpheus-setup-9.9.9.exe',
          'SHA256SUMS.txt',
        ],
      );
      final client = clientServing('$digest  orpheus-setup-9.9.9.exe\n');

      // Refused at the launch rather than the choice: this host cannot start a
      // Windows executable, which is itself the proof of which one was picked.
      await expectLater(
        apply(client, release: release),
        throwsA(
          isA<UpdateException>().having(
            (error) => error.failure,
            'failure',
            UpdateFailure.launchFailed,
          ),
        ),
      );
      expect(downloaded('orpheus-setup-9.9.9.exe'), hasLength(1));
    },
  );

  test(
    'GivenTheListingFormatTheWorkflowActuallyWrites_WhenItIsRead_ThenTheNameIsFound',
    () async {
      // The published SHA256SUMS.txt names each file as `./name`, because that
      // is how the workflow's `sha256sum *` writes it. A parser that compared
      // the whole field would match nothing and refuse every update.
      final client = clientServing(
        '$digest  ./orpheus-setup-9.9.9.exe\n'
        '${'0' * 64}  ./orpheus-9.9.9-android.apk\n',
      );

      await expectLater(
        apply(client),
        throwsA(
          isA<UpdateException>().having(
            (error) => error.failure,
            'failure',
            // Past the checksum, and stopped only by this host being unable to
            // start a Windows executable.
            UpdateFailure.launchFailed,
          ),
        ),
      );
    },
  );

  test(
    'GivenAChecksumListingWithABinaryMarker_WhenItIsRead_ThenTheMarkerIsNotPartOfTheName',
    () async {
      // `sha256sum -b` writes `<digest> *<name>`, and the workflow's listing is
      // read rather than dictated to.
      final client = clientServing('$digest *orpheus-setup-9.9.9.exe\n');

      await expectLater(
        apply(client),
        throwsA(
          isA<UpdateException>().having(
            (error) => error.failure,
            'failure',
            // Past the checksum, and stopped only by this host being unable to
            // start a Windows executable.
            UpdateFailure.launchFailed,
          ),
        ),
      );
    },
  );

  test(
    'GivenAPackageOfferedOverPlainHttp_WhenAnUpdateIsApplied_ThenNothingIsFetched',
    () async {
      // The checksum is only as good as the channel it came over, and what is
      // being fetched is about to be executed.
      var requests = 0;
      final client = MockClient((request) async {
        requests++;

        return http.Response.bytes(package, 200);
      });
      final release = AppRelease(
        version: AppVersion.tryParse('9.9.9')!,
        downloads: [
          for (final name in ['orpheus-setup-9.9.9.exe', 'SHA256SUMS.txt'])
            ReleaseDownload(
              name: name,
              uri: Uri.parse('http://example.invalid/$name'),
            ),
        ],
      );

      await expectLater(
        apply(client, release: release),
        throwsA(
          isA<UpdateException>().having(
            (error) => error.failure,
            'failure',
            UpdateFailure.downloadFailed,
          ),
        ),
      );
      expect(requests, 0);
    },
  );

  test(
    'GivenAFileAlreadyAtTheInstallersName_WhenAnUpdateIsApplied_ThenItIsNeitherWrittenNorRun',
    () async {
      // The system's temporary directory is shared by every account on a
      // Linux machine, so a file waiting at the name the installer would be
      // given is somebody else's file — or a link to somewhere else entirely.
      // Joined with the host's separator: the paths a directory listing
      // returns use it, and the planted file is told apart by its path.
      final waiting = File(p.join(downloads.path, 'orpheus-setup-9.9.9.exe'))
        ..writeAsStringSync('not yours');
      final client = clientServing('$digest  orpheus-setup-9.9.9.exe\n');

      await expectLater(
        apply(client),
        throwsA(
          isA<UpdateException>().having(
            (error) => error.failure,
            'failure',
            UpdateFailure.launchFailed,
          ),
        ),
      );

      expect(waiting.readAsStringSync(), 'not yours');
      final written = downloaded('orpheus-setup-9.9.9.exe')
          .where((file) => !p.equals(file.path, waiting.path))
          .single;
      expect(written.readAsBytesSync(), package);
      expect(p.equals(written.parent.path, downloads.path), isFalse);
    },
  );

  test(
    'GivenADownloadThatStopsArriving_WhenAnUpdateIsApplied_ThenItIsAbandoned',
    () async {
      final stalled = StreamController<List<int>>();
      addTearDown(stalled.close);
      final client = MockClient.streaming(
        (request, _) async => http.StreamedResponse(stalled.stream, 200),
      );

      await expectLater(
        InstallerUpdate(
          client: client,
          platform: const _Windows(),
          downloadDirectory: downloads.path,
          timeout: const Duration(milliseconds: 50),
        ).apply(releaseOf()),
        throwsA(
          isA<UpdateException>().having(
            (error) => error.failure,
            'failure',
            UpdateFailure.downloadFailed,
          ),
        ),
      );
    },
  );

  test(
    'GivenAnInstallationTheOwnerCannotWriteTo_WhenTheLinuxUpdateIsReady_ThenTheCommandSurvivesASpaceInThePath',
    () async {
      final client = clientServing('$digest  orpheus-installer-9.9.9.sh\n');

      final outcome = await InstallerUpdate(
        client: client,
        platform: const _Linux(),
        downloadDirectory: downloads.path,
        executable: '/opt/no such place/lib/orpheus/orpheus',
      ).apply(releaseOf());

      final installer = downloaded('orpheus-installer-9.9.9.sh').single.path;
      expect(
        (outcome as UpdateNeedsCommand).command,
        "sudo '$installer' --prefix '/opt/no such place'",
      );
    },
    // `chmod` is how the installer is made executable, and only a POSIX host
    // has one.
    skip: Platform.isWindows,
  );
}

/// A host that reports itself as Windows, whatever the suite is running on.
class _Windows implements HostPlatform {
  const _Windows();

  @override
  bool get isWindows => true;

  @override
  bool get isLinux => false;

  @override
  bool get isAndroid => false;

  @override
  bool get isDesktop => true;

  @override
  bool get needsStoragePermission => false;

  @override
  String? get homeDirectory => null;
}

/// A host that reports itself as Linux, whatever the suite is running on.
class _Linux implements HostPlatform {
  const _Linux();

  @override
  bool get isWindows => false;

  @override
  bool get isLinux => true;

  @override
  bool get isAndroid => false;

  @override
  bool get isDesktop => true;

  @override
  bool get needsStoragePermission => false;

  @override
  String? get homeDirectory => null;
}
