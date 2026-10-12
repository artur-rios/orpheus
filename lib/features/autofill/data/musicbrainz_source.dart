import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import '../domain/metadata_source.dart';
import '../domain/release.dart';

/// [MetadataSource] over MusicBrainz, and the Cover Art Archive for covers.
///
/// No key and no account. What MusicBrainz asks in return is an honest
/// User-Agent and no more than one request a second, and both are kept here:
/// the one instance the provider binds holds the throttle, so two autofills in
/// a row cannot add up to more than the service allows.
///
/// What is sent is what an owner would type into the site's own search box:
/// a record's title and artist, or a track's title, artist and length. Not a
/// path, not a file, not anything that persists between requests.
class MusicBrainzSource implements MetadataSource {
  /// Creates the source.
  ///
  /// [wait] and [clock] are seams for the throttle's tests; nothing else
  /// passes them.
  MusicBrainzSource({
    http.Client? client,
    String? version,
    this.spacing = const Duration(seconds: 1),
    this.retryAfter = const Duration(seconds: 2),
    this.timeout = const Duration(seconds: 15),
    Future<void> Function(Duration delay)? wait,
    DateTime Function()? clock,
  }) : _client = client ?? http.Client(),
       userAgent = userAgentFor(version),
       _wait = wait ?? Future<void>.delayed,
       _clock = clock ?? DateTime.now;

  static final Logger _log = Logger('autofill');

  static final Uri _base = Uri.https('musicbrainz.org', '/ws/2/');

  final http.Client _client;
  final Future<void> Function(Duration delay) _wait;
  final DateTime Function() _clock;

  /// The least time between two requests.
  final Duration spacing;

  /// How long to wait before the one retry a 503 earns.
  final Duration retryAfter;

  /// How long a request may take.
  final Duration timeout;

  /// What this application calls itself, as MusicBrainz requires.
  final String userAgent;

  /// When the last request went out, or `null` before the first.
  DateTime? _last;

  /// The queue every request waits its turn in, so the spacing holds however
  /// many callers there are.
  Future<void> _turn = Future<void>.value();

  /// The User-Agent for [version].
  static String userAgentFor(String? version) =>
      'Orpheus/${version ?? 'unknown'} ( https://github.com/artur-rios/orpheus )';

  /// [term] with every character Lucene would read as syntax escaped.
  static String escape(String term) =>
      term.replaceAllMapped(RegExp(r'[+\-&|!(){}\[\]^"~*?:\\/]'), (m) => '\\${m[0]}');

  /// Lets go of the connections.
  void close() => _client.close();

  @override
  Future<List<ReleaseCandidate>> searchReleases(ReleaseQuery query) async {
    final body = await _json('release', {
      'query': query.text ?? _releaseLucene(query),
      'limit': '10',
    });

    return [
      for (final release in _list(body['releases']))
        if (release is Map<String, dynamic>) _candidateFrom(release),
    ];
  }

  @override
  Future<ReleaseDetail> release(String id) async {
    final body = await _json('release/$id', {
      'inc': 'recordings+artist-credits+genres+release-groups+media',
    });

    final tracks = <ReleaseTrack>[];
    for (final medium in _list(body['media'])) {
      if (medium is! Map<String, dynamic>) continue;
      final disc = (medium['position'] as num?)?.toInt() ?? 1;
      for (final track in _list(medium['tracks'])) {
        if (track is! Map<String, dynamic>) continue;
        final recording = track['recording'];
        final recordingMap = recording is Map<String, dynamic> ? recording : const <String, dynamic>{};
        final credit = _credits(track['artist-credit']);
        tracks.add(
          ReleaseTrack(
            disc: disc,
            position: (track['position'] as num?)?.toInt() ?? tracks.length + 1,
            title: track['title'] as String? ?? '',
            artistCredit: credit.isNotEmpty ? credit : _credits(recordingMap['artist-credit']),
            length: _length(track['length']),
            recordingId: recordingMap['id'] as String?,
          ),
        );
      }
    }

    final group = body['release-group'];

    return ReleaseDetail(
      release: _candidateFrom(body, trackCount: tracks.length),
      tracks: tracks,
      genres: _genres(body['genres']),
      releaseGroupId: group is Map<String, dynamic> ? group['id'] as String? : null,
    );
  }

  @override
  Future<List<Genre>> releaseGroupGenres(String id) async {
    final body = await _json('release-group/$id', {'inc': 'genres'});

    return _genres(body['genres']);
  }

  @override
  Future<List<RecordingMatch>> searchRecordings(RecordingQuery query) async {
    final body = await _json('recording', {
      'query': query.text ?? _recordingLucene(query),
      'limit': '10',
    });

    return [
      for (final recording in _list(body['recordings']))
        if (recording is Map<String, dynamic>) _recordingFrom(recording),
    ];
  }

  @override
  Future<Uint8List?> frontCover(String releaseId) async {
    final response = await _send(Uri.https('coverartarchive.org', '/release/$releaseId/front-500'));
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw const MetadataSourceException(MetadataSourceFailure.unreachable);
    }

