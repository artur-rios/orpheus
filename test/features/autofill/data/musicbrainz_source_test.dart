import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:orpheus/features/autofill/data/musicbrainz_source.dart';
import 'package:orpheus/features/autofill/domain/metadata_source.dart';

import '../../../support/musicbrainz_fixtures.dart';

/// Asking MusicBrainz, against recorded answers rather than the service.
void main() {
  late List<http.Request> requests;

  MusicBrainzSource sourceAnswering(http.Response Function(http.Request request) answer) {
    requests = [];

    return MusicBrainzSource(
      client: MockClient((request) async {
        requests.add(request);
        return answer(request);
      }),
      version: '1.3.0',
      // No real waiting in a test: the spacing has its own tests.
      wait: (_) async {},
    );
  }

  http.Response json(Object body) => http.Response(
    jsonEncode(body),
    200,
    headers: const {'content-type': 'application/json; charset=utf-8'},
  );

  test('GivenARecordQuery_WhenReleasesAreSearched_ThenTheyAreParsedWithEverythingRankingNeeds', () async {
    final source = sourceAnswering((_) => json(releaseSearch));

    final found = await source.searchReleases(const ReleaseQuery(album: 'OK Computer', artist: 'Radiohead'));

    expect(found, hasLength(2));
    final first = found.first;
    expect(first.id, 'rel-1');
    expect(first.title, 'OK Computer');
    expect(first.artist, 'Radiohead');
    expect(first.trackCount, 12);
    expect(first.status, 'Official');
    expect(first.primaryType, 'Album');
    expect(first.format, 'CD');
    expect(first.country, 'GB');
    expect(first.score, 100);
    expect(found[1].disambiguation, 'remaster');
  });

  test('GivenAnyRequest_WhenItIsSent_ThenItNamesOrpheusAndAsksForJson', () async {
    final source = sourceAnswering((_) => json(releaseSearch));

    await source.searchReleases(const ReleaseQuery(album: 'OK Computer'));

    final request = requests.single;
    expect(request.headers['User-Agent'], 'Orpheus/1.3.0 ( https://github.com/artur-rios/orpheus )');
    expect(request.url.host, 'musicbrainz.org');
    expect(request.url.path, '/ws/2/release');
    expect(request.url.queryParameters['fmt'], 'json');
    expect(request.url.queryParameters['limit'], '10');
  });

  test('GivenNamesWithLuceneSyntaxInThem_WhenSearched_ThenTheyAreEscapedRatherThanInterpreted', () async {
    // Review focus: AC/DC, parentheses, quotes.
    final source = sourceAnswering((_) => json(const {'releases': <Object>[]}));

    await source.searchReleases(const ReleaseQuery(album: 'Back in Black (Remastered)', artist: 'AC/DC'));

    final query = requests.single.url.queryParameters['query']!;
    expect(query, r'release:"Back in Black \(Remastered\)" AND artist:"AC\/DC"');
    expect(MusicBrainzSource.escape('"Heroes"'), r'\"Heroes\"');
  });

  test('GivenTheOwnersOwnWords_WhenSearched_ThenTheyAreSentAsTheyWereTyped', () async {
    final source = sourceAnswering((_) => json(const {'releases': <Object>[]}));

    await source.searchReleases(const ReleaseQuery(text: 'radiohead ok computer'));

    expect(requests.single.url.queryParameters['query'], 'radiohead ok computer');
  });

  test('GivenAReleaseId_WhenItIsLookedUp_ThenItsTracksGenresAndGroupAreParsed', () async {
    final source = sourceAnswering((_) => json(releaseLookup));

    final detail = await source.release('rel-1');

    expect(requests.single.url.path, '/ws/2/release/rel-1');
    expect(requests.single.url.queryParameters['inc'], 'recordings+artist-credits+genres+release-groups+media');
    expect(detail.release.title, 'OK Computer');
    expect(detail.releaseGroupId, 'rg-1');
    expect(detail.tracks, hasLength(2));
    expect(detail.tracks.first.title, 'Airbag');
    expect(detail.tracks.first.disc, 1);
    expect(detail.tracks.first.position, 1);
    expect(detail.tracks.first.length, const Duration(milliseconds: 284000));
    expect(detail.tracks.first.recordingId, 'rec-1');
    // A track with no credit of its own takes its recording's.
    expect(detail.tracks[1].artist, 'Radiohead');
    expect(detail.tracks[1].length, isNull);
    // Most voted first, whatever order the service gave.
    expect([for (final g in detail.genres) g.name], ['alternative rock', 'art rock']);
  });

  test('GivenAReleaseGroup_WhenItsGenresAreAsked_ThenTheyAreParsed', () async {
    final source = sourceAnswering((_) => json(releaseGroupLookup));

    final genres = await source.releaseGroupGenres('rg-1');

    expect(requests.single.url.path, '/ws/2/release-group/rg-1');
    expect(genres.single.name, 'rock');
  });

  test('GivenATrackQueryWithALength_WhenRecordingsAreSearched_ThenTheLengthNarrowsItAndAppearancesAreParsed', () async {
    final source = sourceAnswering((_) => json(recordingSearch));

    final found = await source.searchRecordings(
      const RecordingQuery(title: 'Lucky', artist: 'Radiohead', duration: Duration(seconds: 259)),
    );

    expect(
      requests.single.url.queryParameters['query'],
      'recording:"Lucky" AND artist:"Radiohead" AND dur:[256000 TO 262000]',
    );
    final appearance = found.single.appearances.single;
    expect(appearance.release.id, 'rel-1');
    expect(appearance.release.primaryType, 'Album');
    expect(appearance.disc, 1);
    // track-offset is zero-based.
    expect(appearance.position, 11);
  });

  test('GivenAShortTrack_WhenRecordingsAreSearched_ThenTheLowerBoundStopsAtZero', () async {
    final source = sourceAnswering((_) => json(const {'recordings': <Object>[]}));

    await source.searchRecordings(const RecordingQuery(title: 'x', duration: Duration(seconds: 1)));

    expect(requests.single.url.queryParameters['query'], endsWith('dur:[0 TO 4000]'));
  });

  test('GivenAReleaseWithACover_WhenItIsFetched_ThenItsBytesComeBackFromTheCoverArtArchive', () async {
    final source = sourceAnswering((_) => http.Response.bytes([1, 2, 3], 200));

    final cover = await source.frontCover('rel-1');

    expect(cover, Uint8List.fromList([1, 2, 3]));
    expect(requests.single.url.toString(), 'https://coverartarchive.org/release/rel-1/front-500');
  });

  test('GivenAReleaseWithNoCover_WhenItIsFetched_ThenThereIsNone', () async {
    final source = sourceAnswering((_) => http.Response('', 404));

    expect(await source.frontCover('rel-1'), isNull);
  });

  test('GivenAnAnswerThatIsNotJson_WhenItArrives_ThenItIsReportedAsMalformed', () async {
    final source = sourceAnswering((_) => http.Response('<html>', 200));

    await expectLater(
      source.searchReleases(const ReleaseQuery(album: 'x')),
      throwsA(isA<MetadataSourceException>().having((e) => e.kind, 'kind', MetadataSourceFailure.malformed)),
    );
  });

  group('the service limits', () {
    test('GivenTwoRequestsBackToBack_WhenTheySend_ThenTheSecondWaitsOutTheRestOfTheSecond', () async {
      var now = DateTime.utc(2026);
      final waits = <Duration>[];
      final source = MusicBrainzSource(
        client: MockClient((_) async {
          now = now.add(const Duration(milliseconds: 200));
          return http.Response(jsonEncode(releaseGroupLookup), 200);
        }),
        clock: () => now,
        wait: (delay) async {
          waits.add(delay);
          now = now.add(delay);
        },
      );

      await source.releaseGroupGenres('a');
      await source.releaseGroupGenres('b');

      expect(waits, [const Duration(milliseconds: 800)]);
    });

    test('GivenTwoCallersAtOnce_WhenBothAsk_ThenTheirRequestsStillGoOutASecondApart', () async {
      var now = DateTime.utc(2026);
      final sentAt = <DateTime>[];
      final source = MusicBrainzSource(
        client: MockClient((_) async {
          sentAt.add(now);
          return http.Response(jsonEncode(releaseGroupLookup), 200);
        }),
        clock: () => now,
        wait: (delay) async => now = now.add(delay),
      );

      await Future.wait([source.releaseGroupGenres('a'), source.releaseGroupGenres('b')]);

      expect(sentAt[1].difference(sentAt[0]), greaterThanOrEqualTo(const Duration(seconds: 1)));
    });

    test('GivenTheServiceAsksForFewerRequestsOnce_WhenTheRetryIsAnswered_ThenTheAnswerComesBack', () async {
      var calls = 0;
      final source = MusicBrainzSource(
        client: MockClient((_) async {
          calls++;
          return calls == 1 ? http.Response('', 503) : http.Response(jsonEncode(releaseGroupLookup), 200);
        }),
        wait: (_) async {},
      );

      final genres = await source.releaseGroupGenres('rg-1');

      expect(calls, 2);
      expect(genres.single.name, 'rock');
    });

    test('GivenTheServiceKeepsAskingForFewerRequests_WhenTheRetryFailsToo_ThenItIsReportedAsRateLimited', () async {
      final source = MusicBrainzSource(
        client: MockClient((_) async => http.Response('', 503)),
        wait: (_) async {},
      );

      await expectLater(
        source.releaseGroupGenres('rg-1'),
        throwsA(isA<MetadataSourceException>().having((e) => e.kind, 'kind', MetadataSourceFailure.rateLimited)),
      );
    });

    test('GivenNoNetwork_WhenAskedAnything_ThenItIsReportedAsUnreachable', () async {
      final source = MusicBrainzSource(
        client: MockClient((_) async => throw http.ClientException('no route to host')),
        wait: (_) async {},
      );

      await expectLater(
        source.searchReleases(const ReleaseQuery(album: 'x')),
        throwsA(isA<MetadataSourceException>().having((e) => e.kind, 'kind', MetadataSourceFailure.unreachable)),
      );
    });

    test('GivenAFailedRequest_WhenTheNextOneIsAsked_ThenTheQueueStillMoves', () async {
      var calls = 0;
      final source = MusicBrainzSource(
        client: MockClient((_) async {
          calls++;
          if (calls == 1) throw http.ClientException('dropped');
          return http.Response(jsonEncode(releaseGroupLookup), 200);
        }),
        wait: (_) async {},
      );

      await expectLater(source.releaseGroupGenres('a'), throwsA(isA<MetadataSourceException>()));
      expect((await source.releaseGroupGenres('b')).single.name, 'rock');
    });

    test('GivenTheWaitItselfBreaks_WhenTheNextRequestIsAsked_ThenTheQueueStillMoves', () async {
      // The clock never moves, so every request after the first has to wait.
      final now = DateTime.utc(2026);
      var waits = 0;
      final source = MusicBrainzSource(
        client: MockClient((_) async => http.Response(jsonEncode(releaseGroupLookup), 200)),
        clock: () => now,
        wait: (_) async {
          waits++;
          if (waits == 1) throw StateError('timer gone');
        },
      );

      await source.releaseGroupGenres('a');
      await expectLater(
        source.releaseGroupGenres('b'),
        throwsA(isA<MetadataSourceException>().having((e) => e.kind, 'kind', MetadataSourceFailure.unreachable)),
      );
      expect((await source.releaseGroupGenres('c')).single.name, 'rock');
    }, timeout: const Timeout(Duration(seconds: 5)));

    test('GivenTheClockBreaksOnce_WhenTheNextRequestIsAsked_ThenTheQueueStillMoves', () async {
      var reads = 0;
      final source = MusicBrainzSource(
        client: MockClient((_) async => http.Response(jsonEncode(releaseGroupLookup), 200)),
        clock: () {
          reads++;
          if (reads == 1) throw StateError('clock gone');
          return DateTime.utc(2026).add(Duration(minutes: reads));
        },
        wait: (_) async {},
      );

      await expectLater(
        source.releaseGroupGenres('a'),
        throwsA(isA<MetadataSourceException>().having((e) => e.kind, 'kind', MetadataSourceFailure.unreachable)),
      );
      expect((await source.releaseGroupGenres('b')).single.name, 'rock');
    }, timeout: const Timeout(Duration(seconds: 5)));
  });

  group('answers that are not what was promised', () {
    test('GivenJsonWithFieldsOfTheWrongType_WhenReleasesAreSearched_ThenItIsReportedAsMalformed', () async {
      final source = sourceAnswering(
        (_) => json(const {
          'releases': [
            {'id': 7, 'title': 'x'},
          ],
        }),
      );

      await expectLater(
        source.searchReleases(const ReleaseQuery(album: 'x')),
        throwsA(isA<MetadataSourceException>().having((e) => e.kind, 'kind', MetadataSourceFailure.malformed)),
      );
    });

    test('GivenARecordingWithATitleThatIsANumber_WhenRecordingsAreSearched_ThenItIsReportedAsMalformed', () async {
      final source = sourceAnswering(
        (_) => json(const {
          'recordings': [
            {'id': 'rec-1', 'title': 5},
          ],
        }),
      );

      await expectLater(
        source.searchRecordings(const RecordingQuery(title: 'x')),
        throwsA(isA<MetadataSourceException>().having((e) => e.kind, 'kind', MetadataSourceFailure.malformed)),
      );
    });

    test('GivenAReleaseWithATrackTitleThatIsANumber_WhenItIsLookedUp_ThenItIsReportedAsMalformed', () async {
      final source = sourceAnswering(
        (_) => json(const {
          'id': 'rel-1',
          'title': 'x',
          'media': [
            {
              'position': 1,
              'tracks': [
                {'position': 1, 'title': 5},
              ],
            },
          ],
        }),
      );

      await expectLater(
        source.release('rel-1'),
        throwsA(isA<MetadataSourceException>().having((e) => e.kind, 'kind', MetadataSourceFailure.malformed)),
      );
    });

    test('GivenAGenreWithANameThatIsANumber_WhenTheGroupsGenresAreAsked_ThenItIsReportedAsMalformed', () async {
      final source = sourceAnswering(
        (_) => json(const {
          'genres': [
            {'name': 5, 'count': 1},
          ],
        }),
      );

      await expectLater(
        source.releaseGroupGenres('rg-1'),
        throwsA(isA<MetadataSourceException>().having((e) => e.kind, 'kind', MetadataSourceFailure.malformed)),
      );
    });
  });
}
