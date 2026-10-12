import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/autofill/domain/autofill_field.dart';
import 'package:orpheus/features/autofill/domain/proposals.dart';
import 'package:orpheus/features/autofill/domain/release.dart';
import 'package:orpheus/features/autofill/domain/tag_writer.dart';
import 'package:orpheus/features/library/domain/audio_file.dart';
import 'package:orpheus/features/library/domain/music_entry.dart';
import 'package:orpheus/features/library/domain/track_metadata.dart';

import '../../../support/entries.dart';

/// Turning a match into the changes the owner is shown.
void main() {
  final airbag = entry(
    id: 'ok1',
    title: 'Airbag',
    artist: 'Radiohed',
    album: 'OK Computer',
    track: 1,
  );

  const release = ReleaseDetail(
    release: ReleaseCandidate(
      id: 'r',
      title: 'OK Computer',
      artistCredit: [ArtistCredit(name: 'Radiohead')],
      trackCount: 2,
      date: '1997-05-21',
    ),
    tracks: [
      ReleaseTrack(
        disc: 1,
        position: 1,
        title: 'Airbag',
        artistCredit: [ArtistCredit(name: 'Radiohead')],
      ),
      ReleaseTrack(
        disc: 1,
        position: 2,
        title: 'Paranoid Android',
        artistCredit: [ArtistCredit(name: 'Radiohead')],
      ),
    ],
    genres: [
      Genre(name: 'alternative rock', votes: 9),
      Genre(name: 'art rock', votes: 4),
    ],
  );

  FileTags tagsOf(
    Map<AutofillField, Object?> values, {
    Set<AutofillField>? writable,
    Uint8List? cover,
  }) => FileTags(
    writable: writable ?? AutofillField.values.toSet(),
    values: values,
    cover: cover,
  );

  List<FileProposal> propose(
    Map<MusicEntry, ReleaseTrack?> assignment,
    Set<AutofillField> fields,
    Map<String, FileTags> tags, {
    Uint8List? cover,
    List<Genre> fallback = const [],
  }) => proposalsFor(
    assignment: assignment,
    release: release,
    fields: fields,
    tags: tags,
    cover: cover,
    fallbackGenres: fallback,
  );

  test(
    'GivenAMisspeltArtist_WhenProposed_ThenOnlyTheArtistChangesAndItIsTicked',
    () {
      final proposals = propose(
        {airbag: release.tracks.first},
        {AutofillField.title, AutofillField.artist},
        {
          airbag.file.path: tagsOf({
            AutofillField.title: 'Airbag',
            AutofillField.artist: 'Radiohed',
          }),
        },
      );

      final changes = proposals.single.changes;
      expect(changes, hasLength(1));
      expect(changes.single.field, AutofillField.artist);
      expect(changes.single.before, 'Radiohed');
      expect(changes.single.after, 'Radiohead');
      expect(changes.single.accepted, isTrue);
    },
  );

  test(
    'GivenValuesEqualButForSurroundingSpace_WhenProposed_ThenThereIsNoChange',
    () {
      // Review focus: whitespace is not a change; case is.
      final proposals = propose(
        {airbag: release.tracks.first},
        {AutofillField.artist},
        {
          airbag.file.path: tagsOf({AutofillField.artist: ' Radiohead '}),
        },
      );
      expect(proposals.single.changes, isEmpty);

      final lower = propose(
        {airbag: release.tracks.first},
        {AutofillField.artist},
        {
          airbag.file.path: tagsOf({AutofillField.artist: 'radiohead'}),
        },
      );
      expect(lower.single.changes.single.after, 'Radiohead');
    },
  );

  group('the genre', () {
    const rock = ReleaseDetail(
      release: ReleaseCandidate(
        id: 'r',
        title: 'T',
        artistCredit: [],
        trackCount: 1,
      ),
      tracks: [
        ReleaseTrack(disc: 1, position: 1, title: 'Airbag', artistCredit: []),
      ],
      genres: [Genre(name: 'rock', votes: 3)],
    );

    List<FieldChange> genreChanges(String? before) => proposalsFor(
      assignment: {airbag: rock.tracks.single},
      release: rock,
      fields: {AutofillField.genre},
      tags: {
        airbag.file.path: tagsOf({AutofillField.genre: before}),
      },
    ).single.changes;

    test('GivenTheSameGenreInAnotherCase_WhenProposed_ThenThereIsNoChange', () {
      // MusicBrainz spells every genre in lower case: "Rock" is already rock.
      expect(genreChanges('Rock'), isEmpty);
      expect(genreChanges(' ROCK '), isEmpty);
    });

    test('GivenADifferentGenre_WhenProposed_ThenItChangesToTheGenreAsMusicBrainzSpellsIt', () {
      final change = genreChanges('Pop').single;

      expect(change.before, 'Pop');
      expect(change.after, 'rock');
    });

    test('GivenEveryGenreTheFileHoldsJoined_WhenOneOfThemIsProposed_ThenItIsAChangeFromAllOfThem', () {
      // A write replaces every GENRE comment, so "Rock; Pop" becoming "rock"
      // loses Pop: a change the owner has to see.
      final change = genreChanges('Rock; Pop').single;

      expect(change.before, 'Rock; Pop');
      expect(change.after, 'rock');
    });
  });

  test('GivenEveryField_WhenProposedForAnEmptyFile_ThenNumbersYearAndGenreComeFromTheRelease', () {
    final proposals = propose(
      {airbag: release.tracks[1]},
      AutofillField.defaults,
      {airbag.file.path: tagsOf({})},
    );

    final after = {for (final c in proposals.single.changes) c.field: c.after};
    expect(after[AutofillField.title], 'Paranoid Android');
    expect(after[AutofillField.albumArtist], 'Radiohead');
    expect(after[AutofillField.album], 'OK Computer');
    expect(after[AutofillField.trackNumber], 2);
    expect(after[AutofillField.trackTotal], 2);
    expect(after[AutofillField.discNumber], 1);
    expect(after[AutofillField.discTotal], 1);
    expect(after[AutofillField.year], 1997);
    expect(after[AutofillField.genre], 'alternative rock');
  });

  test(
    'GivenAReleaseWithNoGenres_WhenProposed_ThenTheReleaseGroupsGenreStandsIn',
    () {
      const bare = ReleaseDetail(
        release: ReleaseCandidate(
          id: 'r',
          title: 'T',
          artistCredit: [],
          trackCount: 1,
        ),
        tracks: [
          ReleaseTrack(disc: 1, position: 1, title: 'Airbag', artistCredit: []),
        ],
      );

      final proposals = proposalsFor(
        assignment: {airbag: bare.tracks.single},
        release: bare,
        fields: {AutofillField.genre},
        tags: {airbag.file.path: tagsOf({})},
        fallbackGenres: const [Genre(name: 'rock', votes: 1)],
      );

      expect(proposals.single.changes.single.after, 'rock');
    },
  );

  test('GivenAFieldTheFormatCannotHold_WhenProposed_ThenItIsNamedAsNotWritableAndNotProposed', () {
    final proposals = propose(
      {airbag: release.tracks.first},
      {AutofillField.albumArtist, AutofillField.artist},
      {
        airbag.file.path: tagsOf(
          {AutofillField.artist: 'Radiohed'},
          writable: AutofillField.values.toSet()
            ..remove(AutofillField.albumArtist),
        ),
      },
    );

    expect(
      [for (final c in proposals.single.changes) c.field],
      [AutofillField.artist],
    );
    expect(proposals.single.notWritable, {AutofillField.albumArtist});
  });

  test(
    'GivenAnUnwritableFormat_WhenProposed_ThenTheFileIsBlockedWithNoChanges',
    () {
      final ogg = MusicEntry(
        file: AudioFile(
          path: '/library/song.ogg',
          sizeInBytes: 1024,
          modifiedAt: DateTime.utc(2026),
        ),
        metadata: const TrackMetadata(title: 'Airbag'),
      );
      final proposals = propose(
        {ogg: release.tracks.first},
        {AutofillField.title},
        {ogg.file.path: FileTags.unwritable},
      );

      expect(proposals.single.blockedBecause, ProposalBlock.unwritableFormat);
      expect(proposals.single.changes, isEmpty);
    },
  );

  test('GivenAWritableKindOfFileWhoseTagsCannotBeChangedSafely_WhenProposed_ThenItIsBlockedForItsTagsNotItsKind', () {
    // A FLAC is a kind of file Orpheus writes; this one's tags could not be
    // read, or are of a shape the editor leaves alone.
    final proposals = propose(
      {airbag: release.tracks.first},
      {AutofillField.title},
      {airbag.file.path: FileTags.unwritable},
    );

    expect(proposals.single.blockedBecause, ProposalBlock.unsafeTags);
    expect(proposals.single.changes, isEmpty);
  });

  test('GivenAFileWithNoMatch_WhenProposed_ThenItIsBlockedAsNoMatch', () {
    final proposals = propose({airbag: null}, {AutofillField.title}, {
      airbag.file.path: tagsOf({}),
    });

    expect(proposals.single.blockedBecause, ProposalBlock.noMatch);
  });

  test(
    'GivenTheSameCoverIsAlreadyEmbedded_WhenProposed_ThenTheCoverIsNoChange',
    () {
      final picture = Uint8List.fromList([1, 2, 3]);

      final same = propose(
        {airbag: release.tracks.first},
        {AutofillField.cover},
        {
          airbag.file.path: tagsOf({}, cover: Uint8List.fromList([1, 2, 3])),
        },
        cover: picture,
      );
      expect(same.single.changes, isEmpty);

      final different = propose(
        {airbag: release.tracks.first},
        {AutofillField.cover},
        {airbag.file.path: tagsOf({})},
        cover: picture,
      );
      expect(different.single.changes.single.after, picture);
    },
  );

  test('GivenAProposal_WhenAChangeIsUnticked_ThenTheAcceptedCountFalls', () {
    final proposal = propose(
      {airbag: release.tracks[1]},
      {AutofillField.title, AutofillField.artist},
      {
        airbag.file.path: tagsOf({
          AutofillField.title: 'Airbag',
          AutofillField.artist: 'Radiohed',
        }),
      },
    ).single;

    final edited = proposal.withChanges([
      proposal.changes.first.withAccepted(false),
      ...proposal.changes.skip(1),
    ]);

    expect(proposal.acceptedCount, 2);
    expect(edited.acceptedCount, 1);
  });

  test('GivenANumberTheFileHoldsSeveralOf_WhenOneOfThemIsProposed_ThenItIsAChangeFromAllOfThem', () {
    // A file whose frames hold track 1 and track 3 is read as the text
    // `1; 3`, which no number equals: writing 1 drops the 3.
    final several = propose(
      {airbag: release.tracks.first},
      {AutofillField.trackNumber},
      {
        airbag.file.path: tagsOf({AutofillField.trackNumber: '1; 3'}),
      },
    );
    expect(several.single.changes.single.before, '1; 3');
    expect(several.single.changes.single.after, 1);

    final one = propose(
      {airbag: release.tracks.first},
      {AutofillField.trackNumber},
      {
        airbag.file.path: tagsOf({AutofillField.trackNumber: 1}),
      },
    );
    expect(one.single.changes, isEmpty);
  });
}
