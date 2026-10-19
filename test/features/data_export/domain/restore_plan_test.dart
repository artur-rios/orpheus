import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/data_export/domain/backup.dart';
import 'package:orpheus/features/data_export/domain/restore_plan.dart';
import 'package:orpheus/features/library/domain/music_entry.dart';
import 'package:orpheus/features/playlists/domain/playlist.dart';
import 'package:orpheus/features/stats/domain/play_history.dart';

import '../../../support/entries.dart';

/// What a restore changes, part by part, for each of the three choices.
void main() {
  final now = DateTime.utc(2026, 10, 19, 12);

  group('SongMatcher', () {
    test('GivenALibraryPath_WhenMatched_ThenThatPathIsAnswered', () {
      final matcher = SongMatcher([entry(id: 'a', title: 'Alpha')]);

      expect(matcher.match(song('/library/zzz-a.flac')), '/library/zzz-a.flac');
    });

    test(
      'GivenOneFolderOnEachSide_WhenMatched_ThenThePathMovesUnderTheNew',
      () {
        final matcher = SongMatcher(
          [entry(id: 'a', directory: '/home/ann/Music/rock')],
          oldFolder: '/old/Music',
          newFolder: '/home/ann/Music',
        );

        expect(
          matcher.match(song('/old/Music/rock/zzz-a.flac')),
          '/home/ann/Music/rock/zzz-a.flac',
        );
      },
    );

    test('GivenAWindowsBackupOnLinux_WhenMatched_ThenTheSeparatorsFollow', () {
      final matcher = SongMatcher(
        [entry(id: 'a', directory: '/home/ann/Music/rock')],
        oldFolder: r'C:\Music\',
        newFolder: '/home/ann/Music',
      );

      expect(
        matcher.match(song(r'C:\Music\rock\zzz-a.flac')),
        '/home/ann/Music/rock/zzz-a.flac',
      );
    });

    test(
      'GivenAFolderThatOnlySharesThePrefix_WhenMatched_ThenNotRewritten',
      () {
        final matcher = SongMatcher(
          // Where a careless rewrite of /music2/… would land.
          [entry(id: 'a', directory: '/library/2')],
          oldFolder: '/music',
          newFolder: '/library',
        );

        expect(matcher.match(song('/music2/zzz-a.flac')), isNull);
      },
    );

    test('GivenTagsWithSpacesAndCase_WhenMatched_ThenTheSongIsFound', () {
      final matcher = SongMatcher([
        entry(
          id: 'a',
          title: 'Alpha',
          artist: 'Ann',
          album: 'First',
          duration: const Duration(seconds: 185),
        ),
      ]);

      final matched = matcher.match(
        song(
          '/elsewhere/alpha.mp3',
          title: '  alpha ',
          artist: 'ANN',
          album: 'first ',
          durationMs: 185000,
        ),
      );

      expect(matched, '/library/zzz-a.flac');
    });

    test('GivenALengthWithin2Seconds_WhenMatchedByTags_ThenItIsFound', () {
      final matcher = SongMatcher([alpha(id: 'a', seconds: 185)]);

      expect(
        matcher.match(alphaSong(durationMs: 186900)),
        '/library/zzz-a.flac',
      );
    });

    test('GivenALengthBeyond2Seconds_WhenMatchedByTags_ThenNothing', () {
      final matcher = SongMatcher([alpha(id: 'a', seconds: 185)]);

      expect(matcher.match(alphaSong(durationMs: 187100)), isNull);
    });

    test('GivenTwoSongsWithTheTags_WhenMatchedByTags_ThenNothing', () {
      final matcher = SongMatcher([
        alpha(id: 'a', seconds: 185),
        alpha(id: 'b', seconds: 186),
      ]);

      expect(matcher.match(alphaSong(durationMs: 185000)), isNull);
    });

    test('GivenNoSongWithThePathOrTags_WhenMatched_ThenNothing', () {
      final matcher = SongMatcher([alpha(id: 'a', seconds: 185)]);

      final matched = matcher.match(
        song(
          '/elsewhere/beta.mp3',
          title: 'Beta',
          artist: 'Ann',
          album: 'First',
          durationMs: 185000,
        ),
      );

      expect(matched, isNull);
    });

    test('GivenNoTitle_WhenMatchedByTags_ThenNothing', () {
      final matcher = SongMatcher([
        entry(
          id: 'a',
          artist: 'Ann',
          album: 'First',
          duration: const Duration(seconds: 185),
        ),
      ]);

      final matched = matcher.match(
        song(
          '/elsewhere/x.mp3',
          artist: 'Ann',
          album: 'First',
          durationMs: 185000,
        ),
      );

      expect(matched, isNull);
    });

    test('GivenNoLength_WhenMatchedByTags_ThenNothing', () {
      final matcher = SongMatcher([alpha(id: 'a', seconds: 185)]);

      expect(matcher.match(alphaSong(durationMs: null)), isNull);
    });
  });

  group('restorePlaylists', () {
    final library = [alpha(id: 'a', seconds: 185), entry(id: 'b')];
    final matcher = SongMatcher(library);
    final earlier = DateTime.utc(2026, 1, 2);
    final later = DateTime.utc(2026, 3, 4);
    final cover = Uint8List.fromList([1, 2, 3]);
    final otherCover = Uint8List.fromList([9, 9]);

    PlaylistsOutcome restore(
      List<Playlist> current,
      BackupContents backup,
      RestoreChoice choice,
    ) => restorePlaylists(
      current,
      backup,
      matcher,
      choice,
      newId: counter(),
      now: now,
    );

    group('merge', () {
      test('GivenANewName_WhenMerged_ThenItIsAddedWithNewIds', () {
        final backup = backupWith(
          playlists: [
            savedPlaylist(
              'p1',
              'Road trip',
              createdAt: earlier,
              modifiedAt: later,
              entries: [savedEntry('/library/zzz-b.flac')],
            ),
          ],
        );

        final outcome = restore(const [], backup, RestoreChoice.merge);

        expect(outcome.playlists, [
          Playlist(
            id: 'new1',
            name: 'Road trip',
            entries: const [
              PlaylistEntry(id: 'new2', path: '/library/zzz-b.flac'),
            ],
            createdAt: earlier,
            modifiedAt: later,
          ),
        ]);
        expect((outcome.added, outcome.merged, outcome.replaced), (1, 0, 0));
      });

      test('GivenTheSameName_WhenMerged_ThenTheMissingEntriesAreAppended', () {
        final here = playlist('h1', 'Road trip', modifiedAt: earlier, [
          const PlaylistEntry(id: 'e1', path: '/library/zzz-b.flac'),
        ]);
        final backup = backupWith(
          playlists: [
            savedPlaylist(
              'p1',
              'Road trip',
              entries: [
                savedEntry('/old/gone.mp3', title: 'Gone'),
                savedEntry('/library/zzz-b.flac'),
                savedEntry('/library/zzz-a.flac'),
                savedEntry('/old/gone.mp3', title: 'Gone'),
              ],
            ),
          ],
        );

        final outcome = restore([here], backup, RestoreChoice.merge);

        expect(outcome.playlists, [
          Playlist(
            id: 'h1',
            name: 'Road trip',
            entries: const [
              PlaylistEntry(id: 'e1', path: '/library/zzz-b.flac'),
              PlaylistEntry(id: 'new1', path: '/old/gone.mp3', title: 'Gone'),
              PlaylistEntry(id: 'new2', path: '/library/zzz-a.flac'),
            ],
            createdAt: earlier,
            modifiedAt: now,
          ),
        ]);
        expect((outcome.added, outcome.merged, outcome.replaced), (0, 1, 0));
      });

      test('GivenAnEntryMatchedByTags_WhenMerged_ThenTheLibraryPathIsUsed', () {
        final backup = backupWith(
          songs: [alphaSong(id: 's1', durationMs: 185000)],
          playlists: [
            savedPlaylist(
              'p1',
              'Road trip',
              entries: [savedEntry('/elsewhere/alpha.mp3', songId: 's1')],
            ),
          ],
        );

        final outcome = restore(const [], backup, RestoreChoice.merge);

        expect(
          outcome.playlists.single.entries.single.path,
          '/library/zzz-a.flac',
        );
      });

      test('GivenAnUnmatchedEntry_WhenMerged_ThenItKeepsItsPathAndDetails', () {
        final backup = backupWith(
          playlists: [
            savedPlaylist(
              'p1',
              'Road trip',
              entries: [
                savedEntry(
                  '/old/gone.mp3',
                  title: 'Gone',
                  artist: 'Nobody',
                  album: 'Lost',
                  durationMs: 61000,
                ),
              ],
            ),
          ],
        );

        final outcome = restore(const [], backup, RestoreChoice.merge);

        expect(
          outcome.playlists.single.entries.single,
          const PlaylistEntry(
            id: 'new2',
            path: '/old/gone.mp3',
            title: 'Gone',
            artist: 'Nobody',
            album: 'Lost',
            duration: Duration(seconds: 61),
          ),
        );
      });

      test('GivenSeveralWithTheName_WhenMerged_ThenTheLatestChangedGetsIt', () {
        final older = playlist('h1', 'Mix', modifiedAt: earlier, const []);
        final newer = playlist('h2', 'Mix', modifiedAt: later, const []);
        final backup = backupWith(
          playlists: [
            savedPlaylist(
              'p1',
              'Mix',
              entries: [savedEntry('/library/zzz-b.flac')],
            ),
          ],
        );

        final outcome = restore([older, newer], backup, RestoreChoice.merge);

        expect(outcome.playlists[0], older);
        expect(outcome.playlists[1].entries.single.path, '/library/zzz-b.flac');
        expect(outcome.merged, 1);
      });

      test('GivenNothingNew_WhenMerged_ThenThePlaylistIsUnchanged', () {
        final here = playlist('h1', 'Mix', modifiedAt: earlier, [
          const PlaylistEntry(id: 'e1', path: '/library/zzz-b.flac'),
        ]);
        final backup = backupWith(
          playlists: [
            savedPlaylist(
              'p1',
              'Mix',
              entries: [savedEntry('/library/zzz-b.flac')],
            ),
          ],
        );

        final outcome = restore([here], backup, RestoreChoice.merge);

        expect(outcome.playlists, [here]);
      });

      test('GivenNothingNew_WhenMerged_ThenItIsNotCountedAsMerged', () {
        final here = playlist('h1', 'Mix', modifiedAt: earlier, [
          const PlaylistEntry(id: 'e1', path: '/library/zzz-b.flac'),
        ]);
        final backup = backupWith(
          playlists: [
            savedPlaylist(
              'p1',
              'Mix',
              entries: [savedEntry('/library/zzz-b.flac')],
            ),
          ],
        );

        final outcome = restore([here], backup, RestoreChoice.merge);

        expect((outcome.added, outcome.merged, outcome.replaced), (0, 0, 0));
      });

      test('GivenAnAddedPlaylistsCover_WhenMerged_ThenItIsUnderTheNewId', () {
        final backup = backupWith(
          playlists: [savedPlaylist('p1', 'Road trip')],
          covers: {'p1': cover},
        );

        final outcome = restore(const [], backup, RestoreChoice.merge);

        expect(outcome.playlists.single.coverId, 'new1');
        expect(outcome.coversToWrite, {'new1': cover});
      });

      test(
        'GivenAPlaylistWithNoCover_WhenMerged_ThenTheBackupCoverIsGiven',
        () {
          final here = playlist('h1', 'Mix', modifiedAt: earlier, const []);
          final backup = backupWith(
            playlists: [savedPlaylist('p1', 'Mix')],
            covers: {'p1': cover},
          );

          final outcome = restore([here], backup, RestoreChoice.merge);

          expect(outcome.playlists.single.coverId, 'h1');
          expect(outcome.coversToWrite, {'h1': cover});
        },
      );

      test('GivenAPlaylistWithACover_WhenMerged_ThenItsCoverIsKept', () {
        final here = playlist(
          'h1',
          'Mix',
          modifiedAt: earlier,
          coverId: 'h1',
          const [],
        );
        final backup = backupWith(
          playlists: [savedPlaylist('p1', 'Mix')],
          covers: {'p1': cover},
        );

        final outcome = restore([here], backup, RestoreChoice.merge);

        expect(outcome.playlists, [here]);
        expect(outcome.coversToWrite, isEmpty);
      });

      test('GivenAnAddedPlaylistsCoverTooLargeToRead_WhenMerged_ThenItIsAddedWithoutAndNamedAsLost', () {
        final backup = backupWith(
          playlists: [savedPlaylist('p1', 'Road trip')],
          skippedCovers: {'p1'},
        );

        final outcome = restore(const [], backup, RestoreChoice.merge);

        expect(outcome.playlists.single.coverId, isNull);
        expect(outcome.coversToWrite, isEmpty);
        expect(outcome.coversLost, {'new1'});
      });

      test('GivenAMergedPlaylistsCoverTooLargeToRead_WhenMerged_ThenItIsNamedAsLost', () {
        final here = playlist('h1', 'Mix', modifiedAt: earlier, const []);
        final backup = backupWith(
          playlists: [
            savedPlaylist(
              'p1',
              'Mix',
              entries: [savedEntry('/library/zzz-b.flac')],
            ),
          ],
          skippedCovers: {'p1'},
        );

        final outcome = restore([here], backup, RestoreChoice.merge);

        expect(outcome.merged, 1);
        expect(outcome.coversLost, {'h1'});
      });

      test('GivenAnUnchangedPlaylistWithNoCover_WhenTheBackupsIsTooLarge_ThenItIsStillNamedAsLost', () {
        final here = playlist('h1', 'Mix', modifiedAt: earlier, [
          const PlaylistEntry(id: 'e1', path: '/library/zzz-b.flac'),
        ]);
        final backup = backupWith(
          playlists: [
            savedPlaylist(
              'p1',
              'Mix',
              entries: [savedEntry('/library/zzz-b.flac')],
            ),
          ],
          skippedCovers: {'p1'},
        );

        final outcome = restore([here], backup, RestoreChoice.merge);

        expect(outcome.merged, 0);
        expect(outcome.playlists, [here]);
        expect(outcome.coversLost, {'h1'});
      });

      test('GivenTwoBackupPlaylistsOfOneName_WhenTheSecondsCoverIsGiven_ThenTheFirstsLossIsNotReported', () {
        final here = playlist('h1', 'Mix', modifiedAt: earlier, const []);
        final backup = backupWith(
          playlists: [
            savedPlaylist('p1', 'Mix'),
            savedPlaylist('p2', 'Mix'),
          ],
          covers: {'p2': cover},
          skippedCovers: {'p1'},
        );

        final outcome = restore([here], backup, RestoreChoice.merge);

        expect(outcome.playlists.single.coverId, 'h1');
        expect(outcome.coversToWrite, {'h1': cover});
        expect(outcome.coversLost, isEmpty);
      });

      test('GivenAPlaylistThatKeepsItsOwnCover_WhenTheBackupsIsTooLarge_ThenNothingIsLost', () {
        final here = playlist(
          'h1',
          'Mix',
          modifiedAt: earlier,
          coverId: 'h1',
          const [],
        );
        final backup = backupWith(
          playlists: [
            savedPlaylist(
              'p1',
              'Mix',
              entries: [savedEntry('/library/zzz-b.flac')],
            ),
          ],
          skippedCovers: {'p1'},
        );

        final outcome = restore([here], backup, RestoreChoice.merge);

        expect(outcome.coversLost, isEmpty);
      });

      test('GivenACoverNoPlaylistNames_WhenMerged_ThenItIsIgnored', () {
        final backup = backupWith(
          playlists: [savedPlaylist('p1', 'Road trip')],
          covers: {'p9': otherCover, 'new1': otherCover},
        );

        final outcome = restore(const [], backup, RestoreChoice.merge);

        expect(outcome.playlists.single.coverId, isNull);
        expect(outcome.coversToWrite, isEmpty);
      });
    });

    group('skip', () {
      test('GivenANewName_WhenSkipped_ThenItIsAdded', () {
        final backup = backupWith(
          playlists: [savedPlaylist('p1', 'Road trip')],
        );

        final outcome = restore(const [], backup, RestoreChoice.skip);

        expect(outcome.playlists.single.name, 'Road trip');
        expect(outcome.playlists.single.id, 'new1');
        expect(outcome.added, 1);
      });

      test('GivenTheSameName_WhenSkipped_ThenTheExistingIsUntouched', () {
        final here = playlist('h1', 'Mix', modifiedAt: earlier, const []);
        final backup = backupWith(
          playlists: [
            savedPlaylist(
              'p1',
              'Mix',
              entries: [savedEntry('/library/zzz-b.flac')],
            ),
          ],
          covers: {'p1': cover},
        );

        final outcome = restore([here], backup, RestoreChoice.skip);

        expect(outcome.playlists, [here]);
        expect(outcome.coversToWrite, isEmpty);
        expect((outcome.added, outcome.merged, outcome.replaced), (0, 0, 0));
      });
    });

    group('replace', () {
      test('GivenPlaylistsHere_WhenReplaced_ThenOnlyTheBackupsRemain', () {
        final here = [
          playlist('h1', 'Mix', modifiedAt: earlier, const []),
          playlist('p1', 'Other', modifiedAt: earlier, const []),
        ];
        final backup = backupWith(
          playlists: [
            savedPlaylist(
              'p1',
              'Mix',
              createdAt: earlier,
              modifiedAt: later,
              entries: [savedEntry('/library/zzz-b.flac')],
            ),
          ],
          covers: {'p1': cover},
        );

        final outcome = restore(here, backup, RestoreChoice.replace);

        expect(outcome.playlists, [
          Playlist(
            id: 'new1',
            name: 'Mix',
            entries: const [
              PlaylistEntry(id: 'new2', path: '/library/zzz-b.flac'),
            ],
            coverId: 'new1',
            createdAt: earlier,
            modifiedAt: later,
          ),
        ]);
        expect(outcome.coversToWrite, {'new1': cover});
        expect((outcome.added, outcome.merged, outcome.replaced), (1, 0, 2));
      });
    });

    group('unreadable', () {
      test('GivenUnreadablePlaylists_WhenReplaced_ThenTheOnesHereStay', () {
        final here = [playlist('h1', 'Mix', modifiedAt: earlier, const [])];
        final backup = backupWith(
          playlists: [savedPlaylist('p1', 'Road trip')],
          covers: {'p1': cover},
          problems: [
            {'section': 'playlists', 'message': 'unreadable'},
          ],
        );

        for (final choice in RestoreChoice.values) {
          final outcome = restore(here, backup, choice);

          expect(outcome.playlists, here, reason: choice.name);
          expect(outcome.coversToWrite, isEmpty, reason: choice.name);
          expect(
            (outcome.added, outcome.merged, outcome.replaced),
            (0, 0, 0),
            reason: choice.name,
          );
        }
      });
    });
  });

  group('restoreHistory', () {
    final library = [
      alpha(id: 'a', seconds: 185),
      entry(id: 'b'),
      entry(id: 'c'),
    ];
    final matcher = SongMatcher(library);
    final monthAgo = now.subtract(const Duration(days: 30));
    final weekAgo = now.subtract(const Duration(days: 7));
    final yesterday = now.subtract(const Duration(days: 1));
    final longAgo = now.subtract(const Duration(days: 91));
    final longerAgo = now.subtract(const Duration(days: 120));
    final twoWeeksAgo = now.subtract(const Duration(days: 14));

    HistoryOutcome restore(
      PlayHistory current,
      BackupContents backup,
      RestoreChoice choice,
    ) => restoreHistory(current, backup, matcher, choice, now);

    group('merge', () {
      test('GivenPlaysOnBothSides_WhenMerged_ThenTheHigherCountIsKept', () {
        final current = historyOf([
          TrackPlays(
            path: '/library/zzz-b.flac',
            plays: 5,
            lastPlayedAt: weekAgo,
          ),
          TrackPlays(
            path: '/library/zzz-c.flac',
            plays: 2,
            lastPlayedAt: weekAgo,
          ),
        ]);
        final backup = backupWith(
          history: [
            played('/library/zzz-b.flac', plays: 3, lastPlayedAt: weekAgo),
            played('/library/zzz-c.flac', plays: 7, lastPlayedAt: weekAgo),
          ],
        );

        final outcome = restore(current, backup, RestoreChoice.merge);

        expect(outcome.history.tracks['/library/zzz-b.flac']!.plays, 5);
        expect(outcome.history.tracks['/library/zzz-c.flac']!.plays, 7);
      });

      test('GivenTwoLastPlays_WhenMerged_ThenTheLaterIsKept', () {
        final current = historyOf([
          TrackPlays(
            path: '/library/zzz-b.flac',
            plays: 1,
            lastPlayedAt: weekAgo,
          ),
          TrackPlays(
            path: '/library/zzz-c.flac',
            plays: 1,
            lastPlayedAt: yesterday,
          ),
        ]);
        final backup = backupWith(
          history: [
            played('/library/zzz-b.flac', plays: 1, lastPlayedAt: yesterday),
            played('/library/zzz-c.flac', plays: 1, lastPlayedAt: weekAgo),
          ],
        );

        final outcome = restore(current, backup, RestoreChoice.merge);

        expect(
          outcome.history.tracks['/library/zzz-b.flac']!.lastPlayedAt,
          yesterday,
        );
        expect(
          outcome.history.tracks['/library/zzz-c.flac']!.lastPlayedAt,
          yesterday,
        );
      });

      test('GivenDatedPlaysOnBothSides_WhenMerged_ThenTheirUnionIsKept', () {
        final current = historyOf([
          TrackPlays(
            path: '/library/zzz-b.flac',
            plays: 2,
            lastPlayedAt: yesterday,
            recent: [weekAgo, yesterday],
          ),
        ]);
        final backup = backupWith(
          history: [
            played(
              '/library/zzz-b.flac',
              plays: 2,
              lastPlayedAt: weekAgo,
              recent: [monthAgo, weekAgo],
            ),
          ],
        );

        final outcome = restore(current, backup, RestoreChoice.merge);

        expect(outcome.history.tracks['/library/zzz-b.flac']!.recent, [
          monthAgo,
          weekAgo,
          yesterday,
        ]);
      });

      test('GivenDatesOlderThan90Days_WhenMerged_ThenTheyAreTrimmed', () {
        final backup = backupWith(
          history: [
            played(
              '/library/zzz-b.flac',
              plays: 2,
              lastPlayedAt: weekAgo,
              recent: [longAgo, weekAgo],
            ),
          ],
        );

        final outcome = restore(PlayHistory.empty, backup, RestoreChoice.merge);

        expect(outcome.history.tracks['/library/zzz-b.flac']!.recent, [
          weekAgo,
        ]);
      });

      test('GivenSongsOnlyInTheBackup_WhenMerged_ThenTheyAreAdded', () {
        final current = historyOf([
          TrackPlays(
            path: '/library/zzz-b.flac',
            plays: 5,
            lastPlayedAt: weekAgo,
          ),
        ]);
        final backup = backupWith(
          history: [
            played('/library/zzz-c.flac', plays: 3, lastPlayedAt: yesterday),
          ],
        );

        final outcome = restore(current, backup, RestoreChoice.merge);

        expect(outcome.history.tracks.keys, {
          '/library/zzz-b.flac',
          '/library/zzz-c.flac',
        });
        expect(outcome.history.tracks['/library/zzz-c.flac']!.plays, 3);
      });

      test(
        'GivenASongMatchedByTags_WhenMerged_ThenItsPlaysGoToTheLibraryPath',
        () {
          final backup = backupWith(
            songs: [alphaSong(id: 's1', durationMs: 185000)],
            history: [
              played(
                '/elsewhere/alpha.mp3',
                songId: 's1',
                plays: 4,
                lastPlayedAt: weekAgo,
              ),
            ],
          );

          final outcome = restore(
            PlayHistory.empty,
            backup,
            RestoreChoice.merge,
          );

          expect(outcome.history.tracks.keys, {'/library/zzz-a.flac'});
          expect(
            outcome.history.tracks['/library/zzz-a.flac']!.path,
            '/library/zzz-a.flac',
          );
        },
      );

      test('GivenSongsNotInTheLibrary_WhenMerged_ThenTheyAreCounted', () {
        final backup = backupWith(
          history: [
            played('/library/zzz-b.flac', plays: 1, lastPlayedAt: weekAgo),
            played('/old/gone.mp3', plays: 6, lastPlayedAt: weekAgo),
          ],
        );

        final outcome = restore(PlayHistory.empty, backup, RestoreChoice.merge);

        expect(outcome.history.tracks['/old/gone.mp3']!.plays, 6);
        expect((outcome.songs, outcome.notInLibrary), (2, 1));
      });

      test('GivenDisjointDatedPlays_WhenMerged_ThenEveryDateIsAPlay', () {
        final current = historyOf([
          TrackPlays(
            path: '/library/zzz-b.flac',
            plays: 2,
            lastPlayedAt: weekAgo,
            recent: [monthAgo, weekAgo],
          ),
        ]);
        final backup = backupWith(
          history: [
            played(
              '/library/zzz-b.flac',
              plays: 2,
              lastPlayedAt: yesterday,
              recent: [twoWeeksAgo, yesterday],
            ),
          ],
        );

        final outcome = restore(current, backup, RestoreChoice.merge);

        expect(outcome.history.tracks['/library/zzz-b.flac']!.plays, 4);
      });

      test(
        'GivenDatesOlderThan90Days_WhenMerged_ThenTheyDoNotRaiseTheCount',
        () {
          final current = historyOf([
            TrackPlays(
              path: '/library/zzz-b.flac',
              plays: 2,
              lastPlayedAt: weekAgo,
              recent: [longAgo, weekAgo],
            ),
          ]);
          final backup = backupWith(
            history: [
              played(
                '/library/zzz-b.flac',
                plays: 2,
                lastPlayedAt: yesterday,
                recent: [longerAgo, yesterday],
              ),
            ],
          );

          final outcome = restore(current, backup, RestoreChoice.merge);

          final track = outcome.history.tracks['/library/zzz-b.flac']!;
          expect(track.plays, 2);
          expect(track.recent, [weekAgo, yesterday]);
        },
      );

      test('GivenTwoBackupRecordsOfOneSong_WhenRestored_ThenTheyAreOne', () {
        final backup = backupWith(
          songs: [alphaSong(id: 's1', durationMs: 185000)],
          history: [
            played(
              '/library/zzz-a.flac',
              plays: 1,
              lastPlayedAt: weekAgo,
              recent: [weekAgo],
            ),
            played(
              '/elsewhere/alpha.mp3',
              songId: 's1',
              plays: 1,
              lastPlayedAt: yesterday,
              recent: [yesterday],
            ),
          ],
        );

        final outcome = restore(
          PlayHistory.empty,
          backup,
          RestoreChoice.replace,
        );

        final track = outcome.history.tracks['/library/zzz-a.flac']!;
        expect(outcome.history.tracks.keys, {'/library/zzz-a.flac'});
        expect((track.plays, track.lastPlayedAt), (2, yesterday));
        expect(track.recent, [weekAgo, yesterday]);
        expect((outcome.songs, outcome.notInLibrary), (1, 0));
      });
    });

    group('skip', () {
      test(
        'GivenSongsWithHistoryHere_WhenSkipped_ThenOnlyTheOthersAreAdded',
        () {
          final here = TrackPlays(
            path: '/library/zzz-b.flac',
            plays: 1,
            lastPlayedAt: weekAgo,
          );
          final backup = backupWith(
            history: [
              played('/library/zzz-b.flac', plays: 9, lastPlayedAt: yesterday),
              played('/old/gone.mp3', plays: 6, lastPlayedAt: weekAgo),
            ],
          );

          final outcome = restore(
            historyOf([here]),
            backup,
            RestoreChoice.skip,
          );

          expect(outcome.history.tracks['/library/zzz-b.flac'], same(here));
          expect(outcome.history.tracks['/old/gone.mp3']!.plays, 6);
          expect((outcome.songs, outcome.notInLibrary), (1, 1));
        },
      );
    });

    group('replace', () {
      test('GivenHistoryHere_WhenReplaced_ThenOnlyTheBackupsRemains', () {
        final current = historyOf([
          TrackPlays(
            path: '/library/zzz-b.flac',
            plays: 9,
            lastPlayedAt: yesterday,
          ),
          TrackPlays(
            path: '/library/zzz-c.flac',
            plays: 2,
            lastPlayedAt: weekAgo,
          ),
        ]);
        final backup = backupWith(
          history: [
            played(
              '/library/zzz-b.flac',
              plays: 3,
              lastPlayedAt: weekAgo,
              recent: [longAgo, weekAgo],
            ),
          ],
        );

        final outcome = restore(current, backup, RestoreChoice.replace);

        expect(outcome.history.tracks.keys, {'/library/zzz-b.flac'});
        final track = outcome.history.tracks['/library/zzz-b.flac']!;
        expect((track.plays, track.lastPlayedAt), (3, weekAgo));
        expect(track.recent, [weekAgo]);
        expect((outcome.songs, outcome.notInLibrary), (1, 0));
      });
    });

    group('unreadable', () {
      test('GivenAnUnreadableHistory_WhenRestored_ThenTheOneHereStays', () {
        final current = historyOf([
          TrackPlays(
            path: '/library/zzz-b.flac',
            plays: 9,
            lastPlayedAt: yesterday,
          ),
        ]);
        final backup = backupWith(
          history: [
            played('/library/zzz-c.flac', plays: 3, lastPlayedAt: weekAgo),
          ],
          problems: [
            {'section': 'playHistory', 'message': 'unreadable'},
          ],
        );

        for (final choice in RestoreChoice.values) {
          final outcome = restore(current, backup, choice);

          expect(outcome.history, same(current), reason: choice.name);
          expect(
            (outcome.songs, outcome.notInLibrary),
            (0, 0),
            reason: choice.name,
          );
        }
      });
    });
  });

  group('restorePreferences', () {
    const defaults = PreferencesSnapshot(
      themeMode: 'system',
      locale: null,
      opensPlayerOnPlay: true,
      rescansAtStartup: true,
      fetchesLyricsOnline: true,
      checksForUpdatesOnStartup: true,
      showsAutoPlaylists: true,
      volume: 1,
      libraryFolders: [],
    );
    const current = PreferencesSnapshot(
      themeMode: 'system',
      locale: 'en',
      opensPlayerOnPlay: true,
      rescansAtStartup: false,
      fetchesLyricsOnline: true,
      checksForUpdatesOnStartup: true,
      showsAutoPlaylists: true,
      volume: 0.5,
      libraryFolders: ['/library'],
    );
    const backup = PreferencesSnapshot(
      themeMode: 'dark',
      locale: null,
      opensPlayerOnPlay: false,
      rescansAtStartup: true,
      fetchesLyricsOnline: false,
      checksForUpdatesOnStartup: false,
      showsAutoPlaylists: false,
      volume: 0.2,
      libraryFolders: [r'C:\Music'],
    );

    test('GivenMerge_WhenRestored_ThenOnlyDefaultValuesTakeTheBackups', () {
      final restored = restorePreferences(
        current,
        defaults,
        backup,
        RestoreChoice.merge,
      );

      expect(
        restored,
        const PreferencesSnapshot(
          themeMode: 'dark',
          locale: 'en',
          opensPlayerOnPlay: false,
          rescansAtStartup: false,
          fetchesLyricsOnline: false,
          checksForUpdatesOnStartup: false,
          showsAutoPlaylists: false,
          volume: 0.5,
          libraryFolders: ['/library'],
        ),
      );
    });

    test('GivenSkip_WhenRestored_ThenNothingIsApplied', () {
      expect(
        restorePreferences(current, defaults, backup, RestoreChoice.skip),
        isNull,
      );
    });

    test('GivenReplace_WhenRestored_ThenEveryValueIsTheBackups', () {
      final restored = restorePreferences(
        current,
        defaults,
        backup,
        RestoreChoice.replace,
      );

      expect(
        restored,
        const PreferencesSnapshot(
          themeMode: 'dark',
          locale: null,
          opensPlayerOnPlay: false,
          rescansAtStartup: true,
          fetchesLyricsOnline: false,
          checksForUpdatesOnStartup: false,
          showsAutoPlaylists: false,
          volume: 0.2,
          libraryFolders: ['/library'],
        ),
      );
    });

    test('GivenAnyChoice_WhenRestored_ThenTheFoldersStayAsTheyAre', () {
      for (final choice in [RestoreChoice.merge, RestoreChoice.replace]) {
        final restored = restorePreferences(
          current.withNoFolders(),
          defaults,
          backup,
          choice,
        );

        expect(restored!.libraryFolders, isEmpty, reason: choice.name);
      }
    });

    test('GivenNoPreferencesInTheBackup_WhenRestored_ThenNothingIsApplied', () {
      expect(
        restorePreferences(current, defaults, null, RestoreChoice.replace),
        isNull,
      );
    });
  });

  group('unreadableParts', () {
    test('GivenProblems_WhenRead_ThenThePlaylistsAndHistoryAreNamed', () {
      final backup = backupWith(
        problems: [
          {'section': 'songs', 'message': 'rebuilding'},
          {'section': 'playlists', 'message': 'unreadable'},
          {'section': 'playHistory', 'message': 'unreadable'},
        ],
      );

      expect(unreadableParts(backup), {'playlists', 'playHistory'});
    });

    test('GivenNoProblems_WhenRead_ThenNothingIsNamed', () {
      expect(unreadableParts(backupWith()), isEmpty);
    });
  });
}

