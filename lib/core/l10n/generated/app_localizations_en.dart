// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Orpheus';

  @override
  String get loading => 'Loading';

  @override
  String get retry => 'Try again';

  @override
  String get close => 'Close';

  @override
  String get cancel => 'Cancel';

  @override
  String get dismiss => 'Dismiss';

  @override
  String get remove => 'Remove';

  @override
  String get done => 'Done';

  @override
  String get openSettings => 'Open settings';

  @override
  String get destinationMusic => 'Music';

  @override
  String get destinationQueue => 'Queue';

  @override
  String get destinationFolders => 'Folders';

  @override
  String get searchHint => 'Search the library';

  @override
  String get searchClear => 'Clear the search';

  @override
  String searchResults(String term) {
    return 'Results for “$term”';
  }

  @override
  String searchEmpty(String term) {
    return 'Nothing in the library matches “$term”.';
  }

  @override
  String get settingsTitle => 'Preferences';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get themeSystem => 'Follow the system';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get languageSystem => 'Follow the system';

  @override
  String get languageEnglish => 'English';

  @override
  String get languagePortuguese => 'Português (Brasil)';

  @override
  String get settingsPlayback => 'Playback';

  @override
  String get settingsOpensPlayerOnPlay => 'Open the player when a track starts';

  @override
  String get settingsRescansAtStartup => 'Re-scan the library at every launch';

  @override
  String get settingsLyrics => 'Lyrics';

  @override
  String get settingsFetchesLyricsOnline => 'Look up missing lyrics online';

  @override
  String get settingsFetchesLyricsOnlineDetail =>
      'For a track this machine has no lyrics for, Orpheus sends its artist and title to lrclib.net and saves what comes back as an .lrc file beside the track. This is the only thing Orpheus sends anywhere.';

  @override
  String get settingsVolume => 'Volume';

  @override
  String get settingsUnsaved =>
      'This applies now, but could not be saved for next time.';

  @override
  String get musicViewArtists => 'Artists';

  @override
  String get musicViewAlbums => 'Albums';

  @override
  String get musicViewSongs => 'Songs';

  @override
  String get musicBreadcrumbRoot => 'Library';

  @override
  String get musicUnknownArtist => 'Unknown artist';

  @override
  String get musicUnknownAlbum => 'Unknown album';

  @override
  String get musicUnknownTitle => 'Untitled';

  @override
  String get musicEmpty => 'Your library is empty.';

  @override
  String get musicEmptyHint =>
      'Add the folder your music is in, and Orpheus will read it.';

  @override
  String get musicRowActions => 'Actions for this track';

  @override
  String get layoutList => 'List';

  @override
  String get layoutGrid => 'Grid';

  @override
  String musicTrackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tracks',
      one: '1 track',
      zero: 'No tracks',
    );
    return '$_temp0';
  }

  @override
  String get playbackNothingPlaying => 'Nothing is playing';

  @override
  String get playbackBarLabel => 'Playback';

  @override
  String get audioPlay => 'Play';

  @override
  String get audioPause => 'Pause';

  @override
  String get audioStop => 'Stop';

  @override
  String get audioNext => 'Next track';

  @override
  String get audioPrevious => 'Previous track';

  @override
  String get audioPlayAlbum => 'Play the album';

  @override
  String get audioPlayArtist => 'Play the artist';

  @override
  String get audioShuffleAlbum => 'Shuffle the album';

  @override
  String get audioShuffleArtist => 'Shuffle the artist';

  @override
  String get audioShuffleAll => 'Shuffle everything';

  @override
  String get audioShuffleAllLabel => 'Everything, shuffled';

  @override
  String get audioOpenPlayer => 'Open the player';

  @override
  String get audioClosePlayer => 'Close the player';

  @override
  String audioSkipped(String title) {
    return 'Skipped “$title” — it could not be played.';
  }

  @override
  String get audioNothingPlayable =>
      'Nothing in that selection could be played.';

  @override
  String audioResumePrompt(String position) {
    return 'Continue from $position?';
  }

  @override
  String get audioResume => 'Continue';

  @override
  String get audioStartOver => 'Start over';

  @override
  String get audioSoundBarsLabel => 'Sound bars';

  @override
  String get lyricsShow => 'Show the lyrics';

  @override
  String get lyricsHide => 'Hide the lyrics';

  @override
  String get lyricsLabel => 'Lyrics';

  @override
  String get lyricsNone => 'No lyrics for this track';

  @override
  String get lyricsWhereTheyComeFrom =>
      'Orpheus reads them from an .lrc file beside the track, or from the track\'s own tags. Where there are none and the online lookup is on, it asks a lyrics service for them.';

  @override
  String get lyricsNotSynced =>
      'These lyrics carry no times, so they do not follow the music.';

  @override
  String get albumCoverLabel => 'Album cover';

  @override
  String get audioRepeatOff => 'Repeat is off';

  @override
  String get audioRepeatAll => 'Repeat the queue';

  @override
  String get audioRepeatOne => 'Repeat this track';

  @override
  String get audioVolume => 'Volume';

  @override
  String get queueEmpty => 'Nothing is queued.';

  @override
  String get queueNowPlaying => 'Playing now';

  @override
  String queuePosition(int index, int total) {
    return '$index of $total';
  }

  @override
  String get foldersTitle => 'Library folders';

  @override
  String get foldersDescription =>
      'Orpheus reads the audio files under these folders. It never moves, changes or deletes them.';

  @override
  String get foldersEmpty => 'No folders yet.';

  @override
  String get foldersAdd => 'Add a folder';

  @override
  String get foldersAddDefault => 'Add my music folder';

  @override
  String get foldersRemove => 'Remove this folder';

  @override
  String get foldersRemoveTitle => 'Remove this folder?';

  @override
  String get foldersRemoveBody =>
      'Its tracks leave the library at the next scan. Nothing on disk is touched.';

  @override
  String get scanNow => 'Scan now';

  @override
  String scanWalking(int count) {
    return 'Looking for music… $count files found';
  }

  @override
  String scanReading(int read, int total) {
    return 'Reading $read of $total';
  }

  @override
  String get scanNever => 'This library has never been scanned.';

  @override
  String scanLastAt(String when) {
    return 'Last scanned $when.';
  }

  @override
  String scanReport(int tracks, int added, int removed) {
    return '$tracks tracks — $added new, $removed gone.';
  }

  @override
  String scanUnreadable(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files had tags that could not be read.',
      one: '1 file had tags that could not be read.',
    );
    return '$_temp0';
  }

  @override
  String scanUnreachable(String path) {
    return 'This folder was not there: $path';
  }

  @override
  String scanTracksFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tracks',
      one: '1 track',
      zero: 'No tracks',
    );
    return '$_temp0 in the library.';
  }

  @override
  String get failureCatalogUnavailable =>
      'The library could not be saved. This scan will have to run again next time Orpheus starts.';

  @override
  String get failurePermissionDenied =>
      'Orpheus needs permission to read your audio files.';

  @override
  String get failurePermissionDeniedPermanently =>
      'Permission to read audio files was refused. Grant it in the system settings.';

  @override
  String get failureUnexpected => 'Something went wrong.';

  @override
  String get statsTitle => 'What you listen to';

  @override
  String get statsOpen => 'Statistics';

  @override
  String get statsReadAgain => 'Read again';

  @override
  String get statsTotalPlays => 'Plays';

  @override
  String get statsDistinctTracks => 'Tracks';

  @override
  String get statsTopTracks => 'Most played tracks';

  @override
  String get statsTopArtists => 'Most played artists';

  @override
  String get statsTopAlbums => 'Most played records';

  @override
  String get statsTopGenres => 'Most played genres';

  @override
  String get statsRankingEmpty => 'Nothing here yet';

  @override
  String get statsEmptyTitle => 'Nothing counted yet';

  @override
  String get statsEmptyBody =>
      'A track counts once you have heard half of it, or four minutes of it — whichever comes first.';

  @override
  String statsPlaysCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count plays',
      one: '1 play',
    );
    return '$_temp0';
  }

  @override
  String statsUntaggedNote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count played tracks carry no artist, record or genre tag, so they are counted in the totals above but appear in no ranking below.',
      one: '1 played track carries no artist, record or genre tag, so it is counted in the totals above but appears in no ranking below.',
    );
    return '$_temp0';
  }

  @override
  String get settingsUpdates => 'Updates';

  @override
  String get settingsChecksForUpdatesOnStartup =>
      'Check for updates when Orpheus starts';

  @override
  String get settingsChecksForUpdatesOnStartupDetail =>
      'Asks GitHub once per launch whether a newer release exists. Nothing else is sent, and an update is only ever downloaded after you say so.';

  @override
  String updateAvailableTitle(String version) {
    return 'Orpheus $version is available';
  }

  @override
  String updateCurrentVersion(String version) {
    return 'You have $version.';
  }

  @override
  String get updateNow => 'Update now';

  @override
  String get updateLater => 'Not now';

  @override
  String get updateSkip => 'Skip this version';

  @override
  String get updateDownloading => 'Downloading…';

  @override
  String get updateVerifying => 'Checking what was downloaded…';

  @override
  String get updateHandedOff =>
      'Orpheus is closing so the installer can replace it.';

  @override
  String get updateNeedsCommandTitle => 'Almost there';

  @override
  String get updateNeedsCommandBody =>
      'Orpheus is installed for everyone on this machine, which needs administrator rights to replace. The update is downloaded and checked; run this in a terminal to finish it:';

  @override
  String get updateCopyCommand => 'Copy';

  @override
  String get updateCommandCopied => 'Copied.';

  @override
  String get updateFailedNoPackage =>
      'This release has no package for your system.';

  @override
  String get updateFailedDownload =>
      'The update could not be downloaded. Your connection may have dropped.';

  @override
  String get updateFailedChecksum =>
      'What was downloaded is not what the release published, so it was not run. Try again, or download it from the release page yourself.';

  @override
  String get updateFailedLaunch =>
      'The installer was downloaded but would not start.';

  @override
  String get updateRetry => 'Try again';

  @override
  String get updateClose => 'Close';

  @override
  String get updateReleaseNotes => 'What changed';
}
