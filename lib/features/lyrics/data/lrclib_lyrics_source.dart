import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import '../domain/remote_lyrics_source.dart';
import 'lrc_parsing.dart';

/// [RemoteLyricsSource] over LRCLIB.
///
/// LRCLIB rather than one of the alternatives, for reasons that are mostly
/// about what this application is: it needs no account and no key, so there is
/// nothing to sign up for and nothing identifying the owner to send; it is
/// asked over plain query parameters, so what leaves the machine is legible in
/// this file rather than buried in a vendor client; and its whole subject is
/// timed lyrics, which is the half of the feature that a tag rarely carries.
///
/// Two calls, in this order:
///
/// 1. `/api/get`, which is the exact match — artist, title, record and length
///    together. When it answers, it has answered about *this* recording, and
///    the length is what makes that true: the studio take and the live one
///    share a title and an artist and share nothing about when a line is sung.
/// 2. `/api/search`, for the far more common case of tags that do not match a
///    database entry exactly — a record named for its deluxe reissue, a length
///    a second out because the tag rounded. Its results are ranked here rather
///    than taken in the order they arrive; see [_scoreOf].
///
/// Nothing here throws. Every outcome that is not a sheet — a 404, a refused
/// connection, an aeroplane, a body that is not the JSON it claims — is the
/// same `null` the local source answers for a track with no words, because it
/// leaves the owner in exactly the same place: a panel that says there are
/// none.
class LrclibLyricsSource implements RemoteLyricsSource {
  /// Creates a source over [client], reaching [base].
  ///
  /// Both are injectable for the tests, which is the whole reason this holds a
  /// `Client` rather than calling the top-level `http.get`: the suite stands a
  /// scripted client in front of this and no test opens a socket.
  LrclibLyricsSource({
    http.Client? client,
    Uri? base,
    this.timeout = const Duration(seconds: 10),
  }) : _client = client ?? http.Client(),
       _base = base ?? Uri.https('lrclib.net');

  final http.Client _client;
  final Uri _base;

  /// How long a lookup is given before it is abandoned.
  ///
  /// Short, because nothing waits on it that the owner cannot already do: the
  /// music is playing, and this fills a panel. A minute-long hang on a captive
  /// portal would leave a spinner where "no lyrics" belongs.
  final Duration timeout;

  /// What this application calls itself to the service.
  ///
  /// LRCLIB asks clients to identify themselves and say where to complain, and
  /// that is a reasonable thing to ask of something making requests of a free
  /// service. It names the application and its repository and nothing about
  /// the machine or the owner.
  static const String userAgent =
      'Orpheus/1.0.0 (https://github.com/artur-rios/orpheus)';

  static final Logger _log = Logger('lyrics');

  /// How far a candidate's length may sit from the query's and still be taken
  /// for the same recording.
  ///
  /// Two seconds. Tags round, encoders disagree about where a track ends, and
  /// a gapless rip differs from the same track ripped alone — but a different
  /// arrangement is not two seconds away, it is thirty.
  static const Duration lengthTolerance = Duration(seconds: 2);

  @override
  Future<RemoteLyrics?> find(LyricsQuery query) async {
    final exact = await _exactMatch(query);
    if (exact != null) return exact;

    return _bestSearchResult(query);
  }

  /// What `/api/get` says about [query], or `null` where it knows nothing.
  Future<RemoteLyrics?> _exactMatch(LyricsQuery query) async {
    final body = await _json(
      _base.replace(
        path: '/api/get',
        queryParameters: {
          'artist_name': query.artist,
          'track_name': query.title,
          if (query.album != null) 'album_name': query.album!,
          if (query.duration != null)
            'duration': query.duration!.inSeconds.toString(),
        },
      ),
    );

    return body is Map<String, dynamic> ? _sheetOf(body) : null;
  }

