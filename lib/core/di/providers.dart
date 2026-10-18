/// The single composition root.
///
/// Every outward dependency is bound here and nowhere else, so a test
/// overrides the binding rather than reaching into the widget tree or patching
/// a global. The provider graph is also the one place allowed to see every
/// layer, which is why it sits outside the layered tree.
///
/// A feature adds its gateway here and changes nothing else.
library;

import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/autofill/application/autofill_controller.dart';
import '../../features/autofill/data/audio_metadata_tag_writer.dart';
import '../../features/autofill/data/musicbrainz_source.dart';
import '../../features/autofill/domain/metadata_source.dart';
import '../../features/autofill/domain/tag_writer.dart';
import '../../features/library/application/library_folders_controller.dart';
import '../../features/library/application/music_library_controller.dart';
import '../../features/library/application/scan_controller.dart';
import '../../features/library/data/file_cover_store.dart';
import '../../features/library/data/file_picker_folder_picker.dart';
import '../../features/library/data/isolate_library_scanner.dart';
import '../../features/library/data/json_catalog_store.dart';
import '../../features/library/data/permission_library_access.dart';
import '../../features/library/domain/catalog_store.dart';
import '../../features/library/domain/cover_store.dart';
import '../../features/library/domain/library_access.dart';
import '../../features/library/domain/library_scan.dart';
import '../../features/library/domain/music_catalog.dart';
import '../../features/lyrics/application/lyrics_controller.dart';
import '../../features/lyrics/application/lyrics_visibility_controller.dart';
import '../../features/lyrics/data/file_lyrics_sidecar.dart';
import '../../features/lyrics/data/file_lyrics_source.dart';
import '../../features/lyrics/data/lrclib_lyrics_source.dart';
import '../../features/lyrics/domain/lyrics.dart';
import '../../features/lyrics/domain/lyrics_sidecar.dart';
import '../../features/lyrics/domain/lyrics_source.dart';
import '../../features/lyrics/domain/remote_lyrics_source.dart';
import '../../features/playback/application/album_art_controller.dart';
import '../../features/playback/application/audio_playback_controller.dart';
import '../../features/playback/application/genre_browse_controller.dart';
import '../../features/playback/application/media_session_controller.dart';
import '../../features/playback/application/music_browse_controller.dart';
import '../../features/playback/application/music_layout_controller.dart';
import '../../features/playback/application/song_selection_controller.dart';
import '../../features/playback/application/track_energy_controller.dart';
import '../../features/playback/data/file_energy_store.dart';
import '../../features/playback/data/file_track_probe.dart';
import '../../features/playback/data/media_kit_player.dart';
import '../../features/playback/data/mpv_track_analysis.dart';
import '../../features/playback/data/settings_playback_position_store.dart';
import '../../features/playback/data/silent_media_session.dart';
import '../../features/playback/domain/energy_store.dart';
import '../../features/playback/domain/media_player.dart';
import '../../features/playback/domain/media_session.dart';
import '../../features/playback/domain/music_layout.dart';
import '../../features/playback/domain/playback_position_store.dart';
import '../../features/playback/domain/song_selection.dart';
import '../../features/playback/domain/track_analysis.dart';
import '../../features/playback/domain/track_energy.dart';
import '../../features/playback/domain/track_probe.dart';
import '../../features/playlists/application/playlist_browse_controller.dart';
import '../../features/playlists/application/playlists_controller.dart';
import '../../features/playlists/data/file_picker_file_saver.dart';
import '../../features/playlists/data/file_playlist_cover_store.dart';
import '../../features/playlists/data/json_playlist_store.dart';
import '../../features/playlists/domain/file_saver.dart';
import '../../features/playlists/domain/playlist.dart';
import '../../features/playlists/domain/playlist_cover_store.dart';
import '../../features/playlists/domain/playlist_store.dart';
import '../../features/shell/application/preferences_controller.dart';
import '../../features/shell/application/shell_controller.dart';
import '../../features/shell/domain/shell_destination.dart';
import '../../features/stats/application/music_stats_controller.dart';
import '../../features/stats/application/play_recorder.dart';
import '../../features/stats/data/json_play_history_store.dart';
import '../../features/stats/data/platform_story_share.dart';
import '../../features/stats/domain/music_stats.dart';
import '../../features/stats/domain/play_history.dart';
import '../../features/stats/domain/story_share.dart';
import '../../features/tag_editor/application/many_tag_edit_controller.dart';
import '../../features/tag_editor/application/tag_edit_controller.dart';
import '../../features/tag_editor/data/file_picker_cover_picker.dart';
import '../../features/tag_editor/data/io_file_stamps.dart';
import '../../features/tag_editor/domain/cover_picker.dart';
import '../../features/tag_editor/domain/file_stamps.dart';
import '../../features/updates/application/update_controller.dart';
import '../../features/updates/data/github_release_source.dart';
import '../../features/updates/data/installer_update.dart';
import '../../features/updates/domain/release_source.dart';
import '../../features/updates/domain/update_installer.dart';
import '../app_directories.dart';
import '../platform/app_shutdown.dart';
import '../platform/host_platform.dart';
import '../settings/settings_store.dart';