/// Ids `new1`, `new2`… in the order they are asked for.
String Function() counter() {
  var next = 0;

  return () => 'new${++next}';
}

/// A library song tagged Alpha / Ann / First, [seconds] long.
MusicEntry alpha({required String id, required int seconds}) => entry(
  id: id,
  title: 'Alpha',
  artist: 'Ann',
  album: 'First',
  duration: Duration(seconds: seconds),
);

/// A backup song tagged as [alpha], somewhere the library is not.
Map<String, Object?> alphaSong({String id = 's1', required int? durationMs}) =>
    song(
      '/elsewhere/alpha.mp3',
      id: id,
      title: 'Alpha',
      artist: 'Ann',
      album: 'First',
      durationMs: durationMs,
    );

/// A `songs[]` object of the data document.
Map<String, Object?> song(
  String path, {
  String id = 's1',
  String? title,
  String? artist,
  String? album,
  int? durationMs,
}) => {
  'id': id,
  'path': path,
  'title': title,
  'artist': artist,
  'albumArtist': null,
  'album': album,
  'trackNumber': null,
  'trackTotal': null,
  'discNumber': null,
  'year': null,
  'genres': const <String>[],
  'durationMs': durationMs,
};

/// A `playlists[]` object of the data document.
Map<String, Object?> savedPlaylist(
  String id,
  String name, {
  DateTime? createdAt,
  DateTime? modifiedAt,
  List<Map<String, Object?>> entries = const [],
}) => {
  'id': id,
  'name': name,
  'createdAt': (createdAt ?? DateTime.utc(2025)).toIso8601String(),
  'modifiedAt': (modifiedAt ?? DateTime.utc(2025)).toIso8601String(),
  'hasCustomCover': false,
  'entries': entries,
};

