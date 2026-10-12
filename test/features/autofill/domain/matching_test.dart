import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/autofill/domain/matching.dart';
import 'package:orpheus/features/autofill/domain/release.dart';
import 'package:orpheus/features/library/domain/audio_file.dart';
import 'package:orpheus/features/library/domain/music_entry.dart';
import 'package:orpheus/features/library/domain/track_metadata.dart';

import '../../../support/entries.dart';

/// Choosing between what MusicBrainz offers.
void main() {
  group('normalised', () {
    test('GivenNamesThatDifferOnlyInCaseAccentsAndPunctuation_WhenNormalised_ThenTheyAreEqual', () {
      expect(normalised('Sigur Rós'), normalised('sigur ros'));
      expect(normalised('OK Computer!'), normalised('ok   computer'));
      expect(normalised('Don’t Stop'), normalised("Don't stop"));
    });
  });

  group('rankCandidates', () {
    ReleaseCandidate candidate(
      String id, {
      String title = 'OK Computer',
      String artist = 'Radiohead',
      int trackCount = 12,
      String status = 'Official',
      int score = 100,
      String? date = '1997-05-21',
    }) => ReleaseCandidate(
      id: id,
      title: title,
      artistCredit: [ArtistCredit(name: artist)],
      trackCount: trackCount,
      status: status,
      score: score,
      date: date,
    );

    List<String> ranked(List<ReleaseCandidate> candidates, {int files = 12}) => [
      for (final c in rankCandidates(
        candidates,
        fileCount: files,
        album: 'OK Computer',
        artist: 'Radiohead',
      ))
        c.id,
    ];

    test('GivenAReleaseWithBonusTracks_WhenRanked_ThenTheOneWithAsManyTracksAsFilesComesFirst', () {
      expect(
        ranked([candidate('deluxe', trackCount: 24), candidate('original')]),
        ['original', 'deluxe'],
      );
    });

    test('GivenABootlegAndAnOfficialRelease_WhenRanked_ThenTheOfficialOneComesFirst', () {
      expect(
        ranked([candidate('boot', status: 'Bootleg'), candidate('official')]),
        ['official', 'boot'],
      );
    });

    test('GivenATitleThatOnlyContainsTheAlbum_WhenRanked_ThenTheExactTitleComesFirst', () {
      expect(
        ranked([candidate('tribute', title: 'OK Computer Tribute'), candidate('exact')]),
        ['exact', 'tribute'],
      );
    });

    test('GivenOtherwiseEqualCandidates_WhenRanked_ThenTheEarliestComesFirstEveryTime', () {
      final order = ranked([
        candidate('b', date: '2009'),
        candidate('a', date: '1997'),
        candidate('c', date: null),
      ]);

      expect(order, ['a', 'b', 'c']);
    });
  });

  group('rankAppearances', () {
    ReleaseCandidate release(String id, {String type = 'Album', List<String> secondary = const [], String date = '2000'}) =>
        ReleaseCandidate(
          id: id,
          title: id,
          artistCredit: const [ArtistCredit(name: 'A')],
          trackCount: 10,
          status: 'Official',
          primaryType: type,
          secondaryTypes: secondary,
          date: date,
        );

    test('GivenARecordingOnASingleACompilationAndAnAlbum_WhenRanked_ThenTheAlbumComesFirstAndTheCompilationLast', () {
      final match = RecordingMatch(
        recordingId: 'rec',
        title: 'Song',
        artistCredit: const [ArtistCredit(name: 'A')],
        appearances: [
          RecordingAppearance(release: release('best of', secondary: ['Compilation']), disc: 1, position: 3),
          RecordingAppearance(release: release('single', type: 'Single'), disc: 1, position: 1),
          RecordingAppearance(release: release('album'), disc: 1, position: 5),
        ],
      );

      expect(
        [for (final a in rankAppearances([match], title: 'Song', artist: 'A')) a.release.id],
        ['album', 'single', 'best of'],
      );
    });
  });

  group('queries', () {
    test('GivenARecordTaggedMostlyOneWay_WhenItsQueryIsBuilt_ThenTheCommonestValuesAreUsed', () {
      final entries = [
        entry(id: '1', title: 'A', artist: 'Radiohead', album: 'OK Computer'),
        entry(id: '2', title: 'B', artist: 'Radiohead', album: 'OK Computer'),
        entry(id: '3', title: 'C', artist: 'Radiohed', album: 'Ok Computer'),
      ];

      final query = releaseQueryFor(entries);

      expect(query.album, 'OK Computer');
      expect(query.artist, 'Radiohead');
    });

    test('GivenARecordWithNoAlbumTag_WhenItsQueryIsBuilt_ThenTheFolderNameStandsIn', () {
      final entries = [entry(id: '1', title: 'A', directory: '/music/Kid A')];

      expect(releaseQueryFor(entries).album, 'Kid A');
    });

    test('GivenAnUntitledTrack_WhenItsQueryIsBuilt_ThenItsFileNameWithoutTheNumberStandsIn', () {
      final untitled = MusicEntry(
        file: AudioFile(
          path: '/music/OK Computer/03 - Lucky.flac',
          sizeInBytes: 1,
          modifiedAt: DateTime.utc(2026),
        ),
        metadata: TrackMetadata.empty,
      );

      expect(recordingQueryFor(untitled).title, 'Lucky');
    });

    MusicEntry untitledAt(String path) => MusicEntry(
      file: AudioFile(path: path, sizeInBytes: 1, modifiedAt: DateTime.utc(2026)),
      metadata: TrackMetadata.empty,
    );

    test('GivenANumberThenASpacedDashThenTheTitle_WhenItsQueryIsBuilt_ThenTheNumberIsStripped', () {
      expect(recordingQueryFor(untitledAt('/music/03 - Lucky.flac')).title, 'Lucky');
    });

    test('GivenALeadingZeroNumberThenSpaceThenTheTitle_WhenItsQueryIsBuilt_ThenTheNumberIsStripped', () {
      expect(recordingQueryFor(untitledAt('/music/03 Lucky.flac')).title, 'Lucky');
    });

    test('GivenATitleThatStartsWithANumberWithoutASeparator_WhenItsQueryIsBuilt_ThenTheNumberIsKept', () {
      expect(recordingQueryFor(untitledAt('/music/21 Guns.mp3')).title, '21 Guns');
    });

    test('GivenATitleThatIsOnlyANumber_WhenItsQueryIsBuilt_ThenTheNumberIsKept', () {
      expect(recordingQueryFor(untitledAt('/music/1984.flac')).title, '1984');
    });

    test('GivenAFileNameThatIsOnlyANumberWithALeadingZero_WhenItsQueryIsBuilt_ThenTheNumberIsKept', () {
      expect(recordingQueryFor(untitledAt('/music/03.flac')).title, '03');
    });
  });
}
