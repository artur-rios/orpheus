import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:orpheus/features/updates/data/github_release_source.dart';

/// Reading the release listing, and answering nothing rather than failing.
void main() {
  String listing({
    String tag = 'v1.2.0',
    bool prerelease = false,
    bool draft = false,
    List<String> assets = const ['orpheus-setup-1.2.0.exe', 'SHA256SUMS.txt'],
  }) => jsonEncode({
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
  });

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