    return response.bodyBytes;
  }

  String _releaseLucene(ReleaseQuery query) => [
    if (query.album case final album? when album.trim().isNotEmpty) 'release:"${escape(album.trim())}"',
    if (query.artist case final artist? when artist.trim().isNotEmpty) 'artist:"${escape(artist.trim())}"',
  ].join(' AND ');

  String _recordingLucene(RecordingQuery query) {
    final duration = query.duration;

    return [
      if (query.title case final title? when title.trim().isNotEmpty) 'recording:"${escape(title.trim())}"',
      if (query.artist case final artist? when artist.trim().isNotEmpty) 'artist:"${escape(artist.trim())}"',
      if (duration != null)
        'dur:[${duration.inMilliseconds - 3000} TO ${duration.inMilliseconds + 3000}]',
    ].join(' AND ');
  }

  Future<Map<String, dynamic>> _json(String path, Map<String, String> parameters) async {
    final uri = _base.resolve(path).replace(queryParameters: {...parameters, 'fmt': 'json'});
    final response = await _send(uri);
    if (response.statusCode != 200) {
      _log.info('musicbrainz answered ${response.statusCode} for $path');
      throw const MetadataSourceException(MetadataSourceFailure.unreachable);
    }

    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) return decoded;
    } on FormatException {
      // Answered below.
    }

    throw const MetadataSourceException(MetadataSourceFailure.malformed);
  }

  /// Sends one request in its turn, with the one retry a 503 earns.
  Future<http.Response> _send(Uri uri) async {
    var response = await _spaced(uri);
    if (response.statusCode == 503) {
      await _wait(retryAfter);
      response = await _spaced(uri);
      if (response.statusCode == 503) {
        throw const MetadataSourceException(MetadataSourceFailure.rateLimited);
      }
    }

    return response;
  }

  Future<http.Response> _spaced(Uri uri) {
    final done = Completer<http.Response>();

    _turn = _turn.then((_) async {
      final last = _last;
      if (last != null) {
        final since = _clock().difference(last);
        if (since < spacing) await _wait(spacing - since);
      }
      _last = _clock();

      try {
        done.complete(
          await _client.get(uri, headers: {'User-Agent': userAgent, 'Accept': 'application/json'}).timeout(timeout),
        );
      } on Object catch (error) {
        _log.info('musicbrainz could not be reached', error);
        done.completeError(const MetadataSourceException(MetadataSourceFailure.unreachable));
      }
    });

    return done.future;
  }

  static List<Object?> _list(Object? value) => value is List ? value : const [];

  static List<ArtistCredit> _credits(Object? value) => [
    for (final credit in _list(value))
      if (credit is Map<String, dynamic>)
        ArtistCredit(
          name: credit['name'] as String? ?? '',
          joinPhrase: credit['joinphrase'] as String? ?? '',
        ),
  ];

  static Duration? _length(Object? value) =>
      value is num ? Duration(milliseconds: value.toInt()) : null;

  static List<Genre> _genres(Object? value) => [
    for (final genre in _list(value))
      if (genre is Map<String, dynamic>)
        Genre(name: genre['name'] as String? ?? '', votes: (genre['count'] as num?)?.toInt() ?? 0),
  ]..sort((a, b) => b.votes.compareTo(a.votes));

  static ReleaseCandidate _candidateFrom(Map<String, dynamic> release, {int? trackCount}) {
    final group = release['release-group'];
    final groupMap = group is Map<String, dynamic> ? group : const <String, dynamic>{};
    final media = _list(release['media']);
    final firstMedium = media.firstOrNull;
    final disambiguation = release['disambiguation'] as String?;

    return ReleaseCandidate(
      id: release['id'] as String? ?? '',
      title: release['title'] as String? ?? '',
      artistCredit: _credits(release['artist-credit']),
      trackCount: (release['track-count'] as num?)?.toInt() ?? trackCount ?? 0,
      date: release['date'] as String?,
      country: release['country'] as String?,
      status: release['status'] as String?,
      primaryType: groupMap['primary-type'] as String?,
      secondaryTypes: [for (final t in _list(groupMap['secondary-types'])) if (t is String) t],
      format: firstMedium is Map<String, dynamic> ? firstMedium['format'] as String? : null,
      disambiguation: disambiguation == null || disambiguation.isEmpty ? null : disambiguation,
      score: (release['score'] as num?)?.toInt() ?? 0,
    );
  }

  static RecordingMatch _recordingFrom(Map<String, dynamic> recording) {
    final appearances = <RecordingAppearance>[];
    for (final release in _list(recording['releases'])) {
      if (release is! Map<String, dynamic>) continue;
      final medium = _list(release['media']).firstOrNull;
      if (medium is! Map<String, dynamic>) continue;
      appearances.add(
        RecordingAppearance(
          release: _candidateFrom(release),
          disc: (medium['position'] as num?)?.toInt() ?? 1,
          // `track-offset` counts from zero.
          position: ((medium['track-offset'] as num?)?.toInt() ?? 0) + 1,
        ),
      );
    }

    return RecordingMatch(
      recordingId: recording['id'] as String? ?? '',
      title: recording['title'] as String? ?? '',
      artistCredit: _credits(recording['artist-credit']),
      appearances: appearances,
      length: _length(recording['length']),
      score: (recording['score'] as num?)?.toInt() ?? 0,
    );
  }
}
