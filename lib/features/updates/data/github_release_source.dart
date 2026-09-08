import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import '../domain/app_release.dart';
import '../domain/app_version.dart';
import '../domain/release_notes.dart';
import '../domain/release_source.dart';

/// [ReleaseSource] over the GitHub releases of this repository.
///
/// The same place a person would look, asked the same way: one unauthenticated
/// GET of `/releases/latest`, which needs no account, no key and no token, and
/// so sends nothing identifying the owner. Unauthenticated callers get sixty
/// requests an hour from an address, and this makes one per launch.
///
/// `/releases/latest` rather than the list, deliberately: GitHub excludes
/// pre-releases and drafts from it, so a `v1.1.0-beta.1` published for testing
/// is not offered to everybody running the stable build. Nothing here has to
/// filter for that.
///
/// Nothing throws. Every outcome that is not a release is `null` — see
/// [ReleaseSource.latest] for why that is the right answer rather than an
/// error the owner has to dismiss.
class GitHubReleaseSource implements ReleaseSource {
  /// Creates a source over [client], reaching [base].
  ///
  /// Both injectable for the tests, for the reason the lyrics source's are:
  /// the suite stands a scripted client in front of this and no test opens a
  /// socket.
  GitHubReleaseSource({
    http.Client? client,
    Uri? base,
    this.repository = 'artur-rios/orpheus',
    this.timeout = const Duration(seconds: 10),
  }) : _client = client ?? http.Client(),
       _base = base ?? Uri.https('api.github.com');

  static final Logger _log = Logger('updates');

  final http.Client _client;
  final Uri _base;

  /// The `owner/name` whose releases are read.
  final String repository;

  /// How long the check is given before it is abandoned.
  ///
  /// Short, because nothing waits on it: the application is already up and
  /// playable, and this decides whether one dialog appears.
  final Duration timeout;

  @override
  Future<AppRelease?> latest() async {
    try {
      final response = await _client
          .get(
            _base.replace(path: '/repos/$repository/releases/latest'),
            headers: const {
              'Accept': 'application/vnd.github+json',
              'X-GitHub-Api-Version': '2022-11-28',
            },
          )
          .timeout(timeout);

      if (response.statusCode != 200) {
        _log.fine('the release check answered ${response.statusCode}');

        return null;
      }

      return _releaseFrom(
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
      );
    } on Object catch (error) {
      _log.fine('the release check did not complete', error);

      return null;
    }
  }

  /// The release [body] describes, or `null` where it describes nothing usable.
  AppRelease? _releaseFrom(Map<String, dynamic> body) {
    if (body['draft'] == true || body['prerelease'] == true) return null;

    final version = AppVersion.tryParse('${body['tag_name']}');
    if (version == null) {
      _log.fine('the latest release names no version this understands');

      return null;
    }

    final assets = body['assets'];
    final downloads = <ReleaseDownload>[];
    if (assets is List) {
      for (final asset in assets) {
        if (asset is! Map) continue;

        final name = asset['name'];
        final uri = Uri.tryParse('${asset['browser_download_url']}');
        if (name is String && uri != null && uri.host.isNotEmpty) {
          downloads.add(ReleaseDownload(name: name, uri: uri));
        }
      }
    }

    final notes = body['body'];

    return AppRelease(
      version: version,
      downloads: downloads,
      // Tidied here rather than in the dialog: what this holds is what gets
      // shown, and a widget is not the place to be parsing Markdown.
      notes: ReleaseNotes.readable(notes is String ? notes : null),
    );
  }

  @override
  void close() => _client.close();
}
