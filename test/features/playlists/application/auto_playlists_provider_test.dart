import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/core/di/providers.dart';
import 'package:orpheus/core/settings/in_memory_settings_store.dart';
import 'package:orpheus/features/library/domain/music_catalog.dart';
import 'package:orpheus/features/playlists/domain/auto_playlists.dart';
import 'package:orpheus/features/playlists/domain/playlist.dart';
import 'package:orpheus/features/stats/domain/play_history.dart';

import '../../../support/entries.dart';
import '../../../support/test_container.dart';

/// The two auto playlists as the rest of the application sees them: derived
/// from the history, the library, the clock and the preference.
void main() {
  final now = DateTime.utc(2026, 10, 18, 12);

  final aria = entry(
    id: 'aria',
    title: 'Aria',
    artist: 'Ada',
    album: 'First',
    duration: const Duration(minutes: 3),
  );
  final bolero = entry(id: 'bolero', title: 'Bolero', artist: 'Bea');
  final canon = entry(id: 'canon', title: 'Canon');

  TrackPlays played(
    String path, {
    required int plays,
    required DateTime last,
  }) =>
      TrackPlays(path: path, plays: plays, lastPlayedAt: last, recent: [last]);

  PlayHistory historyOf(List<TrackPlays> tracks) =>
      PlayHistory(tracks: {for (final track in tracks) track.path: track});

  /// The playlists once everything they depend on has loaded.
  Future<List<Playlist>> loaded(Harness harness) async {
    await harness.library();
    await harness.read(playHistoryProvider.future);

    return harness.read(autoPlaylistsProvider).requireValue;
  }

  List<String> pathsIn(Playlist playlist) => [
    for (final entry in playlist.entries) entry.path,
  ];

  Playlist byId(List<Playlist> playlists, String id) =>
      playlists.singleWhere((playlist) => playlist.id == id);

  test(
    'GivenThePreferenceIsOn_WhenTheyAreRead_ThenThereAreTwoWithFixedIds',
    () async {
      final harness = Harness(library: [aria], now: now);

      final playlists = await loaded(harness);

      expect(
        [for (final playlist in playlists) playlist.id],
        [autoLatelyId, autoAllTimeId],
      );
    },
  );

  test('GivenPlayedSongs_WhenTheyAreRead_ThenEachListHoldsThemWithTheirPathAsEntryIdAndTheCatalogSnapshot', () async {
    final harness = Harness(library: [aria, bolero, canon], now: now);
    harness.plays.history = historyOf([
      played(aria.file.path, plays: 5, last: now),
      played(bolero.file.path, plays: 2, last: now),
    ]);

    final playlists = await loaded(harness);

    final allTime = byId(playlists, autoAllTimeId);
    expect(pathsIn(allTime), [aria.file.path, bolero.file.path]);
    final first = allTime.entries.first;
    expect(first.id, aria.file.path);
    expect(first.title, 'Aria');
    expect(first.artist, 'Ada');
    expect(first.album, 'First');
    expect(first.duration, const Duration(minutes: 3));
    expect(pathsIn(byId(playlists, autoLatelyId)), [
      aria.file.path,
      bolero.file.path,
    ]);
  });

  test('GivenTheyAreRead_WhenTheyAreRead_ThenTheyCarryNoLocalisedNameAndAFixedTime', () async {
    final harness = Harness(library: [aria], now: now);
    harness.plays.history = historyOf([
      played(aria.file.path, plays: 1, last: now),
    ]);

    final first = await loaded(harness);
    // Later, after something has changed.
    await harness.read(playRecorderProvider).record(aria.file.path);
    await pumpEventQueue();
    final second = harness.read(autoPlaylistsProvider).requireValue;

    for (final playlist in first) {
      expect(playlist.name, isEmpty);
      expect(playlist.coverId, isNull);
    }
    expect(
      [for (final playlist in second) playlist.modifiedAt],
      [for (final playlist in first) playlist.modifiedAt],
    );
    expect(
      [for (final playlist in second) playlist.createdAt],
      [for (final playlist in first) playlist.createdAt],
    );
  });

  test('GivenNothingWasPlayed_WhenTheyAreRead_ThenBothAreEmpty', () async {
    final harness = Harness(library: [aria], now: now);

    final playlists = await loaded(harness);

    expect(playlists, hasLength(2));
    expect(playlists.every((playlist) => playlist.entries.isEmpty), isTrue);
  });

  test(
    'GivenASongPlayedButNoLongerInTheLibrary_WhenTheyAreRead_ThenItIsLeftOut',
    () async {
      final harness = Harness(library: [aria], now: now);
      harness.plays.history = historyOf([
        played(aria.file.path, plays: 1, last: now),
        played(bolero.file.path, plays: 9, last: now),
      ]);

      final playlists = await loaded(harness);

      expect(pathsIn(byId(playlists, autoAllTimeId)), [aria.file.path]);
      expect(pathsIn(byId(playlists, autoLatelyId)), [aria.file.path]);
    },
  );

  test('GivenThePreferenceIsOff_WhenTheyAreRead_ThenThereAreNoneAndNothingIsLoading', () {
    final harness = Harness(
      library: [aria],
      now: now,
      settings: InMemorySettingsStore(showsAutoPlaylists: false),
    );

    final playlists = harness.read(autoPlaylistsProvider);

    expect(playlists.hasValue, isTrue);
    expect(playlists.requireValue, isEmpty);
  });

  test(
    'GivenTheCatalogHasNotLoaded_WhenTheyAreRead_ThenTheyAreLoading',
    () async {
      final harness = Harness(library: [aria], now: now);
      await harness.read(playHistoryProvider.future);

      expect(harness.read(autoPlaylistsProvider).isLoading, isTrue);

      await harness.library();

      expect(harness.read(autoPlaylistsProvider).hasValue, isTrue);
    },
  );

  test(
    'GivenTheHistoryHasNotLoaded_WhenTheyAreRead_ThenTheyAreLoading',
    () async {
      final harness = Harness(library: [aria], now: now);
      await harness.library();

      expect(harness.read(autoPlaylistsProvider).isLoading, isTrue);

      await harness.read(playHistoryProvider.future);

      expect(harness.read(autoPlaylistsProvider).hasValue, isTrue);
    },
  );

  test(
    'GivenTheCatalogCannotBeRead_WhenTheyAreRead_ThenTheyAreAnError',
    () async {
      final harness = Harness(library: [aria], now: now);
      harness.catalogs.failOnRead = true;
      await harness.read(playHistoryProvider.future);
      await harness
          .read(musicLibraryControllerProvider.future)
          .then<void>((_) {}, onError: (Object _) {});

      expect(harness.read(autoPlaylistsProvider).hasError, isTrue);
    },
  );

  test('GivenTheyAreWatched_WhenAPlayIsRecorded_ThenTheyUpdate', () async {
    final harness = Harness(library: [aria, bolero], now: now);
    harness.container.listen(autoPlaylistsProvider, (_, _) {});
    final before = await loaded(harness);
    expect(byId(before, autoAllTimeId).entries, isEmpty);

    await harness.read(playRecorderProvider).record(bolero.file.path);
    await pumpEventQueue();

    final after = harness.read(autoPlaylistsProvider).requireValue;
    expect(pathsIn(byId(after, autoAllTimeId)), [bolero.file.path]);
    expect(pathsIn(byId(after, autoLatelyId)), [bolero.file.path]);
  });

  test('GivenTheyAreWatched_WhenTheCatalogChanges_ThenTheyUpdate', () async {
    final harness = Harness(library: [aria], now: now);
    harness.plays.history = historyOf([
      played(aria.file.path, plays: 4, last: now),
      played(bolero.file.path, plays: 2, last: now),
    ]);
    harness.container.listen(autoPlaylistsProvider, (_, _) {});
    final before = await loaded(harness);
    expect(pathsIn(byId(before, autoAllTimeId)), [aria.file.path]);

    harness
        .read(musicLibraryControllerProvider.notifier)
        .replaceWith(MusicCatalog(entries: [aria, bolero]));
    await pumpEventQueue();

    final after = harness.read(autoPlaylistsProvider).requireValue;
    expect(pathsIn(byId(after, autoAllTimeId)), [
      aria.file.path,
      bolero.file.path,
    ]);
  });

  test('GivenTheyAreWatched_WhenASongIsRetaggedInTheCatalog_ThenTheSnapshotFollows', () async {
    final harness = Harness(library: [aria], now: now);
    harness.plays.history = historyOf([
      played(aria.file.path, plays: 4, last: now),
    ]);
    harness.container.listen(autoPlaylistsProvider, (_, _) {});
    await loaded(harness);

    harness
        .read(musicLibraryControllerProvider.notifier)
        .replaceWith(
          MusicCatalog(
            entries: [entry(id: 'aria', title: 'Aria (remaster)')],
          ),
        );
    await pumpEventQueue();

    final after = harness.read(autoPlaylistsProvider).requireValue;
    expect(byId(after, autoAllTimeId).entries.single.title, 'Aria (remaster)');
  });

  test(
    'GivenTheyAreShown_WhenThePreferenceIsTurnedOff_ThenThereAreNone',
    () async {
      final harness = Harness(library: [aria], now: now);
      harness.container.listen(autoPlaylistsProvider, (_, _) {});
      await loaded(harness);

      await harness
          .read(preferencesControllerProvider.notifier)
          .setShowsAutoPlaylists(false);

      expect(harness.read(autoPlaylistsProvider).requireValue, isEmpty);

      await harness
          .read(preferencesControllerProvider.notifier)
          .setShowsAutoPlaylists(true);

      expect(harness.read(autoPlaylistsProvider).requireValue, hasLength(2));
    },
  );

  group('the fallback', () {
    test('GivenFewerRecentSongsThanLatelyNeeds_WhenItIsRead_ThenFavouritesLatelyIsTheFallback', () async {
      final harness = Harness(library: [aria], now: now);
      harness.plays.history = historyOf([
        played(aria.file.path, plays: 1, last: now),
      ]);
      await loaded(harness);

      expect(harness.read(autoLatelyIsFallbackProvider), isTrue);
    });

    test('GivenEnoughRecentSongs_WhenItIsRead_ThenFavouritesLatelyIsNotTheFallback', () async {
      final many = [for (var i = 0; i < latelyEnough; i++) entry(id: 'm$i')];
      final harness = Harness(library: many, now: now);
      harness.plays.history = historyOf([
        for (final song in many) played(song.file.path, plays: 1, last: now),
      ]);
      await loaded(harness);

      expect(harness.read(autoLatelyIsFallbackProvider), isFalse);
    });

    test('GivenNothingPlayed_WhenItIsRead_ThenThereIsNoFallback', () async {
      final harness = Harness(library: [aria], now: now);
      await loaded(harness);

      expect(harness.read(autoLatelyIsFallbackProvider), isFalse);
    });

    test(
      'GivenThePreferenceIsOff_WhenItIsRead_ThenThereIsNoFallback',
      () async {
        final harness = Harness(
          library: [aria],
          now: now,
          settings: InMemorySettingsStore(showsAutoPlaylists: false),
        );
        harness.plays.history = historyOf([
          played(aria.file.path, plays: 1, last: now),
        ]);
        await harness.library();
        await harness.read(playHistoryProvider.future);

        expect(harness.read(autoLatelyIsFallbackProvider), isFalse);
      },
    );
  });
}
