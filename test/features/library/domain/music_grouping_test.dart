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

    test(
      'GivenADoubleRecordWithSomeDiscTagsMissing_WhenItIsListed_ThenTheUntaggedTracksSortAsDiscOne',
      () {
        // The comparator used to weigh discs only when both sides named one,
        // so `T2` compared equal to both discs and landed between them by
        // track number — after disc 2's first track, before its second.
        final group = albumsIn([
          entry(id: 'a', title: 'D2T1', artist: 'A', album: 'LP', disc: 2, track: 1),
          entry(id: 'b', title: 'T2', artist: 'A', album: 'LP', track: 2),
          entry(id: 'c', title: 'D2T2', artist: 'A', album: 'LP', disc: 2, track: 2),
          entry(id: 'd', title: 'D1T1', artist: 'A', album: 'LP', disc: 1, track: 1),
        ]).single;

        expect(
          [for (final e in group.entries) e.title],
          ['D1T1', 'T2', 'D2T1', 'D2T2'],
        );
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

  group('entriesOfArtist', () {
    test(
      'GivenAnArtistWithTwoAlbums_WhenAskedForTheirEntries_ThenBothAlbumsAreReturnedInOrder',
      () {
        final library = [
          entry(id: '1', title: 'Zed', artist: 'A', album: 'Beta', track: 1),
          entry(id: '2', title: 'Other', artist: 'B', album: 'Alpha', track: 1),
          entry(id: '3', title: 'Two', artist: 'A', album: 'Alpha', track: 2),
          entry(id: '4', title: 'One', artist: 'A', album: 'Alpha', track: 1),
        ];

        final entries = entriesOfArtist('A', library);

        expect([for (final e in entries) e.title], ['One', 'Two', 'Zed']);
      },
    );

    test(
      'GivenTheUntaggedArtist_WhenAskedForTheirEntries_ThenOnlyTheUntaggedEntriesAreReturned',
      () {
        // An entry with a performer but no album artist falls back to the
        // performer, so it belongs to that artist and not to the untagged
        // group.
        final library = [
          entry(id: '1', title: 'Named', artist: 'A', album: 'Hits'),
          entry(id: '2', title: 'Bare'),
          entry(id: '3', title: 'Also bare', album: 'Loose'),
        ];

        final entries = entriesOfArtist(null, library);

        expect([for (final e in entries) e.title], ['Also bare', 'Bare']);
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

    test(
      'GivenAlbumsTitledInMixedCaseAndAnUntitledGroup_WhenTheArtistIsQueued_ThenTheQueueFollowsTheScreensOrder',
      () {
        // The queue used to sort case-sensitively with the untitled group
        // first — `beta` after `Gamma`, loose tracks ahead of everything —
        // while the artist's screen lists them as `albumsOfArtist` does.
        final library = [
          entry(id: '1', title: 'G1', albumArtist: 'A', album: 'Gamma', track: 1),
          entry(id: '2', title: 'Loose', albumArtist: 'A'),
          entry(id: '3', title: 'B1', albumArtist: 'A', album: 'beta', track: 1),
          entry(id: '4', title: 'A1', albumArtist: 'A', album: 'Alpha', track: 1),
        ];

        final queue = artistOf(library.first, library);
        final screen = [
          for (final group in albumsOfArtist('A', library))
            for (final e in group.entries) e.file.path,
        ];

        expect([for (final file in queue) file.path], screen);
        expect(screen, [
          library[3].file.path,
          library[2].file.path,
          library[0].file.path,
          library[1].file.path,
        ]);
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

    test(
      'GivenATitleStartingWithAnAccentedLetter_WhenSongsAreListed_ThenItIsAmongThePlainLetter',
      () {
        final songs = songsIn([
          entry(id: '1', title: 'Fado'),
          entry(id: '2', title: 'Évora'),
          entry(id: '3', title: 'Dança'),
        ]);

        expect([for (final e in songs) e.title], ['Dança', 'Évora', 'Fado']);
      },
    );
  });

  group('byName', () {
    test(
      'GivenAnAccentedName_WhenItIsCompared_ThenItSortsWithThePlainLetterNotAfterZ',
      () {
        final names = ['Zappa', 'Ângela Rô Rô', 'Bowie', 'Édith Piaf', 'Elis']
          ..sort(byName);

        expect(names, ['Ângela Rô Rô', 'Bowie', 'Édith Piaf', 'Elis', 'Zappa']);
      },
    );

    test(
      'GivenAnAccentInsideAName_WhenItIsCompared_ThenItIsReadAsThePlainLetter',
      () {
        final names = ['Bjorn', 'Björk', 'Bjoa']..sort(byName);

        expect(names, ['Bjoa', 'Björk', 'Bjorn']);
      },
    );

    test(
      'GivenNamesThatDifferOnlyByAnAccent_WhenTheyAreCompared_ThenThePlainOneComesFirstEitherWay',
      () {
        // Not a tie: a tie leaves the order to the sort, which is not stable,
        // and the two names would swap places between rebuilds.
        expect(byName('Edith', 'Édith'), lessThan(0));
        expect(byName('Édith', 'Edith'), greaterThan(0));
      },
    );

    test(
      'GivenNamesThatDifferOnlyByCase_WhenTheyAreCompared_ThenItIsStillATie',
      () {
        // The callers break this tie themselves, with plain compareTo.
        expect(byName('rock', 'Rock'), 0);
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

  group('genres', () {
    test(
      'GivenGenresInMixedCase_WhenGenresAreListed_ThenTheyAreOneGenreNamedByTheMostCommonSpelling',
      () {
        final library = [
          entry(id: '1', genres: ['rock']),
          entry(id: '2', genres: ['Rock']),
          entry(id: '3', genres: ['Rock']),
        ];

        final groups = genresIn(library);

        expect(groups.map((g) => (g.key, g.name)), [('rock', 'Rock')]);
        expect(groups.single.tracks.length, 3);
      },
    );

    test(
      'GivenATieBetweenSpellings_WhenGenresAreListed_ThenTheAlphabeticallyFirstNamesIt',
      () {
        // byName ignores case, so the tie falls through to plain compareTo,
        // which puts capitals first — in either order the files were read.
        final library = [
          entry(id: '1', genres: ['rock']),
          entry(id: '2', genres: ['Rock']),
        ];

        expect(genreNamesIn(library), {'rock': 'Rock'});
        expect(genreNamesIn(library.reversed.toList()), {'rock': 'Rock'});
        expect(
          genreNamesIn([
            entry(id: '1', genres: ['Rock']),
            entry(id: '2', genres: ['ROCK']),
          ]),
          {'rock': 'ROCK'},
        );
      },
    );

    test(
      'GivenSpellingsWithSurroundingSpaces_WhenGenresAreNamed_ThenTheNameIsTrimmed',
      () {
        expect(
          genreNamesIn([
            entry(id: '1', genres: [' Rock ']),
          ]),
          {'rock': 'Rock'},
        );
      },
    );

    test(
      'GivenATrackHoldingTwoSpellings_WhenGenresAreNamed_ThenItVotesOnceForTheGenre',
      () {
        // Counted per spelling, 'rock' would win three to two; each track
        // votes once, with the spelling it lists first: Rock, rock, Rock.
        final library = [
          entry(id: '1', genres: ['Rock', 'rock']),
          entry(id: '2', genres: ['rock']),
          entry(id: '3', genres: ['Rock', 'rock']),
        ];

        expect(genreNamesIn(library), {'rock': 'Rock'});
      },
    );

    test(
      'GivenGenresAndUntaggedTracks_WhenGenresAreListed_ThenTheyAreAlphabeticalWithNoGenreLast',
      () {
        final library = [
          entry(id: '1', genres: ['Rock']),
          entry(id: '2'),
          entry(id: '3', genres: ['jazz']),
        ];

        final groups = genresIn(library);

        expect(groups.map((g) => g.name), ['jazz', 'Rock', null]);
        expect(groups.last.key, isNull);
        expect(groups.last.tracks.map((e) => e.file.path), [
          '/library/zzz-2.flac',
        ]);
      },
    );

    test(
      'GivenEveryTrackHasAGenre_WhenGenresAreListed_ThenThereIsNoNoGenreGroup',
      () {
        final library = [
          entry(id: '1', genres: ['Rock']),
          entry(id: '2', genres: ['Pop']),
        ];

        expect(genresIn(library).map((g) => g.name), ['Pop', 'Rock']);
      },
    );

    test('GivenAnEmptyLibrary_WhenGenresAreListed_ThenThereAreNone', () {
      expect(genresIn(const []), isEmpty);
    });

    test(
      'GivenATrackTaggedRockAndPop_WhenGenresAreListed_ThenItIsUnderBoth',
      () {
        final both = entry(id: '1', genres: ['Rock', 'Pop']);

        final groups = genresIn([both]);

        expect(groups.map((g) => g.name), ['Pop', 'Rock']);
        expect(groups[0].tracks, [both]);
        expect(groups[1].tracks, [both]);
      },
    );

    test(
      'GivenAMixedLibrary_WhenGenresAreListed_ThenEachGroupHoldsExactlyWhatTracksOfGenreGives',
      () {
        // genresIn buckets the library in one pass rather than asking
        // tracksOfGenre once per genre; this is what keeps the two the same
        // answer — the same groups, each with the same tracks in the same
        // order.
        final library = [
          entry(
            id: '01',
            artist: 'Radiohead',
            album: 'OK Computer',
            track: 2,
            genres: ['Rock', 'Alternative'],
          ),
          entry(
            id: '02',
            artist: 'Radiohead',
            album: 'OK Computer',
            track: 1,
            genres: ['rock'],
          ),
          entry(id: '03', artist: 'Björk', album: 'Post', genres: ['Pop']),
          entry(
            id: '04',
            artist: 'radiohead',
            album: 'Kid A',
            track: 1,
            genres: ['Rock', 'ROCK', 'Electronic'],
          ),
          entry(
            id: '05',
            artist: 'Air',
            title: 'Loose',
            genres: ['electronic'],
          ),
          entry(id: '06', artist: 'Air', album: 'Moon Safari'),
          entry(id: '07', title: 'Untagged'),
          entry(
            id: '08',
            artist: 'Massive Attack',
            album: 'Mezzanine',
            disc: 2,
            track: 1,
            genres: ['Trip-Hop', 'Electronic'],
          ),
          entry(
            id: '09',
            artist: 'Massive Attack',
            album: 'Mezzanine',
            disc: 1,
            track: 3,
            genres: [' Trip-Hop '],
          ),
          entry(id: '10', artist: 'Blank', album: 'Nothing', genres: ['']),
          entry(
            id: '11',
            artist: 'Air',
            album: 'Talkie Walkie',
            genres: ['Pop'],
          ),
        ];
        final grouped = albumArtistsAcross(library);

        final groups = genresIn(grouped);

        expect(groups.map((g) => g.key), [
          'alternative',
          'electronic',
          'pop',
          'rock',
          'trip-hop',
          null,
        ]);
        for (final group in groups) {
          expect(
            group.tracks,
            orderedEquals(tracksOfGenre(group.key, grouped)),
            reason: 'genre ${group.key}',
          );
        }
      },
    );

    test('GivenAKey_WhenATrackIsMatched_ThenItIsComparedByGenreKey', () {
      final track = entry(id: '1', genres: [' Rock ']);

      expect(hasGenre(track, 'rock'), isTrue);
      expect(hasGenre(track, 'pop'), isFalse);
      expect(hasGenre(track, null), isFalse);
      expect(hasGenre(entry(id: '2'), null), isTrue);
    });

    test(
      'GivenTracksWithAndWithoutLengths_WhenAGenreIsMeasured_ThenItFollowsTheGroupRule',
      () {
        final measured = genresIn([
          entry(
            id: '1',
            genres: ['Rock'],
            duration: const Duration(minutes: 3),
          ),
          entry(
            id: '2',
            genres: ['Rock'],
            duration: const Duration(minutes: 4),
          ),
        ]);
        final unmeasured = genresIn([
          entry(
            id: '1',
            genres: ['Rock'],
            duration: const Duration(minutes: 3),
          ),
          entry(id: '2', genres: ['Rock']),
        ]);

        expect(measured.single.duration, const Duration(minutes: 7));
        expect(unmeasured.single.duration, isNull);
      },
    );

    group('a record with one rock track of ten', () {
      final record = [
        for (var i = 1; i <= 10; i++)
          entry(
            id: 'r$i',
            title: 'Track $i',
            albumArtist: 'Band',
            album: 'LP',
            track: i,
            genres: [if (i == 4) 'Rock' else 'Folk'],
          ),
      ];
      final other = entry(
        id: 'o',
        albumArtist: 'Other',
        album: 'Else',
        track: 1,
        genres: ['Folk'],
      );
      final library = [other, ...record];

      test(
        'GivenARecordWithOneRockTrackOfTen_WhenRocksLibraryIsBuilt_ThenTheWholeRecordIsInIt',
        () {
          final built = genreLibrary('rock', library);

          expect(built.length, 10);
          expect(built, record);
        },
      );

      test(
        'GivenARecordWithOneRockTrackOfTen_WhenRocksTracksAreTaken_ThenOnlyThatTrackIsAmongThem',
        () {
          expect(tracksOfGenre('rock', library), [record[3]]);
        },
      );
    });

    test(
      'GivenTracksOfThreeRecords_WhenAGenresTracksAreTaken_ThenTheyComeByArtistThenRecordThenTrack',
      () {
        final zebra = entry(
          id: 'z',
          albumArtist: 'Zebra',
          album: 'A',
          track: 1,
          genres: ['Rock'],
        );
        final bandTwo = entry(
          id: 'b2',
          albumArtist: 'Band',
          album: 'Zed',
          track: 2,
          genres: ['Rock'],
        );
        final bandOne = entry(
          id: 'b1',
          albumArtist: 'Band',
          album: 'Zed',
          track: 1,
          genres: ['Rock'],
        );
        final bandFirst = entry(
          id: 'a',
          albumArtist: 'Band',
          album: 'aaa',
          track: 9,
          genres: ['Rock'],
        );

        expect(tracksOfGenre('rock', [zebra, bandTwo, bandOne, bandFirst]), [
          bandFirst,
          bandOne,
          bandTwo,
          zebra,
        ]);
      },
    );

    test(
      'GivenAnArtistsLooseTracks_WhenPopsLibraryIsBuilt_ThenOnlyTheirPopTracksAreInIt',
      () {
        final pop = entry(id: '2', albumArtist: 'Solo', genres: ['Pop']);
        final library = [
          entry(id: '1', albumArtist: 'Solo', genres: ['Folk']),
          pop,
          entry(id: '3', albumArtist: 'Solo'),
        ];

        expect(genreLibrary('pop', library), [pop]);
      },
    );

    test(
      'GivenARecordHalfUntagged_WhenNoGenresLibraryIsBuilt_ThenTheWholeRecordIsInIt',
      () {
        final record = [
          entry(id: '1', albumArtist: 'Band', album: 'LP', track: 1),
          entry(
            id: '2',
            albumArtist: 'Band',
            album: 'LP',
            track: 2,
            genres: ['Rock'],
          ),
        ];

        expect(genreLibrary(null, record), record);
      },
    );

    test(
      'GivenTwoArtistsWhoNamedARecordTheSameThing_WhenOneIsRock_ThenTheOtherIsNotPulledIn',
      () {
        final rock = entry(
          id: '1',
          albumArtist: 'A',
          album: 'Hits',
          track: 1,
          genres: ['Rock'],
        );
        final folk = entry(
          id: '2',
          albumArtist: 'B',
          album: 'Hits',
          track: 1,
          genres: ['Folk'],
        );

        expect(genreLibrary('rock', [folk, rock]), [rock]);
      },
    );

    test(
      'GivenNoGenre_WhenItsTracksAreTaken_ThenOnlyTracksWithNoGenreComeBack',
      () {
        final bare = entry(id: '1', albumArtist: 'Band', album: 'LP', track: 1);
        final library = [
          bare,
          entry(
            id: '2',
            albumArtist: 'Band',
            album: 'LP',
            track: 2,
            genres: ['Rock'],
          ),
        ];

        expect(tracksOfGenre(null, library), [bare]);
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