  /// The best of what `/api/search` returns for [query], or `null`.
  ///
  /// Searched by title and artist alone. The record is left out on purpose:
  /// the album tag is the field most likely to be the reason `/api/get` missed
  /// in the first place, and repeating it here would reproduce the miss.
  Future<RemoteLyrics?> _bestSearchResult(LyricsQuery query) async {
    final body = await _json(
      _base.replace(
        path: '/api/search',
        queryParameters: {
          'artist_name': query.artist,
          'track_name': query.title,
        },
      ),
    );

    if (body is! List) return null;

    ({RemoteLyrics sheet, int score})? best;

    for (final candidate in body) {
      if (candidate is! Map<String, dynamic>) continue;

      final sheet = _sheetOf(candidate);
      if (sheet == null) continue;

      final score = _scoreOf(candidate, sheet, query);
      if (best == null || score > best.score) {
        best = (sheet: sheet, score: score);
      }
    }

    return best?.sheet;
  }

  /// How well [candidate] answers [query], higher being better.
  ///
  /// Three things, in the order they matter. A timed sheet beats an untimed
  /// one outright, because following the music is the point. A length within
  /// [lengthTolerance] beats one outside it, because that is the evidence that
  /// this is the same recording. And an artist that matches the tag exactly
  /// beats one that merely came back from a search for it, which is what keeps
  /// a tribute band's cover from answering for the original.
  int _scoreOf(
    Map<String, dynamic> candidate,
    RemoteLyrics sheet,
    LyricsQuery query,
  ) {
    var score = 0;

    if (sheet.lyrics.isSynced) score += 4;

    final wanted = query.duration;
    final length = _secondsOf(candidate['duration']);
    if (wanted != null && length != null) {
      final apart = (length - wanted).abs();
      if (apart <= lengthTolerance) score += 2;
    }

    if (_matches(candidate['artistName'], query.artist)) score += 1;

    return score;
  }

  /// The sheet [entry] carries, or `null` where it carries no words this can
  /// use.
  RemoteLyrics? _sheetOf(Map<String, dynamic> entry) {
    // A track the database knows to have no words at all. Answering `null` is
    // the honest result: there is nothing to write beside it and nothing to
    // show, and the panel's empty state already says so.
    if (entry['instrumental'] == true) return null;

    // The timed copy first, and the plain one only where there is no timed
    // one — a sheet with no times still beats an empty panel, and the panel
    // already has a line for saying it does not follow the music.
    for (final field in const ['syncedLyrics', 'plainLyrics']) {
      final text = entry[field];
      if (text is! String || text.trim().isEmpty) continue;

      final lyrics = parseLrc(text);
      if (lyrics != null && !lyrics.isEmpty) {
        return RemoteLyrics(lyrics: lyrics, text: text);
      }
    }

    return null;
  }

  /// The decoded body of [url], or `null` for anything that was not one.
  Future<Object?> _json(Uri url) async {
    try {
      final response = await _client
          .get(url, headers: const {'User-Agent': userAgent})
          .timeout(timeout);

      // 404 is the service's ordinary "not in the database", which is most
      // lookups for most libraries and is not worth a log line. Anything else
      // that is not a 200 is worth one.
      if (response.statusCode == 404) return null;
      if (response.statusCode != 200) {
        _log.fine('the lyrics service answered ${response.statusCode}');

        return null;
      }

      // `bodyBytes` decoded as UTF-8 rather than `body`: `body` follows the
      // charset in the response's content type and falls back to Latin-1 when
      // there is none, which turns every accented word in a Portuguese or a
      // French sheet into mojibake before it is ever parsed.
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on Object catch (error) {
      // Broad, like every other outward read in this application, and for a
      // sharper reason here: what a lookup on a bad network throws is a whole
      // family — a socket failure, a timeout, a handshake, a body that is not
      // the JSON it said it was — and the answer to every one of them is the
      // same track with no words on screen.
      _log.fine('the lyrics lookup did not complete', error);

      return null;
    }
  }

  /// [value] as a length, for a field the service writes as seconds and may
  /// write as either a whole number or a fraction.
  static Duration? _secondsOf(Object? value) => switch (value) {
    final int seconds => Duration(seconds: seconds),
    final double seconds => Duration(milliseconds: (seconds * 1000).round()),
    _ => null,
  };

  /// Whether [value] is [wanted], ignoring case and surrounding space.
  static bool _matches(Object? value, String wanted) =>
      value is String &&
      value.trim().toLowerCase() == wanted.trim().toLowerCase();

  /// Releases the connections this holds.
  void close() => _client.close();
}
