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
  String failureFolderUnreadable(String path) {
    return 'This folder could not be read: $path';
  }

  @override
  String get failureCatalogUnavailable =>
      'The library could not be read from disk.';

  @override
  String get failurePermissionDenied =>
      'Orpheus needs permission to read your audio files.';

  @override
  String get failurePermissionDeniedPermanently =>
      'Permission to read audio files was refused. Grant it in the system settings.';

  @override
  String failureTrackUnplayable(String path) {
    return 'This file could not be played: $path';
  }

  @override
  String get failureUnexpected => 'Something went wrong.';
}