/// The loaded settings store.
///
/// Overridden in `main` with the store the platform actually holds, and in
/// every test with an in-memory one. There is no default: a settings store
/// built lazily here would be a second one, and the window is placed from the
/// real one before the first frame.
final settingsStoreProvider = Provider<SettingsStore>(
  (ref) => throw StateError('the settings store was not bound'),
);

/// Where this application writes.
///
/// Overridden in `main`, and in tests with a temporary directory — which is
/// what keeps a test from writing a catalog into the developer's own
/// application-support folder.
final appDirectoriesProvider = Provider<AppDirectories>(
  (ref) => throw StateError('the application directories were not bound'),
);

/// What kind of machine this is.
final hostPlatformProvider = Provider<HostPlatform>(
  (ref) => const HostPlatform(),
);

/// The clock, so that a test can pin what "now" is.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Where the ids of new things come from, so that a test can name them.
///
/// Random rather than counted: an id has to stay unique across runs and
/// devices, and no counter survives both. 128 bits as hexadecimal, from the
/// operating system's source.
final idGeneratorProvider = Provider<String Function()>((ref) {
  final random = Random.secure();
  return () => [
    for (var i = 0; i < 16; i++)
      random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ].join();
});

/// Where a shuffle gets its randomness.
///
/// A provider rather than a `Random()` built where it is used, for one reason:
/// a shuffle nobody can reproduce is a shuffle nobody can test. A test
/// overrides this with a seeded source and asserts the order, where otherwise
/// it could only assert that the same tracks came back.
final shuffleRandomProvider = Provider<Random>((ref) => Random());

/// Where the catalog document is kept.
final catalogStoreProvider = Provider<CatalogStore>(
  (ref) => JsonCatalogStore(ref.watch(appDirectoriesProvider).support),
);

/// Where cover pictures are cached.
final coverStoreProvider = Provider<CoverStore>(
  (ref) => FileCoverStore(ref.watch(appDirectoriesProvider).covers),
);

/// Where a track's words are looked for on this machine.
final lyricsSourceProvider = Provider<LyricsSource>(
  (ref) => const FileLyricsSource(),
);

/// Where they are looked for when this machine holds none.
///
/// The only binding in this graph that reaches a network. It is built on first
/// use and closed with the container, because it holds pooled connections —
/// and a second one would be a second pool for a feature that makes at most
/// one request per track.
///
/// Every test overrides it, as every test overrides the engine and the media
/// session: no test in this suite opens a socket.
final remoteLyricsSourceProvider = Provider<RemoteLyricsSource>((ref) {
  final source = LrclibLyricsSource(
    version: ref.watch(runningVersionProvider)?.toString(),
  );
  ref.onDispose(source.close);

  return source;
});

/// Where autofilled tags come from.
///
/// One instance for the run, because it holds the throttle MusicBrainz asks
/// for: two of them would each keep to one request a second, and together
/// make two. Every test overrides it.
final metadataSourceProvider = Provider<MetadataSource>((ref) {
  final source = MusicBrainzSource(
    version: ref.watch(runningVersionProvider)?.toString(),
  );
  ref.onDispose(source.close);

  return source;
});

