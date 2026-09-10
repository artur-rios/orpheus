import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('pt'),
  ];

  /// The application's name, shown as the window title.
  ///
  /// In en, this message translates to:
  /// **'Orpheus'**
  String get appTitle;

  /// Announced while an operation runs.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get loading;

  /// The button on a failure state.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get retry;

  /// Dismisses a screen or a dialog.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// Abandons a dialog without doing anything.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Clears a notice the owner has read.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get dismiss;

  /// Takes an entry out of a list.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// Closes a dialog that has nothing to confirm.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// Opens the system settings, where a refused permission can be granted.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get openSettings;

  /// The library area, in the navigation panel.
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get destinationMusic;

  /// The play queue area, in the navigation panel.
  ///
  /// In en, this message translates to:
  /// **'Queue'**
  String get destinationQueue;

  /// The library folders area, in the navigation panel.
  ///
  /// In en, this message translates to:
  /// **'Folders'**
  String get destinationFolders;

  /// The placeholder in the search field.
  ///
  /// In en, this message translates to:
  /// **'Search the library'**
  String get searchHint;

  /// The button that empties the search field.
  ///
  /// In en, this message translates to:
  /// **'Clear the search'**
  String get searchClear;

  /// The heading above the search results.
  ///
  /// In en, this message translates to:
  /// **'Results for “{term}”'**
  String searchResults(String term);

  /// Shown when a search matched no track.
  ///
  /// In en, this message translates to:
  /// **'Nothing in the library matches “{term}”.'**
  String searchEmpty(String term);

  /// The title of the preferences dialog.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get settingsTitle;

  /// The heading over the theme and language choices.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// The label on the theme choice.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsTheme;

  /// The theme choice that follows the operating system.
  ///
  /// In en, this message translates to:
  /// **'Follow the system'**
  String get themeSystem;

  /// The light theme.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// The dark theme.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// The label on the language choice.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// The language choice that follows the operating system.
  ///
  /// In en, this message translates to:
  /// **'Follow the system'**
  String get languageSystem;

  /// The English language choice.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// The Brazilian Portuguese language choice.
  ///
  /// In en, this message translates to:
  /// **'Português (Brasil)'**
  String get languagePortuguese;

  /// The heading over the playback preferences.
  ///
  /// In en, this message translates to:
  /// **'Playback'**
  String get settingsPlayback;

  /// The preference that opens the full player on play.
  ///
  /// In en, this message translates to:
  /// **'Open the player when a track starts'**
  String get settingsOpensPlayerOnPlay;

  /// The preference that scans the folders at startup.
  ///
  /// In en, this message translates to:
  /// **'Re-scan the library at every launch'**
  String get settingsRescansAtStartup;

  /// The heading over the lyrics preferences.
  ///
  /// In en, this message translates to:
  /// **'Lyrics'**
  String get settingsLyrics;

  /// The preference that allows the online lyrics lookup.
  ///
  /// In en, this message translates to:
  /// **'Look up missing lyrics online'**
  String get settingsFetchesLyricsOnline;

  /// Says exactly what the online lyrics lookup sends and writes.
  ///
  /// In en, this message translates to:
  /// **'For a track this machine has no lyrics for, Orpheus sends its artist and title to lrclib.net and saves what comes back as an .lrc file beside the track. This is the only thing Orpheus sends anywhere.'**
  String get settingsFetchesLyricsOnlineDetail;

  /// The label on the volume slider.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get settingsVolume;

  /// Shown when a preference could not be written.
  ///
  /// In en, this message translates to:
  /// **'This applies now, but could not be saved for next time.'**
  String get settingsUnsaved;

  /// The artists view.
  ///
  /// In en, this message translates to:
  /// **'Artists'**
  String get musicViewArtists;

  /// The albums view.
  ///
  /// In en, this message translates to:
  /// **'Albums'**
  String get musicViewAlbums;

  /// The songs view.
  ///
  /// In en, this message translates to:
  /// **'Songs'**
  String get musicViewSongs;

  /// The first crumb, which returns to the top of the current view.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get musicBreadcrumbRoot;

  /// What an artist with no tag is called.
  ///
  /// In en, this message translates to:
  /// **'Unknown artist'**
  String get musicUnknownArtist;

  /// What an album with no tag is called.
  ///
  /// In en, this message translates to:
  /// **'Unknown album'**
  String get musicUnknownAlbum;

  /// What a track with no title tag is called.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get musicUnknownTitle;

  /// Shown when nothing has been scanned.
  ///
  /// In en, this message translates to:
  /// **'Your library is empty.'**
  String get musicEmpty;

  /// The sentence under the empty library state.
  ///
  /// In en, this message translates to:
  /// **'Add the folder your music is in, and Orpheus will read it.'**
  String get musicEmptyHint;

  /// The tooltip on a track row's menu button.
  ///
  /// In en, this message translates to:
  /// **'Actions for this track'**
  String get musicRowActions;

  /// The list layout.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get layoutList;

  /// The grid layout.
  ///
  /// In en, this message translates to:
  /// **'Grid'**
  String get layoutGrid;

  /// How many tracks a group holds.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No tracks} =1{1 track} other{{count} tracks}}'**
  String musicTrackCount(int count);

  /// Shown in the bar and the player when the queue is empty.
  ///
  /// In en, this message translates to:
  /// **'Nothing is playing'**
  String get playbackNothingPlaying;

  /// The accessible name of the playback bar.
  ///
  /// In en, this message translates to:
  /// **'Playback'**
  String get playbackBarLabel;

  /// Starts or resumes playback.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get audioPlay;

  /// Pauses playback.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get audioPause;

  /// Stops playback and clears the queue.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get audioStop;

  /// Moves to the next track in the queue.
  ///
  /// In en, this message translates to:
  /// **'Next track'**
  String get audioNext;

  /// Moves to the previous track, or restarts this one.
  ///
  /// In en, this message translates to:
  /// **'Previous track'**
  String get audioPrevious;

  /// Queues the whole record the track belongs to.
  ///
  /// In en, this message translates to:
  /// **'Play the album'**
  String get audioPlayAlbum;

  /// Queues everything by the record's artist.
  ///
  /// In en, this message translates to:
  /// **'Play the artist'**
  String get audioPlayArtist;

  /// Queues the record in an order nobody chose.
  ///
  /// In en, this message translates to:
  /// **'Shuffle the album'**
  String get audioShuffleAlbum;

  /// Queues the artist's tracks in an order nobody chose.
  ///
  /// In en, this message translates to:
  /// **'Shuffle the artist'**
  String get audioShuffleArtist;

  /// Queues the whole library in an order nobody chose.
  ///
  /// In en, this message translates to:
  /// **'Shuffle everything'**
  String get audioShuffleAll;

  /// What the bar calls the shuffle-everything queue.
  ///
  /// In en, this message translates to:
  /// **'Everything, shuffled'**
  String get audioShuffleAllLabel;

  /// Opens the full-window player.
  ///
  /// In en, this message translates to:
  /// **'Open the player'**
  String get audioOpenPlayer;

  /// Closes the full-window player.
  ///
  /// In en, this message translates to:
  /// **'Close the player'**
  String get audioClosePlayer;

  /// Names a track the queue stepped over.
  ///
  /// In en, this message translates to:
  /// **'Skipped “{title}” — it could not be played.'**
  String audioSkipped(String title);

  /// Shown when every queued track failed.
  ///
  /// In en, this message translates to:
  /// **'Nothing in that selection could be played.'**
  String get audioNothingPlayable;

  /// Offers to resume a track where it stopped.
  ///
  /// In en, this message translates to:
  /// **'Continue from {position}?'**
  String audioResumePrompt(String position);

  /// Resumes a track where it stopped.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get audioResume;

  /// Plays a track from the beginning.
  ///
  /// In en, this message translates to:
  /// **'Start over'**
  String get audioStartOver;

  /// The accessible name of the visualiser.
  ///
  /// In en, this message translates to:
  /// **'Sound bars'**
  String get audioSoundBarsLabel;

  /// The player button that puts the words in place of the sleeve.
  ///
  /// In en, this message translates to:
  /// **'Show the lyrics'**
  String get lyricsShow;

  /// The player button that puts the sleeve back.
  ///
  /// In en, this message translates to:
  /// **'Hide the lyrics'**
  String get lyricsHide;

  /// The accessible name of the lyrics panel.
  ///
  /// In en, this message translates to:
  /// **'Lyrics'**
  String get lyricsLabel;

  /// Shown where the machine holds no words for what is playing.
  ///
  /// In en, this message translates to:
  /// **'No lyrics for this track'**
  String get lyricsNone;

  /// Explains, under the no-lyrics message, where words come from.
  ///
  /// In en, this message translates to:
  /// **'Orpheus reads them from an .lrc file beside the track, or from the track\'s own tags. Where there are none and the online lookup is on, it asks a lyrics service for them.'**
  String get lyricsWhereTheyComeFrom;

  /// Shown above words that are a plain sheet rather than a timed one.
  ///
  /// In en, this message translates to:
  /// **'These lyrics carry no times, so they do not follow the music.'**
  String get lyricsNotSynced;

  /// The accessible name of a record's sleeve.
  ///
  /// In en, this message translates to:
  /// **'Album cover'**
  String get albumCoverLabel;

  /// The repeat button when nothing repeats.
  ///
  /// In en, this message translates to:
  /// **'Repeat is off'**
  String get audioRepeatOff;

  /// The repeat button when the queue repeats.
  ///
  /// In en, this message translates to:
  /// **'Repeat the queue'**
  String get audioRepeatAll;

  /// The repeat button when one track repeats.
  ///
  /// In en, this message translates to:
  /// **'Repeat this track'**
  String get audioRepeatOne;

  /// The tooltip on the volume control.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get audioVolume;

  /// Shown when the queue area has no tracks.
  ///
  /// In en, this message translates to:
  /// **'Nothing is queued.'**
  String get queueEmpty;

  /// Marks the track the queue is on.
  ///
  /// In en, this message translates to:
  /// **'Playing now'**
  String get queueNowPlaying;

  /// Where in the queue playback is.
  ///
  /// In en, this message translates to:
  /// **'{index} of {total}'**
  String queuePosition(int index, int total);

  /// The heading of the folders area.
  ///
  /// In en, this message translates to:
  /// **'Library folders'**
  String get foldersTitle;

  /// The sentence explaining what the folders are for.
  ///
  /// In en, this message translates to:
  /// **'Orpheus reads the audio files under these folders. It never moves, changes or deletes them.'**
  String get foldersDescription;

  /// Shown when no folder is registered.
  ///
  /// In en, this message translates to:
  /// **'No folders yet.'**
  String get foldersEmpty;

  /// Opens the folder chooser.
  ///
  /// In en, this message translates to:
  /// **'Add a folder'**
  String get foldersAdd;

  /// Adds the platform's conventional music folder.
  ///
  /// In en, this message translates to:
  /// **'Add my music folder'**
  String get foldersAddDefault;

  /// Takes a folder out of the library.
  ///
  /// In en, this message translates to:
  /// **'Remove this folder'**
  String get foldersRemove;

  /// The title of the confirmation asked before a folder is removed.
  ///
  /// In en, this message translates to:
  /// **'Remove this folder?'**
  String get foldersRemoveTitle;

  /// The body of that confirmation.
  ///
  /// In en, this message translates to:
  /// **'Its tracks leave the library at the next scan. Nothing on disk is touched.'**
  String get foldersRemoveBody;

  /// Starts a scan of every registered folder.
  ///
  /// In en, this message translates to:
  /// **'Scan now'**
  String get scanNow;

  /// Shown while the scan is still walking the folders.
  ///
  /// In en, this message translates to:
  /// **'Looking for music… {count} files found'**
  String scanWalking(int count);

  /// Shown while the scan reads tags.
  ///
  /// In en, this message translates to:
  /// **'Reading {read} of {total}'**
  String scanReading(int read, int total);

  /// Shown when no scan has run.
  ///
  /// In en, this message translates to:
  /// **'This library has never been scanned.'**
  String get scanNever;

  /// When the last scan ran.
  ///
  /// In en, this message translates to:
  /// **'Last scanned {when}.'**
  String scanLastAt(String when);

  /// What the last scan changed.
  ///
  /// In en, this message translates to:
  /// **'{tracks} tracks — {added} new, {removed} gone.'**
  String scanReport(int tracks, int added, int removed);

  /// How many files were listed but not understood.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 file had tags that could not be read.} other{{count} files had tags that could not be read.}}'**
  String scanUnreadable(int count);

  /// Names a registered folder the scan could not walk.
  ///
  /// In en, this message translates to:
  /// **'This folder was not there: {path}'**
  String scanUnreachable(String path);

  /// Heading of the offer shown when a registered folder could not be read because it is on removable storage.
  ///
  /// In en, this message translates to:
  /// **'Android will not hand this folder over'**
  String get foldersEveryFolderTitle;

  /// Explains why a folder on removable storage could not be read, and what granting all-files access does and does not allow.
  ///
  /// In en, this message translates to:
  /// **'A memory card, or a drive plugged into the phone, is mounted outside the storage Android gives an application by default — so a folder on one reads as a folder that is not there. Reading it needs all-files access, which is granted in the system settings and can be taken back there at any time. Orpheus still reads only the folders you have registered, and still never writes to them.'**
  String get foldersEveryFolderBody;

  /// Opens the system screen where all-files access is granted.
  ///
  /// In en, this message translates to:
  /// **'Allow all files'**
  String get foldersEveryFolderGrant;

  /// Heading shown when a folder is still unreachable although all-files access has already been granted.
  ///
  /// In en, this message translates to:
  /// **'Orpheus already reads every folder'**
  String get foldersEveryFolderGrantedTitle;

  /// Explains that a removable volume mounted, or the permission granted, after the application started is only picked up on the next launch.
  ///
  /// In en, this message translates to:
  /// **'All-files access is already granted, so a folder that still reads as one that is not there is one this run of Orpheus cannot see. Android settles what storage an application may reach at the moment it starts: a card or a drive mounted after that — or this permission granted after that — is outside the view this run was given. With the card or the drive plugged in, close Orpheus, open it again, and scan.'**
  String get foldersEveryFolderGrantedBody;

  /// How large the library is.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No tracks} =1{1 track} other{{count} tracks}} in the library.'**
  String scanTracksFound(int count);

  /// The catalog document could not be written.
  ///
  /// In en, this message translates to:
  /// **'The library could not be saved. This scan will have to run again next time Orpheus starts.'**
  String get failureCatalogUnavailable;

  /// The owner refused the storage permission.
  ///
  /// In en, this message translates to:
  /// **'Orpheus needs permission to read your audio files.'**
  String get failurePermissionDenied;

  /// The owner refused it permanently.
  ///
  /// In en, this message translates to:
  /// **'Permission to read audio files was refused. Grant it in the system settings.'**
  String get failurePermissionDeniedPermanently;

  /// Anything the application did not model.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong.'**
  String get failureUnexpected;

  /// The title of the listening statistics screen.
  ///
  /// In en, this message translates to:
  /// **'What you listen to'**
  String get statsTitle;

  /// The app bar button that opens the listening statistics.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get statsOpen;

  /// Reads the statistics from scratch.
  ///
  /// In en, this message translates to:
  /// **'Read again'**
  String get statsReadAgain;

  /// Label for the total number of plays counted.
  ///
  /// In en, this message translates to:
  /// **'Plays'**
  String get statsTotalPlays;

  /// Label for how many different tracks have been played.
  ///
  /// In en, this message translates to:
  /// **'Tracks'**
  String get statsDistinctTracks;

  /// Heading of the track ranking.
  ///
  /// In en, this message translates to:
  /// **'Most played tracks'**
  String get statsTopTracks;

  /// Heading of the artist ranking.
  ///
  /// In en, this message translates to:
  /// **'Most played artists'**
  String get statsTopArtists;

  /// Heading of the record ranking.
  ///
  /// In en, this message translates to:
  /// **'Most played records'**
  String get statsTopAlbums;

  /// Heading of the genre ranking.
  ///
  /// In en, this message translates to:
  /// **'Most played genres'**
  String get statsTopGenres;

  /// Shown under a ranking heading that has no rows.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get statsRankingEmpty;

  /// Title of the statistics screen before anything has been played.
  ///
  /// In en, this message translates to:
  /// **'Nothing counted yet'**
  String get statsEmptyTitle;

  /// Explains what has to happen before a statistic appears.
  ///
  /// In en, this message translates to:
  /// **'A track counts once you have heard half of it, or four minutes of it — whichever comes first.'**
  String get statsEmptyBody;

  /// How many plays one row of a ranking accounts for.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 play} other{{count} plays}}'**
  String statsPlaysCount(int count);

  /// Explains why the totals can be larger than the rankings.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 played track carries no artist, record or genre tag, so it is counted in the totals above but appears in no ranking below.} other{{count} played tracks carry no artist, record or genre tag, so they are counted in the totals above but appear in no ranking below.}}'**
  String statsUntaggedNote(int count);

  /// The updates section of the preferences.
  ///
  /// In en, this message translates to:
  /// **'Updates'**
  String get settingsUpdates;

  /// The switch for the startup update check.
  ///
  /// In en, this message translates to:
  /// **'Check for updates when Orpheus starts'**
  String get settingsChecksForUpdatesOnStartup;

  /// What the startup update check actually does.
  ///
  /// In en, this message translates to:
  /// **'Asks GitHub once per launch whether a newer release exists. Nothing else is sent, and an update is only ever downloaded after you say so.'**
  String get settingsChecksForUpdatesOnStartupDetail;

  /// The title of the update prompt.
  ///
  /// In en, this message translates to:
  /// **'Orpheus {version} is available'**
  String updateAvailableTitle(String version);

  /// Which version is running.
  ///
  /// In en, this message translates to:
  /// **'You have {version}.'**
  String updateCurrentVersion(String version);

  /// The button that starts the update.
  ///
  /// In en, this message translates to:
  /// **'Update now'**
  String get updateNow;

  /// The button that closes the prompt for this launch.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get updateLater;

  /// The button that stops this version being offered again.
  ///
  /// In en, this message translates to:
  /// **'Skip this version'**
  String get updateSkip;

  /// Shown while the package is being fetched.
  ///
  /// In en, this message translates to:
  /// **'Downloading…'**
  String get updateDownloading;

  /// Shown while the package's checksum is being compared.
  ///
  /// In en, this message translates to:
  /// **'Checking what was downloaded…'**
  String get updateVerifying;

  /// Shown once the installer has been started.
  ///
  /// In en, this message translates to:
  /// **'Orpheus is closing so the installer can replace it.'**
  String get updateHandedOff;

  /// The heading shown when the update needs a command run by hand.
  ///
  /// In en, this message translates to:
  /// **'Almost there'**
  String get updateNeedsCommandTitle;

  /// Why a system-wide Linux install cannot be updated from inside the application.
  ///
  /// In en, this message translates to:
  /// **'Orpheus is installed for everyone on this machine, which needs administrator rights to replace. The update is downloaded and checked; run this in a terminal to finish it:'**
  String get updateNeedsCommandBody;

  /// Copies the command to the clipboard.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get updateCopyCommand;

  /// Confirms the command was copied.
  ///
  /// In en, this message translates to:
  /// **'Copied.'**
  String get updateCommandCopied;

  /// No asset matches this platform.
  ///
  /// In en, this message translates to:
  /// **'This release has no package for your system.'**
  String get updateFailedNoPackage;

  /// The download did not finish.
  ///
  /// In en, this message translates to:
  /// **'The update could not be downloaded. Your connection may have dropped.'**
  String get updateFailedDownload;

  /// The checksum did not match — the one failure that is never retried blindly.
  ///
  /// In en, this message translates to:
  /// **'What was downloaded is not what the release published, so it was not run. Try again, or download it from the release page yourself.'**
  String get updateFailedChecksum;

  /// The package could not be executed.
  ///
  /// In en, this message translates to:
  /// **'The installer was downloaded but would not start.'**
  String get updateFailedLaunch;

  /// Retries a failed update.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get updateRetry;

  /// Closes the update prompt.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get updateClose;

  /// The heading above the release notes.
  ///
  /// In en, this message translates to:
  /// **'What changed'**
  String get updateReleaseNotes;

  /// Opens the statistics as a story.
  ///
  /// In en, this message translates to:
  /// **'See it as a story'**
  String get statsStory;

  /// The opening card's heading.
  ///
  /// In en, this message translates to:
  /// **'Your listening, so far'**
  String get storyOpeningTitle;

  /// How many plays in total.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 play} other{{count} plays}}'**
  String storyOpeningPlays(int count);

  /// How many distinct tracks account for them.
  ///
  /// In en, this message translates to:
  /// **'across {count, plural, =1{1 track} other{{count} tracks}}'**
  String storyOpeningTracks(int count);

  /// The heading of the top artist card.
  ///
  /// In en, this message translates to:
  /// **'Your top artist'**
  String get storyTopArtist;

  /// The heading of the top album card.
  ///
  /// In en, this message translates to:
  /// **'Your top record'**
  String get storyTopAlbum;

  /// The heading of the top track card.
  ///
  /// In en, this message translates to:
  /// **'Your top track'**
  String get storyTopTrack;

  /// The heading of the top genre card.
  ///
  /// In en, this message translates to:
  /// **'Your top genre'**
  String get storyTopGenre;

  /// The heading of the artists ranking card.
  ///
  /// In en, this message translates to:
  /// **'Your artists'**
  String get storyRankingArtists;

  /// The heading of the albums ranking card.
  ///
  /// In en, this message translates to:
  /// **'Your records'**
  String get storyRankingAlbums;

  /// The heading of the tracks ranking card.
  ///
  /// In en, this message translates to:
  /// **'Your tracks'**
  String get storyRankingTracks;

  /// The heading of the genres ranking card.
  ///
  /// In en, this message translates to:
  /// **'Your genres'**
  String get storyRankingGenres;

  /// What share of a ranking's plays the leader accounts for.
  ///
  /// In en, this message translates to:
  /// **'{percent}% of what you played'**
  String storyShareOfPlays(String percent);

  /// The closing card's heading.
  ///
  /// In en, this message translates to:
  /// **'That is your Orpheus'**
  String get storySummaryTitle;

  /// Hands the card to another application.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get storyShare;

  /// Writes the card to a file.
  ///
  /// In en, this message translates to:
  /// **'Save the picture'**
  String get storySave;

  /// Confirms the card was handed on.
  ///
  /// In en, this message translates to:
  /// **'Shared.'**
  String get storyShared;

  /// Confirms the card was written to a file.
  ///
  /// In en, this message translates to:
  /// **'Saved.'**
  String get storySaved;

  /// Shown when rendering or sending the card failed.
  ///
  /// In en, this message translates to:
  /// **'The picture could not be made.'**
  String get storyShareFailed;

  /// The tooltip on the story's close button.
  ///
  /// In en, this message translates to:
  /// **'Close the story'**
  String get storyClose;

  /// The tooltip on the forward half of a card.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get storyNext;

  /// The tooltip on the back half of a card.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get storyPrevious;

  /// The line at the foot of a shared card, which travels with the picture.
  ///
  /// In en, this message translates to:
  /// **'Made with Orpheus'**
  String get storyMadeWith;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
