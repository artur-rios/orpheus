import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/core/settings/in_memory_settings_store.dart';
import 'package:orpheus/features/playback/data/settings_playback_position_store.dart';
import 'package:orpheus/features/playback/domain/playback_position_store.dart';

/// The resume points, kept in one settings key.
///
/// A resume point that does not survive a restart is not one, and a stored
/// document nobody can read must cost the owner their resume points, never the
/// start of the application.
void main() {
  const key = SettingsPlaybackPositionStore.settingsKey;

  PlaybackPosition positionOf(
    String path, {
    int seconds = 42,
    int? durationSeconds = 300,
    int minute = 0,
  }) => PlaybackPosition(
    path: path,
    position: Duration(seconds: seconds),
    duration: durationSeconds == null
        ? null
        : Duration(seconds: durationSeconds),
    updatedAt: DateTime.utc(2026, 1, 1).add(Duration(minutes: minute)),
  );

  test('GivenNothingStored_WhenAPositionIsAskedFor_ThenThereIsNone', () {
    final store = SettingsPlaybackPositionStore(InMemorySettingsStore());

    expect(store.positionFor('/music/a.flac'), isNull);
  });

  test(
    'GivenARecordedPosition_WhenANewStoreReadsTheSameSettings_ThenItIsThere',
    () async {
      final settings = InMemorySettingsStore();
      await SettingsPlaybackPositionStore(
        settings,
      ).record(positionOf('/music/a.flac', seconds: 42, durationSeconds: 300));

      final read = SettingsPlaybackPositionStore(
        settings,
      ).positionFor('/music/a.flac')!;

      expect(read.path, '/music/a.flac');
      expect(read.position, const Duration(seconds: 42));
      expect(read.duration, const Duration(seconds: 300));
      expect(read.updatedAt, DateTime.utc(2026, 1, 1));
    },
  );

  test(
    'GivenAPositionWithNoDuration_WhenItRoundTrips_ThenTheDurationStaysUnknown',
    () async {
      final settings = InMemorySettingsStore();
      await SettingsPlaybackPositionStore(
        settings,
      ).record(positionOf('/music/a.flac', durationSeconds: null));

      final stored =
          jsonDecode(settings.getString(key)!) as Map<String, dynamic>;
      expect(
        (stored['/music/a.flac'] as Map<String, dynamic>).containsKey(
          'durationMs',
        ),
        isFalse,
      );
      expect(
        SettingsPlaybackPositionStore(
          settings,
        ).positionFor('/music/a.flac')!.duration,
        isNull,
      );
    },
  );

  test(
    'GivenAPositionForTheSameFile_WhenRecordedAgain_ThenTheNewOneReplacesIt',
    () async {
      final store = SettingsPlaybackPositionStore(InMemorySettingsStore());

      await store.record(positionOf('/music/a.flac', seconds: 10));
      await store.record(positionOf('/music/a.flac', seconds: 20, minute: 1));

      expect(
        store.positionFor('/music/a.flac')!.position,
        const Duration(seconds: 20),
      );
    },
  );

  test(
    'GivenARecordedPosition_WhenItIsForgotten_ThenNeitherThisStoreNorTheNextHasIt',
    () async {
      final settings = InMemorySettingsStore();
      final store = SettingsPlaybackPositionStore(settings);
      await store.record(positionOf('/music/a.flac'));
      await store.record(positionOf('/music/b.flac'));

      await store.forget('/music/a.flac');

      expect(store.positionFor('/music/a.flac'), isNull);
      final reread = SettingsPlaybackPositionStore(settings);
      expect(reread.positionFor('/music/a.flac'), isNull);
      expect(reread.positionFor('/music/b.flac'), isNotNull);
    },
  );

  test(
    'GivenAFullStore_WhenOneMoreIsRecorded_ThenOnlyTheOldestIsDropped',
    () async {
      final settings = InMemorySettingsStore();
      final store = SettingsPlaybackPositionStore(settings);
      const limit = SettingsPlaybackPositionStore.limit;
      // Recorded newest first, so the oldest is not simply the first in.
      for (var i = limit; i >= 0; i--) {
        await store.record(positionOf('/music/$i.flac', minute: i));
      }

      expect(store.positionFor('/music/0.flac'), isNull);
      expect(store.positionFor('/music/1.flac'), isNotNull);
      expect(store.positionFor('/music/$limit.flac'), isNotNull);
      final stored =
          jsonDecode(settings.getString(key)!) as Map<String, dynamic>;
      expect(stored, hasLength(limit));
    },
  );

  test(
    'GivenExactlyAsManyAsItKeeps_WhenRecorded_ThenNoneIsDropped',
    () async {
      final store = SettingsPlaybackPositionStore(InMemorySettingsStore());
      const limit = SettingsPlaybackPositionStore.limit;

      for (var i = 0; i < limit; i++) {
        await store.record(positionOf('/music/$i.flac', minute: i));
      }

      expect(store.positionFor('/music/0.flac'), isNotNull);
      expect(store.positionFor('/music/${limit - 1}.flac'), isNotNull);
    },
  );

  for (final (name, stored) in [
    ('NotJson', 'not json'),
    ('AList', '[1, 2]'),
    ('ARowThatIsNotAnObject', '{"/music/a.flac": 7}'),
    ('ARowWithNoPosition', '{"/music/a.flac": {"updatedAt": "2026-01-01"}}'),
    ('ARowWithABadDate', '{"/music/a.flac": {"positionMs": 1, "updatedAt": "x"}}'),
  ]) {
    test(
      'Given${name}Stored_WhenTheStoreStarts_ThenItStartsEmptyAndStillRecords',
      () async {
        final settings = InMemorySettingsStore(values: {key: stored});

        final store = SettingsPlaybackPositionStore(settings);

        expect(store.positionFor('/music/a.flac'), isNull);
        await store.record(positionOf('/music/b.flac'));
        expect(
          SettingsPlaybackPositionStore(settings).positionFor('/music/b.flac'),
          isNotNull,
        );
      },
    );
  }
}
