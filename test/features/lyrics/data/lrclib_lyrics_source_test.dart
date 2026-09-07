import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:orpheus/features/lyrics/data/lrclib_lyrics_source.dart';
import 'package:orpheus/features/lyrics/domain/remote_lyrics_source.dart';

/// The one call this application makes over a network.
///
/// Against a scripted client rather than the service: what is under test is
/// what this asks for, how it chooses between answers, and that it never
/// throws — none of which needs a socket, and all of which a real service
/// would make untestable by answering differently next week. The sheets in the
/// fixtures are invented lines with times attached.
void main() {
  /// A client answering [handler], and recording every URL it was given.
  ({http.Client client, List<Uri> requested}) clientThat(
    http.Response Function(Uri url) handler,
  ) {
    final requested = <Uri>[];

    return (
      client: MockClient((request) async {
        requested.add(request.url);

        return handler(request.url);
      }),
      requested: requested,
    );
  }

  http.Response json(Object body) => http.Response(
    jsonEncode(body),
    200,
    headers: const {'content-type': 'application/json; charset=utf-8'},
  );

  final notFound = http.Response('', 404);

  const query = LyricsQuery(
    title: 'The Second Track',
    artist: 'A Band',
    album: 'A Record',
    duration: Duration(minutes: 3, seconds: 20),
  );

  const sheet = '[00:12.00]The first line\n[00:20.50]The second line\n';

  Map<String, Object?> entryWith({
    String artist = 'A Band',
    String? synced = sheet,
    String? plain,
    num duration = 200,
    bool instrumental = false,
  }) => {
    'trackName': 'The Second Track',
    'artistName': artist,
    'albumName': 'A Record',
    'duration': duration,
    'instrumental': instrumental,
    'plainLyrics': plain,
    'syncedLyrics': synced,
  };

  test(
    'GivenTheServiceKnowsTheTrack_WhenTheWordsAreLookedUp_ThenTheTimedSheetComesBack',
    () async {
      final scripted = clientThat((_) => json(entryWith()));
      final source = LrclibLyricsSource(client: scripted.client);

      final found = await source.find(query);

      expect(found, isNotNull);
      expect(found!.lyrics.isSynced, isTrue);
      expect(found.lyrics.lines.first.text, 'The first line');
      expect(found.lyrics.lines.first.at, const Duration(seconds: 12));
    },
  );

  test(
    'GivenASheetComesBack_WhenItIsCarried_ThenItIsTheTextAsItArrivedNotAReRendering',
    () async {
      // What gets written beside the track has to be the sheet somebody wrote,
      // headers and all — not this application's parsed lines put back into
      // LRC, which would silently drop everything it chooses not to model.
      const withHeaders = '[ti:The Second Track]\n[ar:A Band]\n$sheet';
      final scripted = clientThat((_) => json(entryWith(synced: withHeaders)));
      final source = LrclibLyricsSource(client: scripted.client);

      final found = await source.find(query);

      expect(found!.text, withHeaders);
    },
  );

  test(
    'GivenATrackWithTagsToGoOn_WhenItIsLookedUp_ThenOnlyItsArtistAndTitleAndRecordLeave',
    () async {
      // The half of this feature that is not about words: what a lookup says
      // about the machine it is running on, which is nothing.
      final scripted = clientThat((_) => json(entryWith()));
      final source = LrclibLyricsSource(client: scripted.client);

      await source.find(query);

      final asked = scripted.requested.single;
      expect(asked.host, 'lrclib.net');
      expect(asked.path, '/api/get');
      expect(asked.queryParameters, {
        'artist_name': 'A Band',
        'track_name': 'The Second Track',
        'album_name': 'A Record',
        'duration': '200',
      });
    },
  );

  test(
    'GivenTheExactLookupMisses_WhenTheWordsAreLookedUp_ThenTheSearchIsTriedNext',
    () async {
      final scripted = clientThat(
        (url) => url.path == '/api/get'
            ? notFound
            : json([entryWith(duration: 200)]),
      );
      final source = LrclibLyricsSource(client: scripted.client);

      final found = await source.find(query);

      expect(found!.lyrics.lines.first.text, 'The first line');
      expect(
        scripted.requested.map((url) => url.path),
        ['/api/get', '/api/search'],
      );
    },
  );

  test(
    'GivenTheSearchIsTried_WhenItIsAsked_ThenTheRecordIsLeftOutOfIt',
    () async {
      // The album tag is the field most likely to be why the exact lookup
      // missed — a deluxe reissue, a compilation — so repeating it here would
      // reproduce the miss.
      final scripted = clientThat(
        (url) => url.path == '/api/get' ? notFound : json(const []),
      );
      final source = LrclibLyricsSource(client: scripted.client);

      await source.find(query);

      expect(scripted.requested.last.queryParameters, {
        'artist_name': 'A Band',
        'track_name': 'The Second Track',
      });
    },
  );

  test(
    'GivenSeveralCandidates_WhenOneIsChosen_ThenTheTimedOneWins',
    () async {
      final scripted = clientThat(
        (url) => url.path == '/api/get'
            ? notFound
            : json([
                entryWith(synced: null, plain: 'An untimed line\n'),
                entryWith(),
              ]),
      );
      final source = LrclibLyricsSource(client: scripted.client);

      final found = await source.find(query);

      expect(found!.lyrics.isSynced, isTrue);
    },
  );

  test(
    'GivenTwoTimedCandidates_WhenOneIsChosen_ThenTheOneAtTheRightLengthWins',
    () async {
      // The studio take and the live one share a title and an artist and share
      // nothing about when a line is sung. The length is what tells them
      // apart.
      const live = '[00:45.00]The first line, live\n';
      final scripted = clientThat(
        (url) => url.path == '/api/get'
            ? notFound
            : json([
                entryWith(synced: live, duration: 400),
                entryWith(duration: 201),
              ]),
      );
      final source = LrclibLyricsSource(client: scripted.client);

      final found = await source.find(query);

      expect(found!.lyrics.lines.first.text, 'The first line');
    },
  );

  test(
    'GivenACandidateByAnotherArtist_WhenOneIsChosen_ThenTheExactArtistWins',
    () async {
      const cover = '[00:12.00]The first line, covered\n';
      final scripted = clientThat(
        (url) => url.path == '/api/get'
            ? notFound
            : json([
                entryWith(artist: 'A Tribute Band', synced: cover),
                entryWith(),
              ]),
      );
      final source = LrclibLyricsSource(client: scripted.client);

      final found = await source.find(query);

      expect(found!.lyrics.lines.first.text, 'The first line');
    },
  );

  test(
    'GivenTheTrackIsInstrumental_WhenItIsLookedUp_ThenNothingComesBack',
    () async {
      final scripted = clientThat(
        (url) => url.path == '/api/get'
            ? json(entryWith(synced: null, instrumental: true))
            : json(const []),
      );
      final source = LrclibLyricsSource(client: scripted.client);

      expect(await source.find(query), isNull);
    },
  );

  test(
    'GivenTheServiceKnowsNothing_WhenTheWordsAreLookedUp_ThenNothingComesBack',
    () async {
      final scripted = clientThat(
        (url) => url.path == '/api/get' ? notFound : json(const []),
      );
      final source = LrclibLyricsSource(client: scripted.client);

      expect(await source.find(query), isNull);
    },
  );

  test(
    'GivenTheNetworkRefuses_WhenTheWordsAreLookedUp_ThenNothingComesBackAndNothingIsThrown',
    () async {
      // An aeroplane, a captive portal, a service that is down. The owner ends
      // up exactly where a track with no words leaves them, and the panel says
      // so — it does not show them a failure they can do nothing about.
      final source = LrclibLyricsSource(
        client: MockClient(
          (_) async => throw http.ClientException('no route to host'),
        ),
      );

      expect(await source.find(query), isNull);
    },
  );

  test(
    'GivenTheServiceAnswersSomethingThatIsNotJson_WhenItIsRead_ThenNothingComesBack',
    () async {
      final source = LrclibLyricsSource(
        client: MockClient((_) async => http.Response('<html>a portal', 200)),
      );

      expect(await source.find(query), isNull);
    },
  );

  test(
    'GivenTheServiceIsFaulty_WhenItAnswersAnError_ThenNothingComesBack',
    () async {
      final source = LrclibLyricsSource(
        client: MockClient((_) async => http.Response('', 500)),
      );

      expect(await source.find(query), isNull);
    },
  );

  test(
    'GivenASheetWithAccentedWords_WhenItIsRead_ThenItIsDecodedAsUtf8',
    () async {
      // `body` follows the charset in the content type and falls back to
      // Latin-1 when there is none, which turns every accented word in a
      // Portuguese or a French sheet into mojibake. The bytes are decoded
      // instead.
      final source = LrclibLyricsSource(
        client: MockClient(
          (_) async => http.Response.bytes(
            utf8.encode(
              jsonEncode(entryWith(synced: '[00:12.00]Uma canção\n')),
            ),
            200,
          ),
        ),
      );

      final found = await source.find(query);

      expect(found!.lyrics.lines.first.text, 'Uma canção');
    },
  );

  test(
    'GivenATrackWithNoRecordOrLengthInItsTags_WhenItIsLookedUp_ThenItIsStillAsked',
    () async {
      // Half-tagged libraries are the norm, and a lookup that insisted on all
      // four fields would answer nothing for a large share of real ones.
      final scripted = clientThat((_) => json(entryWith()));
      final source = LrclibLyricsSource(client: scripted.client);

      await source.find(
        const LyricsQuery(title: 'The Second Track', artist: 'A Band'),
      );

      expect(scripted.requested.single.queryParameters, {
        'artist_name': 'A Band',
        'track_name': 'The Second Track',
      });
    },
  );

  test(
    'GivenTheServiceHangs_WhenTheLookupTimesOut_ThenNothingComesBack',
    () async {
      final source = LrclibLyricsSource(
        client: MockClient(
          (_) async => Future.delayed(
            const Duration(seconds: 1),
            () => http.Response('', 200),
          ),
        ),
        timeout: const Duration(milliseconds: 20),
      );

      expect(await source.find(query), isNull);
    },
  );
}