/// What reads and writes a file's tags for an autofill.
///
/// The one binding in this graph that writes into an audio file. Every test
/// overrides it.
final tagWriterProvider = Provider<TagWriter>(
  (ref) => const AudioMetadataTagWriter(),
);

/// One autofill session, from search to written files.
///
/// Auto-disposed: it lives as long as the review screen watching it, so a
/// closed screen is a forgotten session.
final autofillControllerProvider =
    NotifierProvider<AutofillController, AutofillState>(
      AutofillController.new,
      isAutoDispose: true,
    );

/// One tag edit, from the file read to the edit written.
///
/// Auto-disposed: it lives as long as the dialog watching it, so a closed
/// dialog is a forgotten edit.
final tagEditControllerProvider =
    NotifierProvider<TagEditController, TagEditState>(
      TagEditController.new,
      isAutoDispose: true,
    );

/// Reads several tracks' tags, and writes what the owner changed in all of
/// them.
///
/// Auto-disposed, as [tagEditControllerProvider] is: a closed dialog is a
/// forgotten edit, but a save already confirmed is finished.
final manyTagEditControllerProvider =
    NotifierProvider<ManyTagEditController, ManyTagEditState>(
      ManyTagEditController.new,
      isAutoDispose: true,
    );

/// Where a fetched sheet is written, so it is found locally next time.
final lyricsSidecarProvider = Provider<LyricsSidecar>(
  (ref) => const FileLyricsSidecar(),
);

/// What builds the catalog from the owner's folders.
final libraryScannerProvider = Provider<LibraryScanner>(
  (ref) => const IsolateLibraryScanner(),
);

/// The platform's read-access gate.
final libraryAccessProvider = Provider<LibraryAccess>(
  (ref) => PermissionLibraryAccess(platform: ref.watch(hostPlatformProvider)),
);

/// The platform's folder chooser.
final folderPickerProvider = Provider<FolderPicker>(
  (ref) => const FilePickerFolderPicker(),
);

/// The platform's image chooser, for a cover picked by hand.
final coverPickerProvider = Provider<CoverPicker>(
  (ref) => const FilePickerCoverPicker(),
);

/// A file's size and time as the disk has them now, which a tag edit is
/// measured against.
final fileStampsProvider = Provider<FileStamps>(
  (ref) => const IoFileStamps(),
);

/// Whether a queued file is still there.
final trackProbeProvider = Provider<TrackProbe>(
  (ref) => const FileTrackProbe(),
);

/// The playback engine.
///
/// One for the application, built on first use and released with the
/// container: it holds a native player and an output device, and a second one
/// would be a second thing making noise.
final audioPlayerProvider = Provider<MediaPlayer>((ref) {
  final player = MediaKitPlayer();
  ref.onDispose(player.dispose);

  return player;
});

/// The platform's media session — the notification, the lock screen, and
/// whatever has transport buttons on it.
///
/// Silent by default, which is the honest answer on the two desktop targets
/// and the one every test wants. `main` overrides it on Android with the
/// session over the foreground service, because starting that service is
/// asynchronous and has to have happened before the first frame.
final mediaSessionProvider = Provider<MediaSession>((ref) {
  final session = SilentMediaSession();
  ref.onDispose(session.dispose);

  return session;
});

/// The resume points.
final playbackPositionsProvider = Provider<PlaybackPositionStore>(
  (ref) => SettingsPlaybackPositionStore(ref.watch(settingsStoreProvider)),
);

/// Where the play history is kept.
final playHistoryStoreProvider = Provider<PlayHistoryStore>(
  (ref) => JsonPlayHistoryStore(ref.watch(appDirectoriesProvider).support),
);

/// Where the playlists are kept.
final playlistStoreProvider = Provider<PlaylistStore>(
  (ref) => JsonPlaylistStore(ref.watch(appDirectoriesProvider).support),
);

/// Where the pictures chosen as playlist covers are kept.
final playlistCoverStoreProvider = Provider<PlaylistCoverStore>(
  (ref) => FilePlaylistCoverStore(ref.watch(appDirectoriesProvider).support),
);

