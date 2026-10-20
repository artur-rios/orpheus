import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/autofill/domain/autofill_field.dart';
import 'package:orpheus/features/autofill/domain/batch_plan.dart';
import 'package:orpheus/features/autofill/domain/confidence.dart';
import 'package:orpheus/features/autofill/domain/metadata_source.dart';
import 'package:orpheus/features/autofill/domain/proposals.dart';
import 'package:orpheus/features/autofill/domain/release.dart';
import 'package:orpheus/features/library/domain/audio_file.dart';
import 'package:orpheus/features/library/domain/music_entry.dart';
import 'package:orpheus/features/library/domain/track_metadata.dart';

import '../../../support/entries.dart';

/// Whether a lookup is sure enough to be written without the owner looking.
void main() {
  const radiohead = [ArtistCredit(name: 'Radiohead')];

  ReleaseCandidate candidate({
    String title = 'OK Computer',
    String? status = 'Official',
    String? primaryType = 'Album',
    List<String> secondaryTypes = const [],
    List<ArtistCredit> artistCredit = radiohead,
  }) => ReleaseCandidate(
    id: 'release',
    title: title,
    artistCredit: artistCredit,
    trackCount: 2,
    status: status,
    primaryType: primaryType,
    secondaryTypes: secondaryTypes,
  );

  ReleaseTrack track(int position, String title, {int disc = 1}) =>
      ReleaseTrack(
        disc: disc,
        position: position,
        title: title,
        artistCredit: radiohead,
      );

  MusicEntry song(
    int number, {
    String? title,
    String id = '',
    int? trackNumber,
    int? disc,
    String album = 'OK Computer',
  }) => entry(
    id: '$id$number',
    title: title ?? 'Song $number',
    artist: 'Radiohead',
    albumArtist: 'Radiohead',
    album: album,
    track: trackNumber ?? number,
    disc: disc,
  );

  /// A proposal that changes nothing, which is all rules 1 to 4 look at.
  FileProposal untouched(MusicEntry song, {ProposalBlock? blockedBecause}) =>
      FileProposal(entry: song, blockedBecause: blockedBecause);

  FileProposal changing(MusicEntry song, AutofillField field) => FileProposal(
    entry: song,
    changes: [FieldChange(field: field, before: 'old', after: 'new')],
  );

  /// Two songs, both assigned the track of their own number, on a release that
  /// everything about matches, unless a test says otherwise.
  Confidence judge({
    ReleaseCandidate? release,
    bool hasRelease = true,
    ReleaseQuery query = const ReleaseQuery(
      album: 'OK Computer',
      artist: 'Radiohead',
    ),
    List<MusicEntry>? songs,
    Map<MusicEntry, ReleaseTrack?> Function(List<MusicEntry>)? assign,
    List<FileProposal> Function(List<MusicEntry>)? propose,
    List<MusicEntry> libraryOnly = const [],
  }) {
    final inBatch = songs ?? [song(1), song(2)];
    final detail = hasRelease
        ? ReleaseDetail(
            release: release ?? candidate(),
            tracks: [track(1, 'Song 1'), track(2, 'Song 2')],
          )
        : null;
    final assignment =
        assign?.call(inBatch) ??
        {
          for (var i = 0; i < inBatch.length; i++)
            inBatch[i]: detail?.tracks[i],
        };

    return recordConfidence(
      BatchUnit(
        kind: BatchUnitKind.record,
        songs: inBatch,
        matchAgainst: [...inBatch, ...libraryOnly],
      ),
      query: query,
      release: detail,
      assignment: assignment,
      proposals:
          propose?.call(inBatch) ??
          [for (final item in inBatch) untouched(item)],
    );
  }

  void expectDoubtful(Confidence answer, DoubtReason reason, {int count = 0}) {
    expect(answer, isA<Doubtful>());
    final doubtful = answer as Doubtful;
    expect(doubtful.reason, reason);
    expect(doubtful.count, count);
  }

  group('recordConfidence', () {
    test('GivenEverythingMatches_WhenJudged_ThenConfident', () {
      expect(judge(), isA<Confident>());
    });

    test('GivenNoRelease_WhenJudged_ThenNoMatch', () {
      expectDoubtful(judge(hasRelease: false), DoubtReason.noMatch);
    });

    test('GivenAPromotionRelease_WhenJudged_ThenNotOfficial', () {
      expectDoubtful(
        judge(release: candidate(status: 'Promotion')),
        DoubtReason.notOfficial,
      );
    });

    test('GivenAReleaseOfNoStatus_WhenJudged_ThenNotOfficial', () {
      expectDoubtful(
        judge(release: candidate(status: null)),
        DoubtReason.notOfficial,
      );
    });

    test('GivenOfficialInLowerCase_WhenJudged_ThenConfident', () {
      expect(judge(release: candidate(status: 'official')), isA<Confident>());
    });

    test('GivenARemasteredTitle_WhenJudged_ThenDifferentAlbum', () {
      expectDoubtful(
        judge(release: candidate(title: 'OK Computer (Remastered)')),
        DoubtReason.differentAlbum,
      );
    });

    test('GivenNoAlbumToCompareWith_WhenJudged_ThenDifferentAlbum', () {
      expectDoubtful(
        judge(query: const ReleaseQuery(artist: 'Radiohead')),
        DoubtReason.differentAlbum,
      );
    });

    test(
      'GivenAnAlbumNothingRemainsOfOnceNormalised_WhenJudged_ThenDoubtful',
      () {
        expectDoubtful(
          judge(
            release: candidate(title: '???'),
            query: const ReleaseQuery(album: '!!!', artist: 'Radiohead'),
          ),
          DoubtReason.differentAlbum,
        );
      },
    );

    test('GivenAnotherArtistCredited_WhenJudged_ThenDifferentArtist', () {
      expectDoubtful(
        judge(
          release: candidate(artistCredit: const [ArtistCredit(name: 'Muse')]),
        ),
        DoubtReason.differentArtist,
      );
    });

    test('GivenNoArtistAnywhere_WhenJudged_ThenDifferentArtist', () {
      expectDoubtful(
        judge(query: const ReleaseQuery(album: 'OK Computer')),
        DoubtReason.differentArtist,
      );
    });

    test('GivenOneSongUnassigned_WhenJudged_ThenUnmatchedSongsCount1', () {
      expectDoubtful(
        judge(
          assign: (songs) => {songs[0]: track(1, 'Song 1'), songs[1]: null},
          propose: (songs) => [
            untouched(songs[0]),
            untouched(songs[1], blockedBecause: ProposalBlock.noMatch),
          ],
        ),
        DoubtReason.unmatchedSongs,
        count: 1,
      );
    });

    test(
      'GivenASongMissingFromTheAssignment_WhenJudged_ThenUnmatchedSongs',
      () {
        expectDoubtful(
          judge(assign: (songs) => {songs[0]: track(1, 'Song 1')}),
          DoubtReason.unmatchedSongs,
          count: 1,
        );
      },
    );

    test('GivenAnUntitledSong_WhenJudged_ThenDifferentSongs', () {
      final untitled = entry(
        id: 'untitled',
        artist: 'Radiohead',
        albumArtist: 'Radiohead',
        album: 'OK Computer',
        track: 1,
      );

      expectDoubtful(
        judge(songs: [untitled, song(2)]),
        DoubtReason.differentSongs,
        count: 1,
      );
    });

    test('GivenAnotherTitle_WhenJudged_ThenDifferentSongsCountsThem', () {
      expectDoubtful(
        judge(
          songs: [
            song(1, title: 'Other'),
            song(2, title: 'Another'),
          ],
        ),
        DoubtReason.differentSongs,
        count: 2,
      );
    });

    test('GivenTheTrackNumberDiffers_WhenJudged_ThenDifferentSongs', () {
      expectDoubtful(
        judge(songs: [song(1, trackNumber: 7), song(2)]),
        DoubtReason.differentSongs,
        count: 1,
      );
    });

    test('GivenTheDiscDiffers_WhenJudged_ThenDifferentSongs', () {
      expectDoubtful(
        judge(songs: [song(1, disc: 2), song(2)]),
        DoubtReason.differentSongs,
        count: 1,
      );
    });

    test('GivenNoDiscAndNoNumber_WhenJudged_ThenTheTitleAloneDecides', () {
      final unnumbered = entry(
        id: 'unnumbered',
        title: 'Song 1',
        artist: 'Radiohead',
        albumArtist: 'Radiohead',
        album: 'OK Computer',
      );

      expect(judge(songs: [unnumbered, song(2)]), isA<Confident>());
    });

    test('GivenAMissingDiscAgainstDiscTwo_WhenJudged_ThenDifferentSongs', () {
      final second = song(2);

      expectDoubtful(
        judge(
          songs: [song(1), second],
          assign: (songs) => {
            songs[0]: track(1, 'Song 1'),
            songs[1]: track(2, 'Song 2', disc: 2),
          },
        ),
        DoubtReason.differentSongs,
        count: 1,
      );
    });

    test('GivenCaseAccentsAndPunctuationDiffer_WhenJudged_ThenConfident', () {
      expect(
        judge(
          release: candidate(title: 'ok computer'),
          songs: [
            song(1, title: 'Don’t'),
            song(2),
          ],
          assign: (songs) => {
            songs[0]: track(1, "Don't"),
            songs[1]: track(2, 'Song 2'),
          },
        ),
        isA<Confident>(),
      );
    });

    test('GivenACompilationMatches_WhenJudged_ThenConfident', () {
      expect(
        judge(
          release: candidate(
            primaryType: 'Album',
            secondaryTypes: const ['Compilation'],
          ),
        ),
        isA<Confident>(),
      );
    });

    test('GivenAnUnsafeTagsSong_WhenJudged_ThenTheRestDecide', () {
      expect(
        judge(
          songs: [
            song(1, title: 'Other'),
            song(2),
          ],
          assign: (songs) => {songs[0]: null, songs[1]: track(2, 'Song 2')},
          propose: (songs) => [
            untouched(songs[0], blockedBecause: ProposalBlock.unsafeTags),
            untouched(songs[1]),
          ],
        ),
        isA<Confident>(),
      );
    });

    test('GivenAnUnwritableFormatSong_WhenJudged_ThenTheRestDecide', () {
      expect(
        judge(
          assign: (songs) => {songs[0]: null, songs[1]: track(2, 'Song 2')},
          propose: (songs) => [
            untouched(songs[0], blockedBecause: ProposalBlock.unwritableFormat),
            untouched(songs[1]),
          ],
        ),
        isA<Confident>(),
      );
    });

    test(
      'GivenTheRestOfAnUnsafeTagsRecordIsDoubtful_WhenJudged_ThenDoubtful',
      () {
        expectDoubtful(
          judge(
            songs: [
              song(1),
              song(2, title: 'Other'),
            ],
            assign: (songs) => {songs[0]: null, songs[1]: track(2, 'Song 2')},
            propose: (songs) => [
              untouched(songs[0], blockedBecause: ProposalBlock.unsafeTags),
              untouched(songs[1]),
            ],
          ),
          DoubtReason.differentSongs,
          count: 1,
        );
      },
    );

    test('GivenEverySongBlocked_WhenJudged_ThenDoubtful', () {
      expectDoubtful(
        judge(
          assign: (songs) => {songs[0]: null, songs[1]: null},
          propose: (songs) => [
            for (final item in songs)
              untouched(item, blockedBecause: ProposalBlock.unsafeTags),
          ],
        ),
        DoubtReason.unmatchedSongs,
      );
    });

    test('GivenTheBatchWouldSplitTheAlbum_WhenJudged_ThenWouldSplitAlbum', () {
      expectDoubtful(
        judge(
          libraryOnly: [song(3, id: 'library-only-')],
          propose: (songs) => [
            changing(songs[0], AutofillField.album),
            untouched(songs[1]),
          ],
        ),
        DoubtReason.wouldSplitAlbum,
      );
    });

    test(
      'GivenOnlyTheAlbumArtistChangesInAPartialRecord_WhenJudged_ThenSplit',
      () {
        expectDoubtful(
          judge(
            libraryOnly: [song(3, id: 'library-only-')],
            propose: (songs) => [
              untouched(songs[0]),
              changing(songs[1], AutofillField.albumArtist),
            ],
          ),
          DoubtReason.wouldSplitAlbum,
        );
      },
    );

    test('GivenPartialRecordChangingOnlyYear_WhenJudged_ThenConfident', () {
      expect(
        judge(
          libraryOnly: [song(3, id: 'library-only-')],
          propose: (songs) => [
            changing(songs[0], AutofillField.year),
            changing(songs[1], AutofillField.title),
          ],
        ),
        isA<Confident>(),
      );
    });

    test('GivenAWholeRecordChangingItsAlbum_WhenJudged_ThenConfident', () {
      expect(
        judge(
          propose: (songs) => [
            for (final item in songs) changing(item, AutofillField.album),
          ],
        ),
        isA<Confident>(),
      );
    });

    test('GivenAMixedFormatAlbumWhoseM4aSongIsNotWritten_WhenItsAlbumChanges_ThenWouldSplitAlbum', () {
      final m4a = MusicEntry(
        file: AudioFile(
          path: '/library/zzz-3.m4a',
          sizeInBytes: 1024,
          modifiedAt: DateTime.utc(2026),
        ),
        metadata: const TrackMetadata(
          title: 'Song 3',
          artist: 'Radiohead',
          albumArtist: 'Radiohead',
          album: 'OK Computer',
          track: 3,
        ),
      );

      expectDoubtful(
        judge(
          libraryOnly: [m4a],
          propose: (songs) => [
            for (final item in songs) changing(item, AutofillField.album),
          ],
        ),
        DoubtReason.wouldSplitAlbum,
      );
    });

    test('GivenSeveralReasons_WhenJudged_ThenTheFirstRuleSays', () {
      expectDoubtful(
        judge(
          release: candidate(
            status: 'Bootleg',
            title: 'Other',
            artistCredit: const [ArtistCredit(name: 'Muse')],
          ),
        ),
        DoubtReason.notOfficial,
      );
    });
  });

  group('trackConfidence', () {
    final lucky = entry(
      id: 'lucky',
      title: 'Lucky',
      artist: 'Radiohead',
      duration: const Duration(minutes: 4, seconds: 19),
    );

    RecordingMatch recording({
      String title = 'Lucky',
      List<ArtistCredit> artistCredit = radiohead,
      Duration? length = const Duration(minutes: 4, seconds: 20),
    }) => RecordingMatch(
      recordingId: 'recording',
      title: title,
      artistCredit: artistCredit,
      appearances: const [],
      length: length,
    );

    RecordingAppearance appearance({
      String? status = 'Official',
      String? primaryType = 'Album',
      List<String> secondaryTypes = const [],
    }) => RecordingAppearance(
      release: candidate(
        status: status,
        primaryType: primaryType,
        secondaryTypes: secondaryTypes,
      ),
      disc: 1,
      position: 3,
    );

    test('GivenExactTrackOnOfficialAlbum_WhenJudged_ThenConfident', () {
      expect(
        trackConfidence(lucky, match: recording(), appearance: appearance()),
        isA<Confident>(),
      );
    });

    test('GivenCaseAndPunctuationDiffer_WhenJudged_ThenConfident', () {
      expect(
        trackConfidence(
          entry(
            id: 'dont',
            title: 'DON’T PANIC',
            artist: 'radiohead',
            duration: const Duration(minutes: 3),
          ),
          match: recording(
            title: "Don't Panic",
            length: const Duration(minutes: 3),
          ),
          appearance: appearance(),
        ),
        isA<Confident>(),
      );
    });

    test('GivenLengthOffBy3s_WhenJudged_ThenConfident', () {
      expect(
        trackConfidence(
          lucky,
          match: recording(length: const Duration(minutes: 4, seconds: 22)),
          appearance: appearance(),
        ),
        isA<Confident>(),
      );
    });

    test('GivenLengthOff4s_WhenJudged_ThenUncertainTrack', () {
      expectDoubtful(
        trackConfidence(
          lucky,
          match: recording(length: const Duration(minutes: 4, seconds: 23)),
          appearance: appearance(),
        ),
        DoubtReason.uncertainTrack,
      );
    });

    test('GivenUnknownLength_WhenJudged_ThenUncertainTrack', () {
      expectDoubtful(
        trackConfidence(
          lucky,
          match: recording(length: null),
          appearance: appearance(),
        ),
        DoubtReason.uncertainTrack,
      );
    });

    test('GivenTheSongHasNoLength_WhenJudged_ThenUncertainTrack', () {
      expectDoubtful(
        trackConfidence(
          entry(id: 'no-length', title: 'Lucky', artist: 'Radiohead'),
          match: recording(),
          appearance: appearance(),
        ),
        DoubtReason.uncertainTrack,
      );
    });

    test('GivenOnlyOnASingle_WhenJudged_ThenUncertainTrack', () {
      expectDoubtful(
        trackConfidence(
          lucky,
          match: recording(),
          appearance: appearance(primaryType: 'Single'),
        ),
        DoubtReason.uncertainTrack,
      );
    });

    test('GivenOnACompilation_WhenJudged_ThenUncertainTrack', () {
      expectDoubtful(
        trackConfidence(
          lucky,
          match: recording(),
          appearance: appearance(secondaryTypes: const ['Compilation']),
        ),
        DoubtReason.uncertainTrack,
      );
    });

    test('GivenOnAPromotionRelease_WhenJudged_ThenUncertainTrack', () {
      expectDoubtful(
        trackConfidence(
          lucky,
          match: recording(),
          appearance: appearance(status: 'Promotion'),
        ),
        DoubtReason.uncertainTrack,
      );
    });

    test('GivenAnotherTitle_WhenJudged_ThenUncertainTrack', () {
      expectDoubtful(
        trackConfidence(
          lucky,
          match: recording(title: 'Lucky (Live)'),
          appearance: appearance(),
        ),
        DoubtReason.uncertainTrack,
      );
    });

    test('GivenAnotherArtist_WhenJudged_ThenUncertainTrack', () {
      expectDoubtful(
        trackConfidence(
          lucky,
          match: recording(artistCredit: const [ArtistCredit(name: 'Muse')]),
          appearance: appearance(),
        ),
        DoubtReason.uncertainTrack,
      );
    });

    test('GivenAnUntitledSong_WhenJudged_ThenUncertainTrack', () {
      expectDoubtful(
        trackConfidence(
          entry(
            id: 'untitled',
            artist: 'Radiohead',
            duration: const Duration(minutes: 4, seconds: 20),
          ),
          match: recording(),
          appearance: appearance(),
        ),
        DoubtReason.uncertainTrack,
      );
    });

    test('GivenASongOfNoArtist_WhenJudged_ThenUncertainTrack', () {
      expectDoubtful(
        trackConfidence(
          entry(
            id: 'no-artist',
            title: 'Lucky',
            duration: const Duration(minutes: 4, seconds: 20),
          ),
          match: recording(),
          appearance: appearance(),
        ),
        DoubtReason.uncertainTrack,
      );
    });

    test('GivenNoRecording_WhenJudged_ThenUncertainTrack', () {
      expectDoubtful(
        trackConfidence(lucky, match: null, appearance: appearance()),
        DoubtReason.uncertainTrack,
      );
    });

    test('GivenNoAppearance_WhenJudged_ThenUncertainTrack', () {
      expectDoubtful(
        trackConfidence(lucky, match: recording(), appearance: null),
        DoubtReason.uncertainTrack,
      );
    });
  });
}
