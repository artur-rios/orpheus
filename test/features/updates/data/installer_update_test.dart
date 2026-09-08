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
      expect(
        File('${downloads.path}/orpheus-setup-9.9.9.exe').existsSync(),
        isTrue,
      );
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