/// A playlist entry of the data document.
Map<String, Object?> savedEntry(
  String path, {
  String? songId,
  String? title,
  String? artist,
  String? album,
  int? durationMs,
}) => {
  'path': path,
  'songId': songId,
  'title': title,
  'artist': artist,
  'album': album,
  'durationMs': durationMs,
};

/// A `playHistory[]` object of the data document.
Map<String, Object?> played(
  String path, {
  String? songId,
  required int plays,
  required DateTime lastPlayedAt,
  List<DateTime> recent = const [],
}) => {
  'path': path,
  'songId': songId,
  'plays': plays,
  'lastPlayedAt': lastPlayedAt.toIso8601String(),
  'recentPlays': [for (final at in recent) at.toIso8601String()],
};

/// A playlist on this device.
Playlist playlist(
  String id,
  String name,
  List<PlaylistEntry> entries, {
  required DateTime modifiedAt,
  String? coverId,
}) => Playlist(
  id: id,
  name: name,
  entries: entries,
  coverId: coverId,
  createdAt: DateTime.utc(2026, 1, 2),
  modifiedAt: modifiedAt,
);

/// A history on this device holding [tracks].
PlayHistory historyOf(List<TrackPlays> tracks) =>
    PlayHistory(tracks: {for (final track in tracks) track.path: track});

