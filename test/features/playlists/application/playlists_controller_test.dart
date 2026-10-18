import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/core/di/providers.dart';
import 'package:orpheus/features/library/domain/music_entry.dart';
import 'package:orpheus/features/playlists/application/playlists_controller.dart';
import 'package:orpheus/features/playlists/domain/playlist.dart';

import '../../../support/entries.dart';
import '../../../support/test_container.dart';

/// Creating, changing and deleting playlists, and what is written each time.
void main() {
  final now = DateTime.utc(2026, 6, 1, 12);
  final earlier = DateTime.utc(2026, 1, 1);

  final songA = entry(id: 'a', title: 'Alpha', artist: 'Ann', album: 'One');
  final songB = entry(id: 'b', title: 'Beta', artist: 'Bob', album: 'One');
  final songC = entry(id: 'c', title: 'Gamma', artist: 'Cy');

  PlaylistEntry snapshotOf(String id, MusicEntry song) => PlaylistEntry(
    id: id,
    path: song.file.path,
    title: song.title,
    artist: song.artist,
    album: song.album,
    duration: song.duration,
  );

  Playlist stored(
    String id, {
    String name = 'Road trip',
    List<PlaylistEntry> entries = const [],
    String? coverId,
  }) => Playlist(
    id: id,
    name: name,
    entries: entries,
    coverId: coverId,
    createdAt: earlier,
    modifiedAt: earlier,
  );

  Harness harnessOver({List<Playlist> playlists = const []}) =>
      Harness(library: [songA, songB, songC], playlists: playlists, now: now);

  Future<PlaylistsController> controllerOf(Harness harness) async {
    await harness.container.read(playlistsControllerProvider.future);
    return harness.container.read(playlistsControllerProvider.notifier);
  }

  List<String> pathsOf(Playlist playlist) => [
    for (final e in playlist.entries) e.path,
  ];

  List<String> entryIdsOf(Harness harness) => [
    for (final e in harness.playlistStore.playlists.single.entries) e.id,
  ];

  group('create', () {
    test('GivenAName_WhenAPlaylistIsCreated_ThenItIsPersisted', () async {
      final harness = harnessOver();
      final controller = await controllerOf(harness);

      final created = await controller.create('  Road trip ');

      expect(created.id, 'id-1');
      expect(created.name, 'Road trip');
      expect(created.entries, isEmpty);
      expect(created.coverId, isNull);
      expect(created.createdAt, now);
      expect(created.modifiedAt, now);
      expect(harness.playlistStore.playlists, [created]);
      expect(harness.read(playlistsControllerProvider).value, [created]);
    });

    test(
      'GivenABlankName_WhenAPlaylistIsCreated_ThenNothingIsWritten',
      () async {
        final harness = harnessOver();
        final controller = await controllerOf(harness);

        await expectLater(controller.create('   '), throwsArgumentError);

        expect(harness.playlistStore.writes, 0);
      },
    );

    test(
      'GivenStoredPlaylists_WhenOneIsCreated_ThenTheOthersAreKept',
      () async {
        final harness = harnessOver(playlists: [stored('old')]);
        final controller = await controllerOf(harness);

        await controller.create('New');

        expect(
          [for (final p in harness.playlistStore.playlists) p.id],
          ['old', 'id-1'],
        );
      },
    );
  });

  group('add', () {
    test('GivenSongs_WhenAdded_ThenTheyAreAppendedInOrderAndCounted', () async {
      final harness = harnessOver(
        playlists: [
          stored('p', entries: [snapshotOf('e0', songC)]),
        ],
      );
      final controller = await controllerOf(harness);

      final count = await controller.add('p', [
        songB,
        songA,
      ], skipDuplicates: false);

      final saved = harness.playlistStore.playlists.single;
      expect(count, 2);
      expect(pathsOf(saved), [
        songC.file.path,
        songB.file.path,
        songA.file.path,
      ]);
      expect(saved.modifiedAt, now);
      expect(saved.createdAt, earlier);
    });

    test('GivenASong_WhenAdded_ThenItsTagsAreSnapshotted', () async {
      final timed = entry(
        id: 't',
        title: 'Tee',
        artist: 'Tia',
        album: 'Tau',
        duration: const Duration(seconds: 200),
      );
      final harness = harnessOver(playlists: [stored('p')]);
      final controller = await controllerOf(harness);

      await controller.add('p', [timed], skipDuplicates: false);

      final added = harness.playlistStore.playlists.single.entries.single;
      expect(added.id, 'id-1');
      expect(added.path, timed.file.path);
      expect(added.title, 'Tee');
      expect(added.artist, 'Tia');
      expect(added.album, 'Tau');
      expect(added.duration, const Duration(seconds: 200));
    });

    test('GivenSkipDuplicates_WhenASongIsAlreadyIn_ThenItIsSkipped', () async {
      final harness = harnessOver(
        playlists: [
          stored('p', entries: [snapshotOf('e0', songA)]),
        ],
      );
      final controller = await controllerOf(harness);

      final count = await controller.add('p', [
        songA,
        songB,
      ], skipDuplicates: true);

      expect(count, 1);
      expect(pathsOf(harness.playlistStore.playlists.single), [
        songA.file.path,
        songB.file.path,
      ]);
    });

    test(
      'GivenNoSkipDuplicates_WhenASongIsAlreadyIn_ThenItIsAddedAgain',
      () async {
        final harness = harnessOver(
          playlists: [
            stored('p', entries: [snapshotOf('e0', songA)]),
          ],
        );
        final controller = await controllerOf(harness);

        final count = await controller.add('p', [songA], skipDuplicates: false);

        expect(count, 1);
        expect(pathsOf(harness.playlistStore.playlists.single), [
          songA.file.path,
          songA.file.path,
        ]);
      },
    );

    test(
      'GivenSkipDuplicates_WhenABatchRepeatsASong_ThenTheRepeatIsKept',
      () async {
        final harness = harnessOver(playlists: [stored('p')]);
        final controller = await controllerOf(harness);

        final count = await controller.add('p', [
          songA,
          songA,
        ], skipDuplicates: true);

        expect(count, 2);
        expect(harness.playlistStore.playlists.single.entries, hasLength(2));
      },
    );

    test(
      'GivenOnlyDuplicates_WhenAddedWithSkip_ThenNothingIsWritten',
      () async {
        final harness = harnessOver(
          playlists: [
            stored('p', entries: [snapshotOf('e0', songA)]),
          ],
        );
        final controller = await controllerOf(harness);

        final count = await controller.add('p', [songA], skipDuplicates: true);

        expect(count, 0);
        expect(harness.playlistStore.writes, 0);
      },
    );

    test('GivenASongWhoseTagsChanged_WhenAnythingIsAdded_ThenItsSnapshotIsRefreshed', () async {
      final stale = PlaylistEntry(
        id: 'e0',
        path: songA.file.path,
        title: 'Old title',
        artist: 'Old artist',
      );
      final harness = harnessOver(
        playlists: [
          stored('p', entries: [stale]),
        ],
      );
      final controller = await controllerOf(harness);
      await harness.library();

      await controller.add('p', [songB], skipDuplicates: false);

      final first = harness.playlistStore.playlists.single.entries.first;
      expect(first.id, 'e0');
      expect(first.title, 'Alpha');
      expect(first.artist, 'Ann');
    });

    test(
      'GivenASongMissingFromTheLibrary_WhenAWriteHappens_ThenItsSnapshotStays',
      () async {
        const gone = PlaylistEntry(
          id: 'e0',
          path: '/elsewhere/gone.flac',
          title: 'Gone',
        );
        final harness = harnessOver(
          playlists: [
            stored('p', entries: [gone]),
          ],
        );
        final controller = await controllerOf(harness);
        await harness.library();

        await controller.add('p', [songB], skipDuplicates: false);

        expect(harness.playlistStore.playlists.single.entries.first, gone);
      },
    );

    test(
      'GivenAnUnknownPlaylist_WhenSongsAreAdded_ThenItThrowsAndWritesNothing',
      () async {
        final harness = harnessOver();
        final controller = await controllerOf(harness);

        await expectLater(
          controller.add('nope', [songA], skipDuplicates: false),
          throwsStateError,
        );

        expect(harness.playlistStore.writes, 0);
      },
    );
  });

  group('changing', () {
    List<PlaylistEntry> three() => [
      snapshotOf('e0', songA),
      snapshotOf('e1', songB),
      snapshotOf('e2', songC),
    ];

    test('GivenEntries_WhenSomeAreRemoved_ThenTheRestArePersisted', () async {
      final harness = harnessOver(playlists: [stored('p', entries: three())]);
      final controller = await controllerOf(harness);

      await controller.remove('p', {'e0', 'e2'});

      expect(entryIdsOf(harness), ['e1']);
      expect(harness.playlistStore.playlists.single.modifiedAt, now);
    });

    test('GivenEntries_WhenOneIsMoved_ThenTheNewOrderIsPersisted', () async {
      final harness = harnessOver(playlists: [stored('p', entries: three())]);
      final controller = await controllerOf(harness);

      await controller.move('p', 'e0');

      expect(entryIdsOf(harness), ['e1', 'e2', 'e0']);
      expect(harness.playlistStore.playlists.single.modifiedAt, now);
    });

    test(
      'GivenEntries_WhenOneIsMovedBeforeAnother_ThenItLandsThere',
      () async {
        final harness = harnessOver(playlists: [stored('p', entries: three())]);
        final controller = await controllerOf(harness);

        await controller.move('p', 'e2', beforeEntryId: 'e1');

        expect(entryIdsOf(harness), ['e0', 'e2', 'e1']);
      },
    );

    test(
      'GivenAnEntryThatIsNotThere_WhenItIsMoved_ThenNothingIsWritten',
      () async {
        final harness = harnessOver(playlists: [stored('p', entries: three())]);
        final controller = await controllerOf(harness);

        await controller.move('p', 'gone', beforeEntryId: 'e0');

        expect(harness.playlistStore.writes, 0);
      },
    );

    test('GivenAPlaylist_WhenItIsRenamed_ThenTheNameIsPersisted', () async {
      final harness = harnessOver(playlists: [stored('p')]);
      final controller = await controllerOf(harness);

      await controller.rename('p', ' Commute ');

      final saved = harness.playlistStore.playlists.single;
      expect(saved.name, 'Commute');
      expect(saved.modifiedAt, now);
      expect(harness.read(playlistsControllerProvider).value, [saved]);
    });

    test(
      'GivenABlankName_WhenAPlaylistIsRenamed_ThenItThrowsAndWritesNothing',
      () async {
        final harness = harnessOver(playlists: [stored('p')]);
        final controller = await controllerOf(harness);

        await expectLater(controller.rename('p', ' '), throwsArgumentError);

        expect(harness.playlistStore.writes, 0);
      },
    );
  });

  group('covers', () {
    test(
      'GivenAPicture_WhenItIsSetAsCover_ThenItIsStoredUnderThePlaylistId',
      () async {
        final harness = harnessOver(playlists: [stored('p')]);
        final controller = await controllerOf(harness);
        final bytes = Uint8List.fromList([1, 2, 3]);

        await controller.setCover('p', bytes);

        expect(harness.playlistCovers.covers['p'], bytes);
        expect(harness.playlistStore.playlists.single.coverId, 'p');
      },
    );

    test('GivenACover_WhenItIsRemoved_ThenTheFileAndTheIdAreGone', () async {
      final harness = harnessOver(playlists: [stored('p', coverId: 'p')]);
      harness.playlistCovers.covers['p'] = Uint8List.fromList([1]);
      final controller = await controllerOf(harness);

      await controller.removeCover('p');

      expect(harness.playlistCovers.covers, isEmpty);
      expect(harness.playlistStore.playlists.single.coverId, isNull);
    });

    test(
      'GivenAFailedWrite_WhenACoverIsSet_ThenTheStateStillHasNoCover',
      () async {
        final harness = harnessOver(playlists: [stored('p')]);
        final controller = await controllerOf(harness);
        harness.playlistStore.failNextWrite = Exception('disk full');

        await expectLater(
          controller.setCover('p', Uint8List.fromList([1])),
          throwsException,
        );

        final current = harness.read(playlistsControllerProvider).value!;
        expect(current.single.coverId, isNull);
      },
    );

    test('GivenAFailedWrite_WhenACoverIsRemoved_ThenItsFileIsKept', () async {
      final harness = harnessOver(playlists: [stored('p', coverId: 'p')]);
      harness.playlistCovers.covers['p'] = Uint8List.fromList([1]);
      final controller = await controllerOf(harness);
      harness.playlistStore.failNextWrite = Exception('disk full');

      await expectLater(controller.removeCover('p'), throwsException);

      expect(harness.playlistCovers.covers.keys, ['p']);
    });
  });

  group('delete', () {
    test(
      'GivenTwoPlaylists_WhenOneIsDeleted_ThenOnlyItAndItsCoverGo',
      () async {
        final harness = harnessOver(
          playlists: [
            stored('p', name: 'One', coverId: 'p'),
            stored('q', name: 'Two', coverId: 'q'),
          ],
        );
        final same = Uint8List.fromList([9, 9]);
        harness.playlistCovers.covers['p'] = same;
        harness.playlistCovers.covers['q'] = same;
        final controller = await controllerOf(harness);

        await controller.delete('p');

        expect([for (final p in harness.playlistStore.playlists) p.id], ['q']);
        expect(harness.playlistCovers.deleted, ['p']);
        expect(harness.playlistCovers.covers.keys, ['q']);
        final current = harness.read(playlistsControllerProvider).value!;
        expect([for (final p in current) p.id], ['q']);
      },
    );

    test(
      'GivenAFailedWrite_WhenAPlaylistIsDeleted_ThenItsCoverIsKept',
      () async {
        final harness = harnessOver(playlists: [stored('p', coverId: 'p')]);
        harness.playlistCovers.covers['p'] = Uint8List.fromList([1]);
        final controller = await controllerOf(harness);
        harness.playlistStore.failNextWrite = Exception('disk full');

        await expectLater(controller.delete('p'), throwsException);

        expect(harness.playlistCovers.covers.keys, ['p']);
        expect(harness.read(playlistsControllerProvider).value, hasLength(1));
      },
    );

    test(
      'GivenAPlaylistAlreadyGone_WhenItIsDeletedAgain_ThenNothingHappens',
      () async {
        final harness = harnessOver();
        final controller = await controllerOf(harness);

        await controller.delete('gone');

        expect(harness.playlistStore.writes, 0);
      },
    );
  });

  group('serialising', () {
    test('GivenTwoAddsNotAwaited_WhenBothFinish_ThenBothLanded', () async {
      final harness = harnessOver(playlists: [stored('p')]);
      final controller = await controllerOf(harness);

      final first = controller.add('p', [songA], skipDuplicates: false);
      final second = controller.add('p', [songB], skipDuplicates: false);
      await Future.wait([first, second]);

      expect(pathsOf(harness.playlistStore.playlists.single), [
        songA.file.path,
        songB.file.path,
      ]);
      expect(harness.playlistStore.writes, 2);
    });

    test(
      'GivenAFailedWrite_WhenTheNextMutationRuns_ThenItStillWorks',
      () async {
        final harness = harnessOver(playlists: [stored('p')]);
        final controller = await controllerOf(harness);
        harness.playlistStore.failNextWrite = Exception('disk full');

        final failing = controller.add('p', [songA], skipDuplicates: false);
        final following = controller.add('p', [songB], skipDuplicates: false);

        await expectLater(failing, throwsException);
        await following;
        expect(pathsOf(harness.playlistStore.playlists.single), [
          songB.file.path,
        ]);
      },
    );

    List<PlaylistEntry> three() => [
      snapshotOf('e0', songA),
      snapshotOf('e1', songB),
      snapshotOf('e2', songC),
    ];

    test(
      'GivenAFailedMove_WhenAQuickSecondMoveFollows_ThenItAppliesByIdentity',
      () async {
        final harness = harnessOver(playlists: [stored('p', entries: three())]);
        final controller = await controllerOf(harness);
        harness.playlistStore.failNextWrite = Exception('disk full');

        // e0 dropped at the end, and before that is saved, e2 dropped at the
        // top of what the owner then saw: e1, e2, e0.
        final failing = controller.move('p', 'e0');
        final following = controller.move('p', 'e2', beforeEntryId: 'e1');

        await expectLater(failing, throwsException);
        await following;
        // The second drop on top of what is stored: e2 before e1.
        expect(entryIdsOf(harness), ['e0', 'e2', 'e1']);
      },
    );

    test(
      'GivenARemoveNotYetSaved_WhenAMoveFollows_ThenTheDraggedEntryMoves',
      () async {
        final harness = harnessOver(playlists: [stored('p', entries: three())]);
        final controller = await controllerOf(harness);

        final removing = controller.remove('p', {'e0'});
        final moving = controller.move('p', 'e2', beforeEntryId: 'e1');
        await Future.wait([removing, moving]);

        expect(entryIdsOf(harness), ['e2', 'e1']);
      },
    );

    test(
      'GivenAnEntryRemovedMeanwhile_WhenAMoveOfItRuns_ThenNothingMoves',
      () async {
        final harness = harnessOver(playlists: [stored('p', entries: three())]);
        final controller = await controllerOf(harness);

        final removing = controller.remove('p', {'e1'});
        final moving = controller.move('p', 'e1', beforeEntryId: 'e0');
        await Future.wait([removing, moving]);

        expect(entryIdsOf(harness), ['e0', 'e2']);
        expect(harness.playlistStore.writes, 1);
      },
    );

    test(
      'GivenACreateNotAwaited_WhenAnAddFollows_ThenItFindsThePlaylist',
      () async {
        final harness = harnessOver();
        final controller = await controllerOf(harness);

        final created = controller.create('New');
        final added = controller.add('id-1', [songA], skipDuplicates: false);

        await created;
        expect(await added, 1);
      },
    );
  });

  group('export', () {
    test(
      'GivenAPlaylist_WhenExported_ThenTheSaverGetsTheNameAndTheM3u',
      () async {
        final timed = entry(
          id: 't',
          title: 'Tee',
          artist: 'Tia',
          duration: const Duration(seconds: 200),
        );
        final harness = Harness(
          library: [timed],
          now: now,
          playlists: [
            stored('p', name: 'Road trip', entries: [snapshotOf('e0', timed)]),
          ],
        );
        final controller = await controllerOf(harness);
        await harness.library();

        final exported = await controller.exportM3u('p');

        expect(exported?.path, '/exports/saved');
        final saved = harness.fileSaver.saved.single;
        expect(saved.suggestedName, 'Road trip.m3u');
        expect(
          utf8.decode(saved.bytes),
          '#EXTM3U\n#EXTINF:200,Tia - Tee\n${timed.file.path}\n',
        );
      },
    );

    test('GivenACancelledDialog_WhenExported_ThenItReturnsNull', () async {
      final harness = harnessOver(playlists: [stored('p')]);
      harness.fileSaver.next = null;
      final controller = await controllerOf(harness);

      expect(await controller.exportM3u('p'), isNull);
      expect(harness.fileSaver.saved, isEmpty);
    });

    test('GivenASaverThatFails_WhenExported_ThenItThrows', () async {
      final harness = harnessOver(playlists: [stored('p')]);
      harness.fileSaver.failure = Exception('no space');
      final controller = await controllerOf(harness);

      await expectLater(controller.exportM3u('p'), throwsException);
    });
  });

  group('unreadable store', () {
    // Every change, each against a playlist that would be there if the
    // document could be read.
    final mutations = <String, Future<Object?> Function(PlaylistsController)>{
      'create': (controller) => controller.create('Road trip'),
      'add': (controller) =>
          controller.add('p', [songA], skipDuplicates: false),
      'remove': (controller) => controller.remove('p', {'e0'}),
      'move': (controller) => controller.move('p', 'e0'),
      'rename': (controller) => controller.rename('p', 'Commute'),
      'setCover': (controller) =>
          controller.setCover('p', Uint8List.fromList([1])),
      'removeCover': (controller) => controller.removeCover('p'),
      'delete': (controller) => controller.delete('p'),
      'exportM3u': (controller) => controller.exportM3u('p'),
    };

    for (final MapEntry(key: name, value: mutate) in mutations.entries) {
      test(
        'GivenTheStoreCannotBeRead_When${name}IsCalled_ThenItThrowsAndWritesNothing',
        () async {
          final harness = harnessOver();
          harness.playlistStore.failRead = Exception('unreadable');
          await expectLater(
            harness.container.read(playlistsControllerProvider.future),
            throwsException,
          );
          final controller = harness.container.read(
            playlistsControllerProvider.notifier,
          );
          expect(harness.read(playlistsControllerProvider).hasError, isTrue);

          await expectLater(mutate(controller), throwsStateError);

          expect(harness.playlistStore.writes, 0);
          expect(harness.playlistCovers.covers, isEmpty);
          expect(harness.playlistCovers.deleted, isEmpty);
          expect(harness.fileSaver.saved, isEmpty);
        },
      );
    }
  });
}
