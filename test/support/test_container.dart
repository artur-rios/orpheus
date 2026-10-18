import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/core/app_directories.dart';
import 'package:orpheus/core/di/providers.dart';
import 'package:orpheus/core/settings/in_memory_settings_store.dart';
import 'package:orpheus/core/platform/host_platform.dart';
import 'package:orpheus/core/settings/settings_store.dart';
import 'package:orpheus/features/library/domain/library_scan.dart';
import 'package:orpheus/features/library/domain/music_catalog.dart';
import 'package:orpheus/features/library/domain/music_entry.dart';
import 'package:orpheus/features/library/domain/music_grouping.dart';
import 'package:orpheus/features/playlists/domain/playlist.dart';
import 'package:orpheus/features/updates/application/update_controller.dart';
import 'package:orpheus/features/updates/domain/app_version.dart';

import 'fake_autofill.dart';
import 'fake_media_player.dart';
import 'fake_media_session.dart';
import 'fake_playlists.dart';
import 'fake_story_share.dart';
import 'fake_tag_editor.dart';
import 'fake_track_probe.dart';
import 'fake_updates.dart';
import 'fakes.dart';

/// Everything a test needs bound, and nothing reaching outside the process.
///
/// No test reads the developer's own preferences, writes into their
/// application-support folder, records a play against their listening
/// statistics, opens the native playback engine, starts a platform media
/// service, reaches a network, writes into a music folder, or touches the
/// filesystem: every one of those is a provider, and every one of them is
/// overridden here.
class Harness {
  /// Builds a container over [library], with the doubles the test can inspect.
  Harness({
    List<MusicEntry> library = const [],
    Set<String> missingTracks = const {},
    SettingsStore? settings,
    LibraryScanner? scanner,
    ScriptedTrackAnalysis? analysis,
    ScriptedLyricsSource? lyrics,
    ScriptedRemoteLyricsSource? remoteLyrics,
    FakeLibraryAccess? access,
    FakeFolderPicker? picker,
    int shuffleSeed = 7,
    DateTime? now,
    ScriptedReleaseSource? releases,
    ScriptedUpdateInstaller? updates,
    RecordingStoryShare? storyShare,
    AppVersion? runningVersion,
    HostPlatform? platform,
    ScriptedMetadataSource? metadata,
    FakeTagWriter? tagWriter,
    FakeFileStamps? stamps,
    FakeCoverPicker? coverPicker,
    List<Playlist> playlists = const [],
    FakeFileSaver? fileSaver,
    String Function()? idGenerator,
  }) : player = FakeMediaPlayer(),
       storyShare = storyShare ?? RecordingStoryShare(),
       releases = releases ?? ScriptedReleaseSource(),
       updates = updates ?? ScriptedUpdateInstaller(),
       metadata = metadata ?? ScriptedMetadataSource(),
       tagWriter = tagWriter ?? FakeTagWriter(),
       stamps = stamps ?? FakeFileStamps(),
       coverPicker = coverPicker ?? FakeCoverPicker(),
       shutdown = RecordingAppShutdown(),
       _runningVersion = runningVersion ?? AppVersion.tryParse('1.0.0'),
       session = FakeMediaSession(),
       probe = FakeTrackProbe(missing: {...missingTracks}),
       covers = InMemoryCoverStore(),
       energies = InMemoryEnergyStore(),
       analysis = analysis ?? ScriptedTrackAnalysis(),
       lyrics = lyrics ?? ScriptedLyricsSource(),
       remoteLyrics = remoteLyrics ?? ScriptedRemoteLyricsSource(),
       sidecars = RecordingLyricsSidecar(),
       plays = InMemoryPlayHistoryStore(),
       playlistStore = FakePlaylistStore(playlists),
       playlistCovers = FakePlaylistCoverStore(),
       fileSaver = fileSaver ?? FakeFileSaver(),
       access = access ?? FakeLibraryAccess(),
       picker = picker ?? FakeFolderPicker(),
       platform = platform ?? const FakeHostPlatform(),
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
        energyStoreProvider.overrideWithValue(energies),
        trackAnalysisProvider.overrideWithValue(this.analysis),
        lyricsSourceProvider.overrideWithValue(this.lyrics),
        remoteLyricsSourceProvider.overrideWithValue(this.remoteLyrics),
        lyricsSidecarProvider.overrideWithValue(sidecars),
        playHistoryStoreProvider.overrideWithValue(plays),
        playlistStoreProvider.overrideWithValue(playlistStore),
        playlistCoverStoreProvider.overrideWithValue(playlistCovers),
        fileSaverProvider.overrideWithValue(this.fileSaver),
        // Ids a test can name: `id-1`, `id-2`, ... in the order they are asked
        // for, rather than random ones.
        idGeneratorProvider.overrideWithValue(idGenerator ?? _sequentialIds()),
        audioPlayerProvider.overrideWithValue(player),
        mediaSessionProvider.overrideWithValue(session),
        trackProbeProvider.overrideWithValue(probe),
        libraryAccessProvider.overrideWithValue(this.access),
        folderPickerProvider.overrideWithValue(this.picker),
        hostPlatformProvider.overrideWithValue(this.platform),
        if (scanner != null) libraryScannerProvider.overrideWithValue(scanner),
        shuffleRandomProvider.overrideWithValue(Random(shuffleSeed)),
        if (now != null) clockProvider.overrideWithValue(() => now),
        // The second and last thing in this application that reaches a
        // network, and the one thing in it that would start a process. Both
        // are bound to doubles here for the same reason every other gateway
        // is: no test asks GitHub anything, and no test runs an installer.
        releaseSourceProvider.overrideWithValue(this.releases),
        updateInstallerProvider.overrideWithValue(this.updates),
        // The third thing that reaches a network, and the one thing in this
        // application that writes into an audio file. No test does either.
        metadataSourceProvider.overrideWithValue(this.metadata),
        tagWriterProvider.overrideWithValue(this.tagWriter),
        fileStampsProvider.overrideWithValue(this.stamps),
        coverPickerProvider.overrideWithValue(this.coverPicker),
        appShutdownProvider.overrideWithValue(shutdown),
        storyShareProvider.overrideWithValue(this.storyShare),
        runningVersionProvider.overrideWithValue(_runningVersion),
      ],
    );

    addTearDown(container.dispose);
  }

  /// Which host the code under test believes it is running on.
  ///
  /// A double rather than the machine the suite happens to run on, because
  /// the decisions that turn on it — a window to manage, a storage
  /// permission to ask for, a card Android mounts out of reach — are
  /// decisions no developer's own platform should be the one to make.
  final HostPlatform platform;

  /// The provider graph under test.
  late final ProviderContainer container;

  /// The engine, which records what it was asked to open.
  final FakeMediaPlayer player;

  /// What a release check finds.
  final ScriptedReleaseSource releases;

  /// What applying an update does.
  final ScriptedUpdateInstaller updates;

  /// What a search of MusicBrainz answers, in place of a network.
  final ScriptedMetadataSource metadata;

  /// The files autofill reads and writes, in place of the owner's music
  /// folder.
  final FakeTagWriter tagWriter;

  /// The file stamps every tag edit is measured against.
  final FakeFileStamps stamps;

  /// The cover picker.
  final FakeCoverPicker coverPicker;

  /// Whether the application was asked to quit so an installer could run.
  final RecordingAppShutdown shutdown;

  /// Where a shared story card went.
  final RecordingStoryShare storyShare;

  final AppVersion? _runningVersion;

  /// The platform's media session, which records what it was shown.
  final FakeMediaSession session;

  /// Which queued files exist.
  final FakeTrackProbe probe;

  /// The catalog, in memory.
  final InMemoryCatalogStore catalogs;

  /// The covers, in memory.
  final InMemoryCoverStore covers;

  /// The analysed spectra, in memory.
  final InMemoryEnergyStore energies;

  /// What the sound bars' analysis answers, in place of libmpv.
  final ScriptedTrackAnalysis analysis;

  /// What the words of each track are, in place of files on a disk.
  final ScriptedLyricsSource lyrics;

  /// What the lookup answers, in place of a network. No test opens a socket.
  final ScriptedRemoteLyricsSource remoteLyrics;

  /// What a fetched sheet was written as, in place of the owner's music
  /// folder. No test writes into one.
  final RecordingLyricsSidecar sidecars;

  /// What has been played, in memory.
  final InMemoryPlayHistoryStore plays;

  /// The playlists, in memory.
  final FakePlaylistStore playlistStore;

  /// The playlists' own covers, in memory.
  final FakePlaylistCoverStore playlistCovers;

  /// Where an exported playlist went, in place of the owner's disk.
  final FakeFileSaver fileSaver;

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

/// Ids `id-1`, `id-2`, ... for a test that wants to say which one it means.
String Function() _sequentialIds() {
  var last = 0;
  return () => 'id-${++last}';
}
