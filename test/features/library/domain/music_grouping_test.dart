import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/library/domain/music_entry.dart';
import 'package:orpheus/features/library/domain/music_grouping.dart';

import '../../../support/entries.dart';

/// Grouping a library into artists and albums, and gathering a queue from one.
void main() {
  final okComputer = [
    entry(id: '1', title: 'Airbag', artist: 'Radiohead', album: 'OK', track: 1),
    entry(id: '2', title: 'Karma', artist: 'Radiohead', album: 'OK', track: 2),
  ];
  final kindOfBlue = [
    entry(id: '3', title: 'So What', artist: 'Miles Davis', album: 'Blue', track: 1),
  ];
  final untagged = [entry(id: '4')];

  group('albumArtistsAcross', () {
    test(
      'GivenTwoArtistsWhoNamedARecordTheSameThing_WhenTheLibraryIsDerived_ThenEachKeepsTheirOwn',
      () {
        // The case that made a whole artist disappear: the derivation pooled
        // by album title alone, so the commonest performer across both
        // records was handed to every track of both — and the Artists list,
        // which groups by that answer, then showed one artist where there
        // were two.
        final library = albumArtistsAcross([
          entry(id: 'a1', artist: 'Aretha', album: 'Greatest Hits',
              directory: '/library/aretha'),
          entry(id: 'a2', artist: 'Aretha', album: 'Greatest Hits',
              directory: '/library/aretha'),
          entry(id: 'a3', artist: 'Aretha', album: 'Greatest Hits',
              directory: '/library/aretha'),
          entry(id: 'b1', artist: 'Bowie', album: 'Greatest Hits',
              directory: '/library/bowie'),
          entry(id: 'b2', artist: 'Bowie', album: 'Greatest Hits',
              directory: '/library/bowie'),
        ]);

        expect(
          [for (final group in artistsIn(library)) group.name],
          ['Aretha', 'Bowie'],
        );
        expect(
          [
            for (final group in albumsIn(library))
              (group.name, group.entries.first.albumArtist, group.entries.length),
          ],
          [
            ('Greatest Hits', 'Aretha', 3),
            ('Greatest Hits', 'Bowie', 2),
          ],
        );
      },
    );

    test(
      'GivenOneRecordCarriesAnAlbumArtistTag_WhenAnotherSharesItsTitle_ThenTheTagDoesNotBleedOntoIt',
      () {
        final library = albumArtistsAcross([
          entry(id: 'a1', artist: 'Aretha', albumArtist: 'Aretha',
              album: 'Greatest Hits', directory: '/library/aretha'),
          entry(id: 'b1', artist: 'Bowie', album: 'Greatest Hits',
              directory: '/library/bowie'),
        ]);

        expect(
          [for (final entry in library) entry.albumArtist],
          ['Aretha', 'Bowie'],
        );
      },
    );

    test(
      'GivenARecordSplitAcrossDiscFolders_WhenTheLibraryIsDerived_ThenItIsStillOneRecord',
      () {
        // Two keys, one answer: each folder derives the same artist, and
        // `albumsIn` keys by (album, albumArtist) and joins them again.
        final library = albumArtistsAcross([
          entry(id: '1', artist: 'Host', album: 'LP', track: 1,
              directory: '/library/lp/CD1'),
          entry(id: '2', artist: 'Guest', album: 'LP', track: 2,
              directory: '/library/lp/CD1'),
          entry(id: '3', artist: 'Host', album: 'LP', track: 1,
              directory: '/library/lp/CD2'),
        ]);

        expect(albumsIn(library).single.entries.length, 3);
      },
    );
  });

  group('artistsIn', () {
    test(
      'GivenALibraryOfTwoArtistsAndAnUntaggedFile_WhenTheArtistsAreListed_ThenTheUntaggedGroupIsLast',
      () {
        final groups = artistsIn([...okComputer, ...kindOfBlue, ...untagged]);

        expect(
          [for (final group in groups) group.name],
          ['Miles Davis', 'Radiohead', null],
        );
      },
    );

    test(
      'GivenARecordWhoseTracksNameDifferentGuests_WhenTheArtistsAreListed_ThenItIsOneArtistNotThree',
      () {
        // The case the derivation exists for: a rap record where every other
        // track credits a guest, and no file carries an album-artist tag.
        final library = albumArtistsAcross([
          entry(id: '1', artist: '50 Cent', album: 'GRODT', track: 1),
          entry(id: '2', artist: '50 Cent feat. Nate Dogg', album: 'GRODT', track: 2),
          entry(id: '3', artist: '50 Cent', album: 'GRODT', track: 3),
        ]);

        final groups = artistsIn(library);

        expect(groups.length, 1);
        expect(groups.single.name, '50 Cent');
        expect(groups.single.entries.length, 3);
      },
    );

    test(
      'GivenOneTrackCarriesAnAlbumArtistTag_WhenTheArtistsAreListed_ThenItSettlesTheWholeRecord',
      () {
        // Half-tagged libraries are the norm, and several tag formats have no
        // field for the record's artist at all: one file saying it is enough.
        final library = albumArtistsAcross([
          entry(id: '1', artist: 'Guest', albumArtist: 'The Band', album: 'LP'),
          entry(id: '2', artist: 'Another Guest', album: 'LP'),
        ]);

        expect(artistsIn(library).single.name, 'The Band');
      },
    );

    test(
      'GivenATrackWithNoAlbum_WhenTheArtistsAreListed_ThenItIsFiledUnderItsOwnPerformer',
      () {
        // A loose track belongs to no record, so there is nothing to derive
        // from: its own performer is the only answer available.
        final library = albumArtistsAcross([
          entry(id: '1', artist: 'Someone', title: 'Loose'),
        ]);

        expect(artistsIn(library).single.name, 'Someone');
      },
    );
  });

  group('albumsIn', () {
    test(
      'GivenTwoArtistsWithARecordOfTheSameName_WhenTheAlbumsAreListed_ThenTheyStayTwoRecords',
      () {
        final groups = albumsIn([
          entry(id: '1', artist: 'A', album: 'Greatest Hits'),
          entry(id: '2', artist: 'B', album: 'Greatest Hits'),
        ]);

        expect(groups.length, 2);
        expect(
          [for (final group in groups) group.entries.first.albumArtist],
          ['A', 'B'],
        );
      },
    );

    test(
      'GivenARecordWhoseTracksAreOutOfOrder_WhenItIsListed_ThenItsTracksComeBackInTrackOrder',
      () {
        final group = albumsIn([
          entry(id: '2', title: 'Second', artist: 'A', album: 'LP', track: 2),
          entry(id: '1', title: 'First', artist: 'A', album: 'LP', track: 1),
        ]).single;

        expect([for (final e in group.entries) e.title], ['First', 'Second']);
      },
    );

    test(
      'GivenADoubleRecord_WhenItIsListed_ThenDiscOrdersAheadOfTrackNumber',
      () {
        final group = albumsIn([
          entry(id: 'b', title: 'D2T1', artist: 'A', album: 'LP', disc: 2, track: 1),
          entry(id: 'a', title: 'D1T9', artist: 'A', album: 'LP', disc: 1, track: 9),
        ]).single;

        expect([for (final e in group.entries) e.title], ['D1T9', 'D2T1']);
      },
    );
  });

  group('tracksOfAlbum', () {
    test(
      'GivenTwoRecordsShareATitle_WhenOneIsOpened_ThenOnlyThatArtistsTracksAreShown',
      () {
        final library = [
          entry(id: '1', title: 'Mine', artist: 'A', album: 'Hits'),
          entry(id: '2', title: 'Theirs', artist: 'B', album: 'Hits'),
        ];

        final tracks = tracksOfAlbum('Hits', 'A', library);

        expect([for (final e in tracks) e.title], ['Mine']);
      },
    );
  });

  group('albumOf', () {
    test(
      'GivenACompilationOpenedFromOneGuestsTrack_WhenTheAlbumIsQueued_ThenTheWholeRecordIsQueued',
      () {
        final library = albumArtistsAcross([
          entry(id: '1', artist: 'Host', album: 'LP', track: 1),
          entry(id: '2', artist: 'Guest', album: 'LP', track: 2),
          entry(id: '3', artist: 'Host', album: 'LP', track: 3),
        ]);

        final queue = albumOf(library[1], library);

        expect(queue.length, 3);
      },
    );

    test(
      'GivenTracksWithNoAlbumTag_WhenTheirAlbumIsQueued_ThenTheWholeUntitledGroupPlays',
      () {
        // What `albumsIn` shows as one group is what pressing play on it
        // queues. The Albums list already gathers the files that name no
        // record into a single untitled group, so answering with the seed
        // file alone made a group of many play one of them.
        final library = albumArtistsAcross([entry(id: '1'), entry(id: '2')]);

        expect(albumOf(library.first, library).length, 2);
      },
    );

    test(
      'GivenTwoArtistsWithNoAlbumTag_WhenOneUntitledGroupIsQueued_ThenTheOtherIsNotInIt',
      () {
        // The untitled group is still per artist, which is how `albumsIn`
        // keys it: one owner's loose Bowie tracks are not the same record as
        // their loose Aretha ones.
        final library = albumArtistsAcross([
          entry(id: '1', artist: 'Bowie'),
          entry(id: '2', artist: 'Bowie'),
          entry(id: '3', artist: 'Aretha'),
        ]);

        expect(albumOf(library.first, library).length, 2);
      },
    );
  });

  group('artistOf', () {
    test(
      'GivenAnArtistWithTwoRecords_WhenTheArtistIsQueued_ThenTheRecordsPlayOneAfterTheOther',
      () {
        final library = albumArtistsAcross([
          entry(id: '1', title: 'B1', artist: 'A', album: 'Beta', track: 1),
          entry(id: '2', title: 'A2', artist: 'A', album: 'Alpha', track: 2),
          entry(id: '3', title: 'A1', artist: 'A', album: 'Alpha', track: 1),
        ]);

        final queue = artistOf(library.first, library);

        expect(
          [for (final file in queue) file.path],
          [library[2].file.path, library[1].file.path, library[0].file.path],
        );
      },
    );
  });

  group('songsIn', () {
    test(
      'GivenSomeTracksHaveNoTitle_WhenSongsAreListed_ThenTheUntitledOnesComeLast',
      () {
        final songs = songsIn([
          entry(id: '1'),
          entry(id: '2', title: 'Bravo'),
          entry(id: '3', title: 'alpha'),
        ]);

        expect([for (final e in songs) e.title], ['alpha', 'Bravo', null]);
      },
    );
  });

  group('MusicGroup', () {
    test(
      'GivenEveryTrackKnowsItsLength_WhenTheGroupIsMeasured_ThenTheTotalIsTheirSum',
      () {
        final group = MusicGroup(
          name: 'LP',
          entries: [
            entry(id: '1', duration: const Duration(minutes: 3)),
            entry(id: '2', duration: const Duration(minutes: 4)),
          ],
        );

        expect(group.duration, const Duration(minutes: 7));
      },
    );

    test(
      'GivenOneTrackHasNoLength_WhenTheGroupIsMeasured_ThenThereIsNoTotal',
      () {
        // A total that quietly omitted what it could not measure would be a
        // number the owner has no way to read.
        final group = MusicGroup(
          name: 'LP',
          entries: [
            entry(id: '1', duration: const Duration(minutes: 3)),
            entry(id: '2'),
          ],
        );

        expect(group.duration, isNull);
      },
    );
  });

  group('trimmedOrNull', () {
    test('GivenATagOfSpaces_WhenItIsTrimmed_ThenItNamesNothing', () {
      expect(trimmedOrNull('   '), isNull);
      expect(trimmedOrNull(' Radiohead '), 'Radiohead');
    });
  });
}