/// The platform's save dialog, for a playlist exported to a file.
final fileSaverProvider = Provider<FileSaver>(
  (ref) => const FilePickerFileSaver(),
);

/// The playlists.
///
/// Not retried when the store cannot be read: that failure is a document that
/// could not be set aside, which asking again does not mend, and a retry would
/// only delay the error that every change must report.
final playlistsControllerProvider =
    AsyncNotifierProvider<PlaylistsController, List<Playlist>>(
      PlaylistsController.new,
      retry: (_, _) => null,
    );

/// Which playlist is open, or `null` for the list of them.
final playlistBrowseProvider =
    NotifierProvider<PlaylistBrowseController, String?>(
      PlaylistBrowseController.new,
    );

/// What counts a play, and what has been counted.
///
/// One for the application: the player writes to it and the statistics screen
/// reads from it, and a second one would be a screen showing a total the last
/// play is missing from.
final playRecorderProvider = Provider<PlayRecorder>(
  (ref) => PlayRecorder(
    store: ref.watch(playHistoryStoreProvider),
    clock: ref.watch(clockProvider),
  ),
);

/// The folders the library is built from.
final libraryFoldersControllerProvider =
    NotifierProvider<LibraryFoldersController, List<String>>(
      LibraryFoldersController.new,
    );

/// Whether the platform will let the application read those folders.
final libraryAccessControllerProvider =
    NotifierProvider<LibraryAccessController, LibraryAccessDecision?>(
      LibraryAccessController.new,
    );

/// Whether it may read a folder anywhere on the device — a memory card, or a
/// drive plugged into the phone.
final everyFolderAccessProvider =
    AsyncNotifierProvider<EveryFolderAccessController, bool>(
      EveryFolderAccessController.new,
    );

/// The library itself.
final musicLibraryControllerProvider =
    AsyncNotifierProvider<MusicLibraryController, MusicCatalog>(
      MusicLibraryController.new,
    );

/// The scan that keeps the library current.
final scanControllerProvider = NotifierProvider<ScanController, ScanState>(
  ScanController.new,
);

/// The player.
final audioPlaybackControllerProvider =
    NotifierProvider<AudioPlaybackController, AudioPlaybackState>(
      AudioPlaybackController.new,
    );

/// What the media session is showing, and what it sends back.
///
/// Not auto-disposed and never watched by a widget for its value: it is a view
/// of the player that outlives every screen, in the same way the player itself
/// does.
final mediaSessionControllerProvider =
    NotifierProvider<MediaSessionController, NowPlaying?>(
      MediaSessionController.new,
    );

/// What the owner listens to.
///
/// Auto-disposed, so the screen reads afresh each time it is opened rather
/// than showing what was true the first time it was opened this session.
final musicStatsControllerProvider =
    AsyncNotifierProvider<MusicStatsController, MusicStats>(
      MusicStatsController.new,
      isAutoDispose: true,
    );

/// Where in the music area the owner is.
final musicBrowseControllerProvider =
    NotifierProvider<MusicBrowseController, MusicBrowseState>(
      MusicBrowseController.new,
    );

/// Where in Genres the owner is, apart from where they are in Music.
final genreBrowseControllerProvider =
    NotifierProvider<GenreBrowseController, GenreBrowseState>(
      GenreBrowseController.new,
    );

/// Rows or tiles.
final musicLayoutControllerProvider =
    NotifierProvider<MusicLayoutController, MusicLayout>(
      MusicLayoutController.new,
    );

/// One record's sleeve, decoded, keyed by the picture's own id.
///
/// Auto-disposed, which a family is not by default: a library of a thousand
/// records scrolled past would otherwise hold a thousand decoded pictures for
/// the life of the container.
final albumArtControllerProvider =
    AsyncNotifierProvider.family<AlbumArtController, ui.Image?, String>(
      AlbumArtController.new,
      isAutoDispose: true,
    );

/// Where analysed spectra are cached.
final energyStoreProvider = Provider<EnergyStore>(
  (ref) => FileEnergyStore(ref.watch(appDirectoriesProvider).energy),
);

