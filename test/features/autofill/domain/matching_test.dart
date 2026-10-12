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

  group('assignTracks', () {
    ReleaseTrack track(int disc, int position, String title, {int seconds = 200}) =>
        ReleaseTrack(
          disc: disc,
          position: position,
          title: title,
          artistCredit: const [ArtistCredit(name: 'Radiohead')],
          length: Duration(seconds: seconds),
        );

    ReleaseDetail releaseOf(List<ReleaseTrack> tracks) => ReleaseDetail(
      release: const ReleaseCandidate(
        id: 'r',
        title: 'OK Computer',
        artistCredit: [ArtistCredit(name: 'Radiohead')],
        trackCount: 3,
      ),
      tracks: tracks,
    );

    test('GivenFilesNumberedLikeTheRelease_WhenAssigned_ThenEachGetsItsNumbersTrack', () {
      // No titles: the numbers are the only evidence, and they are enough.
      final files = [entry(id: '1', track: 1), entry(id: '2', track: 2)];
      final release = releaseOf([track(1, 1, 'Airbag'), track(1, 2, 'Paranoid Android')]);

      final assigned = assignTracks(files, release);

      expect(assigned[files[0]]?.title, 'Airbag');
      expect(assigned[files[1]]?.title, 'Paranoid Android');
    });

    test('GivenUnnumberedFiles_WhenAssigned_ThenTheyAreMatchedByTitle', () {
      final files = [entry(id: '1', title: 'paranoid android'), entry(id: '2', title: 'AIRBAG')];
      final release = releaseOf([track(1, 1, 'Airbag'), track(1, 2, 'Paranoid Android')]);

      final assigned = assignTracks(files, release);

      expect(assigned[files[0]]?.position, 2);
      expect(assigned[files[1]]?.position, 1);
    });

    test('GivenTwoFilesTaggedTrackOneWithNoDisc_WhenAssignedToATwoDiscRelease_ThenTheSecondFallsThroughToItsTitle', () {
      // Review focus: the second "track 1" must not take the first's track.
      final files = [
        entry(id: 'a', title: 'Opening', track: 1),
        entry(id: 'b', title: 'Second Opening', track: 1),
      ];
      final release = releaseOf([track(1, 1, 'Opening'), track(2, 1, 'Second Opening')]);

      final assigned = assignTracks(files, release);

      expect(assigned[files[0]]?.disc, 1);
      expect(assigned[files[1]]?.disc, 2);
    });

    test('GivenAFileTheReleaseDoesNotHave_WhenAssigned_ThenItHasNoMatchAndTheOthersAreUnaffected', () {
      // Review focus: extra files are no match; extra release tracks ignored.
      final files = [
        entry(id: '1', title: 'Airbag', track: 1),
        entry(id: 'x', title: 'A Hidden Demo', track: 13),
      ];
      final release = releaseOf([
        track(1, 1, 'Airbag'),
        track(1, 2, 'Paranoid Android'),
        track(1, 3, 'Subterranean Homesick Alien'),
      ]);

      final assigned = assignTracks(files, release);

      expect(assigned[files[0]]?.title, 'Airbag');
      expect(assigned.containsKey(files[1]), isTrue);
      expect(assigned[files[1]], isNull);
    });

    test('GivenAnUntitledUnnumberedFile_WhenItsLengthSinglesOutATrack_ThenItIsAssignedThatTrack', () {
      final files = [entry(id: 'u', duration: const Duration(seconds: 387))];
      final release = releaseOf([track(1, 1, 'Airbag', seconds: 284), track(1, 2, 'Paranoid Android', seconds: 386)]);

      expect(assignTracks(files, release)[files[0]]?.title, 'Paranoid Android');
    });
  });
}
