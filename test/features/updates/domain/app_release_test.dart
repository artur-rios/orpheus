import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/updates/domain/app_release.dart';
import 'package:orpheus/features/updates/domain/app_version.dart';

/// Finding a file among the ones a release publishes.
void main() {
  ReleaseDownload downloadOf(String name) => ReleaseDownload(
    name: name,
    uri: Uri.https('example.invalid', '/$name'),
  );

  AppRelease releaseWith(List<String> names) => AppRelease(
    version: AppVersion.tryParse('9.9.9')!,
    downloads: [for (final name in names) downloadOf(name)],
  );

  test(
    'GivenAReleaseWithItsPackages_WhenAPackageIsLookedFor_ThenItsDownloadIsFound',
    () {
      final release = releaseWith([
        'orpheus-installer-9.9.9.sh',
        'orpheus-setup-9.9.9.exe',
        'SHA256SUMS.txt',
      ]);

      final found = release.downloadMatching('orpheus-setup-')!;

      expect(found.name, 'orpheus-setup-9.9.9.exe');
      expect(
        found.uri,
        Uri.https('example.invalid', '/orpheus-setup-9.9.9.exe'),
      );
    },
  );

  test(
    'GivenTwoMatchingFiles_WhenOneIsLookedFor_ThenTheFirstPublishedIsFound',
    () {
      final release = releaseWith([
        'orpheus-9.9.9-android.apk',
        'orpheus-9.9.9-android-debug-signed.apk',
      ]);

      expect(
        release.downloadMatching(RegExp(r'android.*\.apk$'))!.name,
        'orpheus-9.9.9-android.apk',
      );
    },
  );

  test('GivenNoMatchingFile_WhenOneIsLookedFor_ThenNoneIsFound', () {
    final release = releaseWith(['orpheus-installer-9.9.9.sh']);

    expect(release.downloadMatching('orpheus-setup-'), isNull);
  });

  test('GivenAReleaseWithNoFiles_WhenOneIsLookedFor_ThenNoneIsFound', () {
    expect(releaseWith([]).downloadMatching('orpheus'), isNull);
  });

  test(
    'GivenAPublishedChecksumListing_WhenTheChecksumsAreAskedFor_ThenItIsFound',
    () {
      final release = releaseWith([
        'orpheus-setup-9.9.9.exe',
        'SHA256SUMS.txt',
      ]);

      expect(release.checksums!.name, 'SHA256SUMS.txt');
    },
  );

  test(
    'GivenNoChecksumListing_WhenTheChecksumsAreAskedFor_ThenThereAreNone',
    () {
      expect(releaseWith(['orpheus-setup-9.9.9.exe']).checksums, isNull);
    },
  );
}
