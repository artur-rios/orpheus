import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/core/app_directories.dart';
import 'package:orpheus/core/di/providers.dart';
import 'package:orpheus/core/settings/in_memory_settings_store.dart';
import 'package:orpheus/core/settings/settings_store.dart';
import 'package:orpheus/features/library/domain/music_catalog.dart';
import 'package:orpheus/features/library/domain/music_entry.dart';
import 'package:orpheus/features/library/domain/music_grouping.dart';

import 'fake_media_player.dart';
import 'fake_media_session.dart';
import 'fake_track_probe.dart';
import 'fakes.dart';

/// Everything a test needs bound, and nothing reaching outside the process.
///
/// No test reads the developer's own preferences, writes into their
/// application-support folder, opens the native playback engine, or touches
/// the filesystem: every one of those is a provider, and every one of them is
/// overridden here.
class Harness {
  /// Builds a container over [library], with the doubles the test can inspect.
  Harness({
    List<MusicEntry> library = const [],
    Set<String> missingTracks = const {},
    SettingsStore? settings,
    ScriptedScanner? scanner,
    FakeLibraryAccess? access,
    FakeFolderPicker? picker,
    int shuffleSeed = 7,
    DateTime? now,
  }) : player = FakeMediaPlayer(),
       session = FakeMediaSession(),
       probe = FakeTrackProbe(missing: {...missingTracks}),
       covers = InMemoryCoverStore(),
       access = access ?? FakeLibraryAccess(),
       picker = picker ?? FakeFolderPicker(),
       settings = settings ?? InMemorySettingsStore(),
       catalogs = InMemoryCatalogStore(
         MusicCatalog(
           // Through the same derivation the application uses, so a test's
           // fixture is grouped exactly as a scanned library would be.
           entries: albumArtistsAcross(library),
           // A library with nothing in it has never been scanned, which is
           // what the folders screen says about it — seeding a timestamp for
           // one would make that state untestable.
           scannedAt: library.isEmpty ? null : DateTime.utc(2026),
         ),
       ) {
    container = ProviderContainer(
      overrides: [
        settingsStoreProvider.overrideWithValue(this.settings),
        appDirectoriesProvider.overrideWithValue(
          const AppDirectories('/test/support'),
        ),
        catalogStoreProvider.overrideWithValue(catalogs),
        coverStoreProvider.overrideWithValue(covers),
        audioPlayerProvider.overrideWithValue(player),
        mediaSessionProvider.overrideWithValue(session),
        trackProbeProvider.overrideWithValue(probe),
        libraryAccessProvider.overrideWithValue(this.access),
        folderPickerProvider.overrideWithValue(this.picker),
        if (scanner != null) libraryScannerProvider.overrideWithValue(scanner),
        shuffleRandomProvider.overrideWithValue(Random(shuffleSeed)),
        if (now != null) clockProvider.overrideWithValue(() => now),
      ],
    );

    addTearDown(container.dispose);
  }

  /// The provider graph under test.
  late final ProviderContainer container;

  /// The engine, which records what it was asked to open.
  final FakeMediaPlayer player;

  /// The platform's media session, which records what it was shown.
  final FakeMediaSession session;

  /// Which queued files exist.
  final FakeTrackProbe probe;

  /// The catalog, in memory.
  final InMemoryCatalogStore catalogs;

  /// The covers, in memory.
  final InMemoryCoverStore covers;

  /// The preferences, in memory.
  final SettingsStore settings;

  /// The permission gate.
  final FakeLibraryAccess access;

  /// The folder chooser.
  final FakeFolderPicker picker;

  /// Reads a provider's value.
  T read<T>(ProviderListenable<T> provider) => container.read(provider);

  /// Waits for the library to load, which every player flow depends on.
  Future<MusicCatalog> library() =>
      container.read(musicLibraryControllerProvider.future);
}
