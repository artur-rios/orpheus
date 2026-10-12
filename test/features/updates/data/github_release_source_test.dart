import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:orpheus/features/updates/data/github_release_source.dart';

/// Reading the release listing, and answering nothing rather than failing.
void main() {
  Map<String, Object> entry({
    String tag = 'v1.2.0',
    bool prerelease = false,
    bool draft = false,
    List<String> assets = const ['orpheus-setup-1.2.0.exe', 'SHA256SUMS.txt'],
  }) => {
    'tag_name': tag,
    'prerelease': prerelease,
    'draft': draft,
    'body': 'What changed.',
    'html_url': 'https://github.com/artur-rios/orpheus/releases/tag/$tag',
    'assets': [
      for (final name in assets)
        {
          'name': name,
          'browser_download_url': 'https://github.com/x/y/releases/$name',
        },
    ],
  };

  String listing({
    String tag = 'v1.2.0',
    bool prerelease = false,
    bool draft = false,
  }) => jsonEncode(entry(tag: tag, prerelease: prerelease, draft: draft));

  test(
    'GivenAPublishedRelease_WhenTheLatestIsRead_ThenItsVersionAndPackagesComeBack',
    () async {
      final source = GitHubReleaseSource(
        client: MockClient((_) async => http.Response(listing(), 200)),
      );

      final release = await source.latest();

      expect(release!.version.toString(), '1.2.0');
      expect(release.downloadMatching('orpheus-setup-')!.name,
          'orpheus-setup-1.2.0.exe');
      expect(release.checksums, isNotNull);
      expect(release.notes, 'What changed.');
    },
  );

  test(
    'GivenAPreReleaseOrADraft_WhenTheLatestIsRead_ThenNothingIsOffered',
    () async {
      // GitHub keeps both out of `/releases/latest`, but a body that says it
      // is one is believed over the endpoint it arrived from: a beta published
      // for testing is not an update for everybody running the stable build.
      for (final body in [
        listing(prerelease: true),
        listing(draft: true),
      ]) {
        final source = GitHubReleaseSource(
          client: MockClient((_) async => http.Response(body, 200)),
        );

        expect(await source.latest(), isNull);
      }
    },
  );

  test(
    'GivenAStableBuild_WhenTheLatestIsRead_ThenOnlyTheLatestReleaseIsAskedFor',
    () async {
      final asked = <Uri>[];
      final source = GitHubReleaseSource(
        client: MockClient((request) async {
          asked.add(request.url);

          return http.Response(listing(), 200);
        }),
      );

      await source.latest();

      expect(asked.single.path, '/repos/artur-rios/orpheus/releases/latest');
    },
  );

  test(
    'GivenAPreReleaseBuild_WhenTheNewestIsRead_ThenTheHighestVersionPublishedComesBack',
    () async {
      // Somebody testing a beta is offered the next beta and then the release
      // it leads to — in SemVer order, not in the order GitHub lists them, and
      // never a draft or a tag that names no version.
      final asked = <Uri>[];
      final listings = [
        [
          entry(tag: 'v1.3.0-beta.2', prerelease: true),
          entry(tag: 'v1.3.0', assets: ['orpheus-setup-1.3.0.exe']),
          entry(tag: 'v1.3.0-beta.10', prerelease: true),
          entry(tag: 'v1.4.0', draft: true),
          entry(tag: 'nightly', prerelease: true),
          entry(tag: 'v1.2.1'),
        ],
        [
          entry(tag: 'v1.3.0-beta.2', prerelease: true),
          entry(tag: 'v1.3.0-beta.10', prerelease: true),
          entry(tag: 'v1.2.1'),
        ],
      ];
      final expected = ['1.3.0', '1.3.0-beta.10'];

      for (var index = 0; index < listings.length; index++) {
        final source = GitHubReleaseSource(
          client: MockClient((request) async {
            asked.add(request.url);

            return http.Response(jsonEncode(listings[index]), 200);
          }),
        );

        final release = await source.latest(includePreReleases: true);

        expect(release!.version.toString(), expected[index]);
      }

      expect(asked.first.path, '/repos/artur-rios/orpheus/releases');
    },
  );

  test(
    'GivenTheListCannotBeRead_WhenTheNewestIsReadForAPreRelease_ThenItAnswersNothingRatherThanThrowing',
    () async {
      final clients = [
        MockClient((_) async => http.Response('', 500)),
        MockClient((_) async => http.Response(listing(), 200)),
        MockClient((_) async => http.Response('[]', 200)),
        MockClient((_) async => http.Response('[1, "two"]', 200)),
        MockClient((_) async => throw const SocketExceptionStub()),
      ];

      for (final client in clients) {
        expect(
          await GitHubReleaseSource(client: client).latest(includePreReleases: true),
          isNull,
        );
      }
    },
  );

  test(
    'GivenTheCheckCannotBeMade_WhenTheLatestIsRead_ThenItAnswersNothingRatherThanThrowing',
    () async {
      // A failed check is not news. The owner is running a version that works,
      // and a music player is not where they should be told the network is
      // down.
      final clients = [
        MockClient((_) async => http.Response('', 500)),
        MockClient((_) async => http.Response('{"message":"rate limited"}', 403)),
        MockClient((_) async => http.Response('<html>a captive portal', 200)),
        MockClient((_) async => http.Response(jsonEncode({'tag_name': 'nightly'}), 200)),
        MockClient((_) async => throw const SocketExceptionStub()),
      ];

      for (final client in clients) {
        expect(await GitHubReleaseSource(client: client).latest(), isNull);
      }
    },
  );
}

/// Stands in for a refused connection without importing `dart:io` into a test
/// that otherwise needs none of it.
class SocketExceptionStub implements Exception {
  const SocketExceptionStub();
}