/// A backup whose data document holds these sections.
BackupContents backupWith({
  List<Map<String, Object?>> songs = const [],
  List<Map<String, Object?>> playlists = const [],
  List<Map<String, Object?>> history = const [],
  List<Map<String, Object?>> problems = const [],
  Map<String, Uint8List> covers = const {},
  Set<String> skippedCovers = const {},
}) => BackupContents(
  data: {
    'format': 'orpheus-data',
    'formatVersion': 1,
    'songs': songs,
    'playlists': playlists,
    'playHistory': history,
    'problems': problems,
  },
  preferences: null,
  covers: covers,
  skippedCovers: skippedCovers,
  createdAt: DateTime.utc(2026, 10, 19),
  isFullBackup: true,
);

extension on PreferencesSnapshot {
  PreferencesSnapshot withNoFolders() => PreferencesSnapshot(
    themeMode: themeMode,
    locale: locale,
    opensPlayerOnPlay: opensPlayerOnPlay,
    rescansAtStartup: rescansAtStartup,
    fetchesLyricsOnline: fetchesLyricsOnline,
    checksForUpdatesOnStartup: checksForUpdatesOnStartup,
    showsAutoPlaylists: showsAutoPlaylists,
    volume: volume,
    libraryFolders: const [],
  );
}
