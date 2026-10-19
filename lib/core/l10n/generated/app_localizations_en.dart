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
  String get destinationGenres => 'Genres';

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
  String get searchFieldAll => 'All';

  @override
  String get searchFieldSongs => 'Songs';

  @override
  String get searchFieldArtists => 'Artists';

  @override
  String get searchFieldAlbums => 'Albums';

  @override
  String get searchFieldGenres => 'Genres';

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
  String get genreUnknown => 'No genre';

  @override
  String get genrePlay => 'Play the genre';

  @override
  String get genreShuffle => 'Shuffle the genre';

  @override
  String genreRowSummary(String tracks, String length) {
    return '$tracks · $length';
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
  String scanReport(int tracks, int added, int updated, int removed) {
    return '$tracks tracks — $added new, $updated updated, $removed gone.';
  }

  @override
  String scanUnreadable(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files had tags that could not be read.',
      one: '1 file had tags that could not be read.',
      zero: 'No file had tags that could not be read.',
    );
    return '$_temp0';
  }

  @override
  String scanUnreachable(String path) {
    return 'This folder was not there: $path';
  }

  @override
  String get foldersEveryFolderTitle =>
      'Android will not hand this folder over';

  @override
  String get foldersEveryFolderBody =>
      'A memory card, or a drive plugged into the phone, is mounted outside the storage Android gives an application by default — so a folder on one reads as a folder that is not there. Reading it needs all-files access, which is granted in the system settings and can be taken back there at any time. Orpheus still reads only the folders you have registered, and still never writes to them.';

  @override
  String get foldersEveryFolderGrant => 'Allow all files';

  @override
  String get foldersEveryFolderGrantedTitle =>
      'Orpheus already reads every folder';

  @override
  String get foldersEveryFolderGrantedBody =>
      'All-files access is already granted, so a folder that still reads as one that is not there is one this run of Orpheus cannot see. Android settles what storage an application may reach at the moment it starts: a card or a drive mounted after that — or this permission granted after that — is outside the view this run was given. With the card or the drive plugged in, close Orpheus, open it again, and scan.';

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
          '$count played tracks carry no artist, record or genre tag, so they are counted in the totals above but appear in no artist, record or genre ranking below.',
      one: '1 played track carries no artist, record or genre tag, so it is counted in the totals above but appears in no artist, record or genre ranking below.',
      zero: 'Every played track carries an artist, record or genre tag, so each appears in an artist, record or genre ranking below.',
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

  @override
  String get statsStory => 'See it as a story';

  @override
  String get storyOpeningTitle => 'Your listening, so far';

  @override
  String storyOpeningPlays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count plays',
      one: '1 play',
    );
    return '$_temp0';
  }

  @override
  String storyOpeningTracks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tracks',
      one: '1 track',
    );
    return 'across $_temp0';
  }

  @override
  String get storyTopArtist => 'Your top artist';

  @override
  String get storyTopAlbum => 'Your top record';

  @override
  String get storyTopTrack => 'Your top track';

  @override
  String get storyTopGenre => 'Your top genre';

  @override
  String get storyRankingArtists => 'Your artists';

  @override
  String get storyRankingAlbums => 'Your records';

  @override
  String get storyRankingTracks => 'Your tracks';

  @override
  String get storyRankingGenres => 'Your genres';

  @override
  String storyShareOfPlays(String percent) {
    return '$percent% of what you played';
  }

  @override
  String get storySummaryTitle => 'That is your Orpheus';

  @override
  String get storyShare => 'Share';

  @override
  String get storySave => 'Save the picture';

  @override
  String get storyShared => 'Shared.';

  @override
  String get storySaved => 'Saved.';

  @override
  String get storyShareFailed => 'The picture could not be made.';

  @override
  String get storyClose => 'Close the story';

  @override
  String get storyNext => 'Next';

  @override
  String get storyPrevious => 'Previous';

  @override
  String get storyMadeWith => 'Made with Orpheus';

  @override
  String get autofillAction => 'Autofill tags…';

  @override
  String get autofillFieldsTitle => 'Fill which tags?';

  @override
  String get autofillFind => 'Find';

  @override
  String get autofillNothingWritable =>
      'Orpheus can only change the tags of MP3 and FLAC files.';

  @override
  String get autofillCoverNote =>
      'Downloads the cover from the Cover Art Archive and stores it in each file.';

  @override
  String get autofillFieldTitle => 'Title';

  @override
  String get autofillFieldArtist => 'Artist';

  @override
  String get autofillFieldAlbumArtist => 'Album artist';

  @override
  String get autofillFieldAlbum => 'Album';

  @override
  String get autofillFieldTrackNumber => 'Track number';

  @override
  String get autofillFieldTrackTotal => 'Track total';

  @override
  String get autofillFieldDiscNumber => 'Disc number';

  @override
  String get autofillFieldDiscTotal => 'Disc total';

  @override
  String get autofillFieldYear => 'Year';

  @override
  String get autofillFieldGenre => 'Genre';

  @override
  String get autofillFieldCover => 'Cover art';

  @override
  String get autofillSearching => 'Looking this up on MusicBrainz…';

  @override
  String get autofillUnreachable => 'MusicBrainz could not be reached.';

  @override
  String get autofillRateLimited =>
      'MusicBrainz is busy. Try again in a moment.';

  @override
  String get autofillTryAgain => 'Try again';

  @override
  String get autofillNothingFound => 'Nothing found on MusicBrainz.';

  @override
  String get autofillSearchLabel => 'Search MusicBrainz';

  @override
  String get autofillSearchAgain => 'Search again';

  @override
  String get autofillDifferentRelease => 'Different release';

  @override
  String autofillWrite(int changes, int files) {
    String _temp0 = intl.Intl.pluralLogic(
      changes,
      locale: localeName,
      other: '$changes changes',
      one: '1 change',
      zero: '0 changes',
    );
    String _temp1 = intl.Intl.pluralLogic(
      files,
      locale: localeName,
      other: '$files files',
      one: '1 file',
      zero: '0 files',
    );
    return 'Write $_temp0 to $_temp1';
  }

  @override
  String get autofillTickAll => 'Tick all';

  @override
  String get autofillUntickAll => 'Untick all';

  @override
  String get autofillNoChanges => 'Already matches';

  @override
  String get autofillNoMatch => 'No match on this release';

  @override
  String get autofillUnwritable => 'Orpheus can\'t change this kind of file';

  @override
  String get autofillUnsafeTags =>
      'Orpheus can\'t safely change this file\'s tags';

  @override
  String autofillNotWritableFields(String fields) {
    return 'This kind of file can\'t hold: $fields';
  }

  @override
  String get autofillCoverMissing =>
      'This release has no cover on the Cover Art Archive.';

  @override
  String get autofillCoverUnavailable =>
      'The cover could not be downloaded from the Cover Art Archive.';

  @override
  String autofillWriting(int done, int total) {
    return 'Writing $done of $total…';
  }

  @override
  String get autofillCancel => 'Cancel';

  @override
  String get autofillClose => 'Close';

  @override
  String autofillWritten(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files updated.',
      one: '1 file updated.',
      zero: 'No files were updated.',
    );
    return '$_temp0';
  }

  @override
  String get autofillOutcomeChanged =>
      'Changed since Orpheus read it — not written';

  @override
  String get autofillOutcomeInUse =>
      'In use by playback — try again once it has moved on';

  @override
  String get autofillOutcomeNotWritten => 'Not written — cancelled first';

  @override
  String get autofillOutcomeDenied => 'Orpheus isn\'t allowed to change it';

  @override
  String get autofillOutcomeFailed => 'Could not be written';

  @override
  String get autofillOutcomeUnsupported =>
      'Orpheus can\'t change this kind of file';

  @override
  String get autofillAccessRefused =>
      'Orpheus needs permission to change your music files. Nothing was written.';

  @override
  String get autofillOpenSettings => 'Open settings';

  @override
  String get tagEditAction => 'Edit tags…';

  @override
  String get tagEditTitle => 'Edit tags';

  @override
  String get tagEditSave => 'Save';

  @override
  String get tagEditChooseCover => 'Choose image…';

  @override
  String get tagEditRemoveCover => 'Remove';

  @override
  String get tagEditNoCover => 'No cover';

  @override
  String get tagEditCoverNotImage => 'Choose a JPEG or PNG image';

  @override
  String get tagEditWholeNumber => 'Enter a whole number';

  @override
  String get tagEditYearRange => 'Enter a year from 1 to 9999';

  @override
  String get tagEditNumberForTotal => 'Enter a number, or clear the total';

  @override
  String get tagEditReload => 'Reload';

  @override
  String get tagEditSaved => 'Tags saved';

  @override
  String tagEditManySubtitle(String label, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count songs',
      one: '1 song',
    );
    return '$label · $_temp0';
  }

  @override
  String tagEditManyReading(int done, int total) {
    return 'Reading $done of $total…';
  }

  @override
  String tagEditManySaving(int done, int total) {
    return 'Saving $done of $total…';
  }

  @override
  String get tagEditManyMixed => 'Mixed — leave blank to keep each song\'s own';

  @override
  String get tagEditManyMixedCovers => 'Different covers';

  @override
  String get tagEditManyOneAtATime =>
      'Title and track number are edited one song at a time.';

  @override
  String tagEditManySkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count songs can\'t be changed and will be left alone',
      one: '1 song can\'t be changed and will be left alone',
    );
    return '$_temp0';
  }

  @override
  String get tagEditManySkippedFormat => 'Not an MP3 or FLAC file';

  @override
  String get tagEditManySkippedUnsafe => 'Its tags can\'t be changed safely';

  @override
  String tagEditManyPartly(int written, int failed) {
    String _temp0 = intl.Intl.pluralLogic(
      written,
      locale: localeName,
      other: '$written songs',
      one: '1 song',
      zero: 'no songs',
    );
    String _temp1 = intl.Intl.pluralLogic(
      failed,
      locale: localeName,
      other: '$failed couldn\'t be changed:',
      one: '1 couldn\'t be changed:',
    );
    return 'Saved to $_temp0. $_temp1';
  }

  @override
  String tagEditManySaved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tags saved to $count songs',
      one: 'Tags saved to 1 song',
    );
    return '$_temp0';
  }

  @override
  String get tagEditManyTrackTotalLeft =>
      'Its track total was left as it was: it has no track number';

  @override
  String get tagEditManyDiscTotalLeft =>
      'Its disc total was left as it was: it has no disc number';

  @override
  String get musicGroupActions => 'More actions';

  @override
  String musicSelectionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selected',
      one: '1 selected',
    );
    return '$_temp0';
  }

  @override
  String get musicSelectionAll => 'Select all';

  @override
  String get musicSelectionStop => 'Stop selecting';

  @override
  String musicSelectionSelect(String title) {
    return 'Select $title';
  }

  @override
  String musicSelectionEditTags(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Edit tags of $count songs…',
      one: 'Edit tags of 1 song…',
    );
    return '$_temp0';
  }

  @override
  String get musicSelectionLabel => 'Selected songs';

  @override
  String get playlistTab => 'Playlists';

  @override
  String get playlistNew => 'New playlist';

  @override
  String get playlistNameLabel => 'Name';

  @override
  String get playlistNameRequired => 'Give the playlist a name';

  @override
  String get playlistCreate => 'Create';

  @override
  String playlistSongCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count songs',
      one: '1 song',
      zero: 'No songs',
    );
    return '$_temp0';
  }

  @override
  String get playlistEmpty => 'No playlists yet';

  @override
  String get playlistActions => 'Playlist actions';

  @override
  String get playlistBackToList => 'All playlists';

  @override
  String get playlistCoverLabel => 'Playlist cover';

  @override
  String get playlistRename => 'Rename…';

  @override
  String get playlistRenameTitle => 'Rename playlist';

  @override
  String get playlistRenameConfirm => 'Rename';

  @override
  String get playlistChooseCover => 'Choose cover…';

  @override
  String get playlistRemoveCover => 'Remove cover';

  @override
  String get playlistCoverNotImage =>
      'Choose a JPEG or PNG image for the cover';

  @override
  String get playlistExport => 'Export to .m3u…';

  @override
  String playlistExportSaved(String path) {
    return 'Saved to $path';
  }

  @override
  String get playlistExported => 'Playlist exported';

  @override
  String playlistExportFailed(String name) {
    return 'Couldn\'t export $name';
  }

  @override
  String get playlistDelete => 'Delete…';

  @override
  String playlistDeleteTitle(String name) {
    return 'Delete $name?';
  }

  @override
  String get playlistDeleteBody => 'The songs stay in your library.';

  @override
  String get playlistDeleteConfirm => 'Delete';

  @override
  String get playlistSaveFailed => 'Couldn\'t save the playlists';

  @override
  String get playlistShuffle => 'Shuffle';

  @override
  String playlistSummary(String songs, String length) {
    return '$songs · $length';
  }

  @override
  String get playlistNoSongs => 'No songs in this playlist yet';

  @override
  String get playlistMissing => 'Missing';

  @override
  String playlistMissingBy(String artist) {
    return 'Missing · $artist';
  }

  @override
  String get playlistRemoveFrom => 'Remove from playlist';

  @override
  String get playlistReorder => 'Drag to reorder';

  @override
  String get playlistAddTo => 'Add to playlist…';

  @override
  String get playlistAddToTitle => 'Add to playlist';

  @override
  String get playlistAddToNew => 'New playlist…';

  @override
  String playlistAdded(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Added $count songs to $name',
      one: 'Added 1 song to $name',
    );
    return '$_temp0';
  }

  @override
  String get playlistNothingAdded => 'Nothing added';

  @override
  String playlistDuplicateTitle(String name) {
    return 'Already in $name — add again?';
  }

  @override
  String get playlistAddAnyway => 'Add anyway';

  @override
  String get playlistSkipThose => 'Skip those';

  @override
  String get autoPlaylistSection => 'Auto playlists';

  @override
  String get autoPlaylistYours => 'Your playlists';

  @override
  String get autoPlaylistLately => 'Favourites lately';

  @override
  String get autoPlaylistAllTime => 'All-time favourites';

  @override
  String get autoPlaylistFallbackNote =>
      'Getting to know your recent listening';

  @override
  String get autoPlaylistLatelyEmpty =>
      'Play some music and your recent favourites will show here';

  @override
  String get autoPlaylistAllTimeEmpty =>
      'Play some music and your favourites will show here';

  @override
  String get autoPlaylistShow => 'Show auto playlists';

  @override
  String get autoPlaylistShowDetail =>
      'Favourites lately and All-time favourites, at the top of Playlists. Your plays are still counted while they are hidden.';

  @override
  String get dataExportHeading => 'Your data';

  @override
  String get dataExportAction => 'Export my data (JSON)…';

  @override
  String dataExportSaved(String path) {
    return 'Exported to $path';
  }

  @override
  String get dataExported => 'Exported';

  @override
  String get dataExportPartial => 'Exported, but some data could not be read';

  @override
  String get dataExportFailed => 'Couldn\'t export your data';

  @override
  String get dataExportLibraryFailed =>
      'Your library couldn\'t be read, so there\'s nothing to export';

  @override
  String get dataExportExplanation =>
      'For looking at your data in other tools, or importing it elsewhere.';

  @override
  String get backupAction => 'Back up Orpheus (ZIP)…';

  @override
  String get backupExplanation =>
      'For restoring Orpheus on this or another device: your data, playlist covers and preferences.';

  @override
  String backupSaved(String path) {
    return 'Backed up to $path';
  }

  @override
  String get backedUp => 'Backed up';

  @override
  String get backupPartial => 'Backed up, but some data could not be read';

  @override
  String get backupFailed => 'Couldn\'t back up Orpheus';

  @override
  String get backupLibraryFailed =>
      'Your library couldn\'t be read, so there\'s nothing to back up';

  @override
  String get backupAboutAction => 'About these exports';

  @override
  String get backupAboutTitle => 'About these exports';

  @override
  String get backupAboutColumnJson => 'Export my data (JSON)';

  @override
  String get backupAboutColumnZip => 'Back up Orpheus (ZIP)';

  @override
  String get backupAboutFor => 'For';

  @override
  String get backupAboutForJson =>
      'Looking at your data in other tools, importing elsewhere';

  @override
  String get backupAboutForZip => 'Restoring Orpheus on this or another device';

  @override
  String get backupAboutSongs => 'Songs, artists, albums (as a list)';

  @override
  String get backupAboutPlaylists => 'Playlists';

  @override
  String get backupAboutAutoPlaylists => 'Auto playlists (as they are now)';

  @override
  String get backupAboutHistory => 'Play history and statistics';

  @override
  String get backupAboutCovers => 'Playlist cover pictures';

  @override
  String get backupAboutPreferences => 'Preferences (incl. music folders)';

  @override
  String get backupAboutMusicFiles => 'Your music files';

  @override
  String get backupAboutIncluded => 'Included';

  @override
  String get backupAboutNotIncluded => 'Not included';

  @override
  String get restoreAction => 'Restore from a backup…';

  @override
  String get restoreExplanation =>
      'Bring back playlists, play history and preferences from a backup ZIP or an exported JSON.';

  @override
  String get restoreTitle => 'Restore from a backup';

  @override
  String get restoreFailedNotABackup => 'This isn\'t an Orpheus backup';

  @override
  String get restoreFailedNewer =>
      'This backup is from a newer Orpheus — update first';

  @override
  String get restoreFoldersTitle => 'Your music';

  @override
  String get restoreFoldersIntro =>
      'The songs in a backup are matched against your library, so your music needs to be where Orpheus looks for it.';

  @override
  String get restoreBackupFolders => 'Folders in the backup';

  @override
  String get restoreBackupFoldersNone =>
      'The backup doesn\'t name any folders.';

  @override
  String get restoreFolderFound => 'Found on this device';

  @override
  String get restoreFolderNotFound => 'Not found';

  @override
  String get restoreDeviceFolders => 'Music folders on this device';

  @override
  String get restoreDeviceFoldersNone => 'None yet';

  @override
  String get restoreFoldersStaged => 'Changes when you continue';

  @override
  String restoreRemoveFolder(String folder) {
    return 'Remove $folder';
  }

  @override
  String get restoreChooseFolders => 'Choose folders…';

  @override
  String get restoreFoldersNote =>
      'Continue changes your music folders now and scans your library. If you cancel later, the folders stay as you set them.';

  @override
  String get restoreContinue => 'Continue';

  @override
  String get restoreScanning => 'Scanning your music…';

  @override
  String get restoreChoicesTitle => 'What to restore';

  @override
  String restoreBackupFrom(String date) {
    return 'Backup from $date';
  }

  @override
  String get restoreBackupUndated => 'Backup';

  @override
  String restoreHoldsPlaylists(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count playlists',
      one: '1 playlist',
    );
    return '$_temp0';
  }

  @override
  String restoreHoldsSongs(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count songs with plays',
      one: '1 song with plays',
    );
    return '$_temp0';
  }

  @override
  String restoreHoldsCovers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count playlist covers',
      one: '1 playlist cover',
      zero: 'No playlist covers',
    );
    return '$_temp0';
  }

  @override
  String get restoreHoldsPreferences => 'Preferences included';

  @override
  String get restoreHoldsNoPreferences => 'No preferences';

  @override
  String get restorePartPlaylists => 'Playlists';

  @override
  String get restorePartHistory => 'Play history';

  @override
  String get restorePartPreferences => 'Preferences';

  @override
  String get restoreMerge => 'Merge';

  @override
  String get restoreSkip => 'Skip';

  @override
  String get restoreReplace => 'Replace';

  @override
  String get restorePlaylistsMerge =>
      'Adds the backup\'s playlists that aren\'t here, and the songs your same-named ones lack.';

  @override
  String get restorePlaylistsSkip =>
      'Adds only the backup\'s playlists whose name isn\'t here.';

  @override
  String get restorePlaylistsReplace =>
      'Removes your playlists and uses the backup\'s, covers included.';

  @override
  String get restoreHistoryMerge =>
      'Keeps the higher play count and the later date for each song, and adds the rest.';

  @override
  String get restoreHistorySkip => 'Adds only songs with no play history here.';

  @override
  String get restoreHistoryReplace =>
      'Replaces your play history with the backup\'s.';

  @override
  String get restorePreferencesMerge =>
      'Applies the backup\'s settings only where yours are still the default.';

  @override
  String get restorePreferencesSkip => 'Changes none of your settings.';

  @override
  String get restorePreferencesReplace =>
      'Applies all of the backup\'s settings, volume and language included.';

  @override
  String get restoreNotInBackup => 'Not in this backup';

  @override
  String get restoreNotInFile => 'Not in this file';

  @override
  String restoreReplacePlaylists(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Replaces your $count playlists',
      one: 'Replaces your 1 playlist',
      zero: 'You have no playlists to replace',
    );
    return '$_temp0';
  }

  @override
  String restoreReplaceHistory(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Replaces play counts for $count songs',
      one: 'Replaces play counts for 1 song',
      zero: 'You have no play counts to replace',
    );
    return '$_temp0';
  }

  @override
  String get restoreReplacePreferences =>
      'Replaces all your settings with the backup\'s';

  @override
  String get restoreUnreadablePlaylists =>
      'Your playlists couldn\'t be read here, so this part won\'t be restored.';

  @override
  String get restoreUnreadableHistory =>
      'Your play history couldn\'t be read here, so this part won\'t be restored.';

  @override
  String get restoreFoldersKept =>
      'Your music folders were changed in the last step. Cancelling keeps your music folders as they are now.';

  @override
  String get restoreRestore => 'Restore';

  @override
  String get restoreRestoring => 'Restoring…';

  @override
  String get restoreDoneTitle => 'Restore finished';

  @override
  String get restoreDoneRestored => 'Restored';

  @override
  String get restoreDoneRefused => 'Couldn\'t restore';

  @override
  String restoreDonePlaylists(int added, int merged) {
    return 'Playlists: $added added, $merged merged';
  }

  @override
  String restoreDonePlaylistsReplaced(int replaced, int added) {
    return 'Playlists: replaced your $replaced with $added from the backup';
  }

  @override
  String get restoreDonePlaylistsNothing => 'Playlists: nothing to add';

  @override
  String restoreDoneHistory(int songs) {
    String _temp0 = intl.Intl.pluralLogic(
      songs,
      locale: localeName,
      other: '$songs songs',
      one: '1 song',
    );
    return 'Play history for $_temp0';
  }

  @override
  String restoreDoneHistoryMissing(int songs, int missing) {
    String _temp0 = intl.Intl.pluralLogic(
      songs,
      locale: localeName,
      other: '$songs songs',
      one: '1 song',
    );
    return 'Play history for $_temp0 ($missing not in your library)';
  }

  @override
  String get restoreDoneHistoryNothing => 'Play history: no songs to add';

  @override
  String get restoreDonePreferences => 'Preferences applied';

  @override
  String get restoreDonePreferencesNone => 'Preferences: nothing to change';

  @override
  String get restoreDonePreferencesUnsaved =>
      'Some preferences couldn\'t be saved and last only until Orpheus closes';

  @override
  String restoreDoneCoverFailures(String names) {
    return 'These playlists are back, but their cover pictures couldn\'t be saved: $names';
  }

  @override
  String restoreRefusedLine(String part, String reason) {
    return '$part: $reason';
  }

  @override
  String get restoreReasonNotInBackup =>
      'the backup couldn\'t read this part when it was made';

  @override
  String get restoreReasonNotInFile => 'this file doesn\'t have this part';

  @override
  String get restoreReasonUnreadableHere =>
      'this part couldn\'t be read here, so it was left alone';

  @override
  String get restoreReasonNotWritten =>
      'this part couldn\'t be saved, so nothing of it changed';
}