/// What measures a track's spectrum.
final trackAnalysisProvider = Provider<TrackAnalysis>(
  (ref) => MpvTrackAnalysis(
    scratchDirectory: ref.watch(appDirectoriesProvider).scratch,
  ),
);

/// One track's measured spectrum, or `null` while it is being measured.
final measuredTrackEnergyProvider =
    AsyncNotifierProvider.family<
      TrackEnergyController,
      MeasuredEnergy?,
      String
    >(TrackEnergyController.new, isAutoDispose: true);

/// What the sound bars are drawn from, by track path.
///
/// The measured spectrum of the recording wherever there is one, and the
/// stand-in wherever there is not — which is the second or so before the first
/// analysis of a track lands, and a file that could not be decoded. Composed
/// here rather than in the widget so that the screen asks for one thing and
/// this decides what it gets.
final trackEnergyProvider = Provider.family<TrackEnergy, String>(
  (ref, path) =>
      ref.watch(measuredTrackEnergyProvider(path)).value ??
      SynthesisedEnergy.forTrack(path),
  isAutoDispose: true,
);

/// One track's words, by track path.
///
/// Auto-disposed with the screen that asked, which is the player: a queue that
/// has moved on has no use for the words of what it moved on from.
final lyricsProvider =
    AsyncNotifierProvider.family<LyricsController, Lyrics?, String>(
      LyricsController.new,
      isAutoDispose: true,
    );

/// Whether the player is showing the words in place of the sleeve.
final lyricsVisibilityProvider =
    NotifierProvider<LyricsVisibilityController, bool>(
      LyricsVisibilityController.new,
    );

/// Which area the shell is showing.
final shellControllerProvider =
    NotifierProvider<ShellController, ShellDestination>(ShellController.new);

/// The songs the owner has picked in a list.
final songSelectionProvider =
    NotifierProvider<SongSelectionController, SongSelection>(
      SongSelectionController.new,
    );

/// What the owner has typed into the search field.
final searchTermProvider = NotifierProvider<SearchTermController, String>(
  SearchTermController.new,
);

/// What the search term is matched against.
final searchFieldProvider =
    NotifierProvider<SearchFieldController, SearchField>(
      SearchFieldController.new,
    );

/// The preferences.
final preferencesControllerProvider =
    NotifierProvider<PreferencesController, PreferencesState>(
      PreferencesController.new,
    );

/// A thin read over [preferencesControllerProvider], so the application root
/// rebuilds on a theme change and on nothing else.
final themeModeProvider = Provider<ThemeMode>(
  (ref) => ref.watch(preferencesControllerProvider).themeMode,
);

/// How a story card leaves the application.
///
/// A share sheet on a phone and a save dialog on a desktop, decided by the
/// implementation rather than by the screen. Overridden in every test: a suite
/// that opened a share sheet would be a suite nobody could run unattended.
final storyShareProvider = Provider<StoryShare>(
  (ref) => PlatformStoryShare(platform: ref.watch(hostPlatformProvider)),
);

/// Where the application looks to see whether it is out of date.
///
/// Built on first use and closed with the container, for the reason the lyrics
/// source is: it holds pooled connections, and it is asked once a launch.
///
/// Every test overrides it. This and the lyrics lookup are the only two things
/// here that reach a network, and no test in this suite opens a socket.
final releaseSourceProvider = Provider<ReleaseSource>((ref) {
  final source = GitHubReleaseSource();
  ref.onDispose(source.close);

  return source;
});

/// What fetches an update and starts it.
final updateInstallerProvider = Provider<UpdateInstaller>(
  (ref) => InstallerUpdate(platform: ref.watch(hostPlatformProvider)),
);

/// How the application closes itself when an installer is about to replace it.
final appShutdownProvider = Provider<AppShutdown>(
  (ref) => const WindowShutdown(),
);

/// The update check, and the offer it produces.
final updateControllerProvider =
    NotifierProvider<UpdateController, UpdateState>(UpdateController.new);

/// The chosen language, or `null` to follow the system.
final localeProvider = Provider<Locale?>(
  (ref) => ref.watch(preferencesControllerProvider).locale,
);
