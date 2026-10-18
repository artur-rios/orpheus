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

  /// The area that browses the library by genre, in the navigation panel.
  ///
  /// In en, this message translates to:
  /// **'Genres'**
  String get destinationGenres;

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

  /// Search selector: match the term against everything.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get searchFieldAll;

  /// Search selector: match the term against song titles only.
  ///
  /// In en, this message translates to:
  /// **'Songs'**
  String get searchFieldSongs;

  /// Search selector: match the term against artists only.
  ///
  /// In en, this message translates to:
  /// **'Artists'**
  String get searchFieldArtists;

  /// Search selector: match the term against albums only.
  ///
  /// In en, this message translates to:
  /// **'Albums'**
  String get searchFieldAlbums;

  /// Search selector: match the term against genres only.
  ///
  /// In en, this message translates to:
  /// **'Genres'**
  String get searchFieldGenres;

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

  /// The group of tracks whose tags name no genre.
  ///
  /// In en, this message translates to:
  /// **'No genre'**
  String get genreUnknown;

  /// Plays every track tagged with a genre.
  ///
  /// In en, this message translates to:
  /// **'Play the genre'**
  String get genrePlay;

  /// Plays every track tagged with a genre, in an order nobody chose.
  ///
  /// In en, this message translates to:
  /// **'Shuffle the genre'**
  String get genreShuffle;

  /// Under a genre's name: how many tracks it holds, then how long they run.
  ///
  /// In en, this message translates to:
  /// **'{tracks} · {length}'**
  String genreRowSummary(String tracks, String length);

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
  /// **'{tracks} tracks — {added} new, {updated} updated, {removed} gone.'**
  String scanReport(int tracks, int added, int updated, int removed);

  /// How many files were listed but not understood.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No file had tags that could not be read.} =1{1 file had tags that could not be read.} other{{count} files had tags that could not be read.}}'**
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
  /// **'{count, plural, =0{Every played track carries an artist, record or genre tag, so each appears in an artist, record or genre ranking below.} =1{1 played track carries no artist, record or genre tag, so it is counted in the totals above but appears in no artist, record or genre ranking below.} other{{count} played tracks carry no artist, record or genre tag, so they are counted in the totals above but appear in no artist, record or genre ranking below.}}'**
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

  /// The action, on a record and on a track, that fills its tags from MusicBrainz.
  ///
  /// In en, this message translates to:
  /// **'Autofill tags…'**
  String get autofillAction;

  /// The title of the dialog that asks which tags an autofill should fill.
  ///
  /// In en, this message translates to:
  /// **'Fill which tags?'**
  String get autofillFieldsTitle;

  /// The button that confirms the chosen tags and starts the MusicBrainz lookup.
  ///
  /// In en, this message translates to:
  /// **'Find'**
  String get autofillFind;

  /// Shown in the field dialog when none of the selected files is of a kind whose tags Orpheus can write.
  ///
  /// In en, this message translates to:
  /// **'Orpheus can only change the tags of MP3 and FLAC files.'**
  String get autofillNothingWritable;

  /// The note under the cover art checkbox in the field dialog.
  ///
  /// In en, this message translates to:
  /// **'Downloads the cover from the Cover Art Archive and stores it in each file.'**
  String get autofillCoverNote;

  /// The name of the title tag, in the field dialog and the review.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get autofillFieldTitle;

  /// The name of the artist tag, in the field dialog and the review.
  ///
  /// In en, this message translates to:
  /// **'Artist'**
  String get autofillFieldArtist;

  /// The name of the album artist tag, in the field dialog and the review.
  ///
  /// In en, this message translates to:
  /// **'Album artist'**
  String get autofillFieldAlbumArtist;

  /// The name of the album tag, in the field dialog and the review.
  ///
  /// In en, this message translates to:
  /// **'Album'**
  String get autofillFieldAlbum;

  /// The name of the track number tag, in the field dialog and the review.
  ///
  /// In en, this message translates to:
  /// **'Track number'**
  String get autofillFieldTrackNumber;

  /// The name of the track total tag, in the field dialog and the review.
  ///
  /// In en, this message translates to:
  /// **'Track total'**
  String get autofillFieldTrackTotal;

  /// The name of the disc number tag, in the field dialog and the review.
  ///
  /// In en, this message translates to:
  /// **'Disc number'**
  String get autofillFieldDiscNumber;

  /// The name of the disc total tag, in the field dialog and the review.
  ///
  /// In en, this message translates to:
  /// **'Disc total'**
  String get autofillFieldDiscTotal;

  /// The name of the year tag, in the field dialog and the review.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get autofillFieldYear;

  /// The name of the genre tag, in the field dialog and the review.
  ///
  /// In en, this message translates to:
  /// **'Genre'**
  String get autofillFieldGenre;

  /// The name of the embedded cover picture, in the field dialog and the review.
  ///
  /// In en, this message translates to:
  /// **'Cover art'**
  String get autofillFieldCover;

  /// Shown on the autofill screen while the lookup runs.
  ///
  /// In en, this message translates to:
  /// **'Looking this up on MusicBrainz…'**
  String get autofillSearching;

  /// Shown on the autofill screen when the lookup could not connect.
  ///
  /// In en, this message translates to:
  /// **'MusicBrainz could not be reached.'**
  String get autofillUnreachable;

  /// Shown on the autofill screen when MusicBrainz turned the request away for being too frequent.
  ///
  /// In en, this message translates to:
  /// **'MusicBrainz is busy. Try again in a moment.'**
  String get autofillRateLimited;

  /// The button on the autofill screen that repeats a failed lookup.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get autofillTryAgain;

  /// Shown on the autofill screen when the lookup found no release.
  ///
  /// In en, this message translates to:
  /// **'Nothing found on MusicBrainz.'**
  String get autofillNothingFound;

  /// The label of the search field on the autofill screen.
  ///
  /// In en, this message translates to:
  /// **'Search MusicBrainz'**
  String get autofillSearchLabel;

  /// The button that repeats the lookup with the text the owner typed.
  ///
  /// In en, this message translates to:
  /// **'Search again'**
  String get autofillSearchAgain;

  /// The control on the autofill screen that picks another release than the one proposed.
  ///
  /// In en, this message translates to:
  /// **'Different release'**
  String get autofillDifferentRelease;

  /// The button on the autofill screen that writes the ticked changes into the files.
  ///
  /// In en, this message translates to:
  /// **'Write {changes, plural, =0{0 changes} =1{1 change} other{{changes} changes}} to {files, plural, =0{0 files} =1{1 file} other{{files} files}}'**
  String autofillWrite(int changes, int files);

  /// The control on the autofill screen that ticks every change.
  ///
  /// In en, this message translates to:
  /// **'Tick all'**
  String get autofillTickAll;

  /// The control on the autofill screen that unticks every change.
  ///
  /// In en, this message translates to:
  /// **'Untick all'**
  String get autofillUntickAll;

  /// Shown beside a file whose tags already equal the proposal.
  ///
  /// In en, this message translates to:
  /// **'Already matches'**
  String get autofillNoChanges;

  /// Shown beside a file that matches no track of the chosen release.
  ///
  /// In en, this message translates to:
  /// **'No match on this release'**
  String get autofillNoMatch;

  /// Shown beside a file on the review whose kind Orpheus cannot write.
  ///
  /// In en, this message translates to:
  /// **'Orpheus can\'t change this kind of file'**
  String get autofillUnwritable;

  /// Shown for a file of a kind Orpheus writes (MP3 or FLAC) whose tags could not be read, or are of a shape it will not change safely — on its card on the autofill review, and as why it was not written in the summary.
  ///
  /// In en, this message translates to:
  /// **'Orpheus can\'t safely change this file\'s tags'**
  String get autofillUnsafeTags;

  /// Shown beside a file on the review when its kind cannot hold some of the chosen tags; the placeholder lists their names.
  ///
  /// In en, this message translates to:
  /// **'This kind of file can\'t hold: {fields}'**
  String autofillNotWritableFields(String fields);

  /// Shown on the review when the chosen release has no cover to download.
  ///
  /// In en, this message translates to:
  /// **'This release has no cover on the Cover Art Archive.'**
  String get autofillCoverMissing;

  /// Shown on the review when the chosen release's cover could not be downloaded — a failure, unlike a release that has none.
  ///
  /// In en, this message translates to:
  /// **'The cover could not be downloaded from the Cover Art Archive.'**
  String get autofillCoverUnavailable;

  /// The progress shown while the files are being written.
  ///
  /// In en, this message translates to:
  /// **'Writing {done} of {total}…'**
  String autofillWriting(int done, int total);

  /// The button that abandons an autofill.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get autofillCancel;

  /// The button that leaves the autofill screen or its dialog.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get autofillClose;

  /// The summary shown when an autofill has finished writing.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No files were updated.} =1{1 file updated.} other{{count} files updated.}}'**
  String autofillWritten(int count);

  /// The result shown beside a file that changed on disk after Orpheus read it, so it was left alone.
  ///
  /// In en, this message translates to:
  /// **'Changed since Orpheus read it — not written'**
  String get autofillOutcomeChanged;

  /// The result shown beside a file that playback was holding open.
  ///
  /// In en, this message translates to:
  /// **'In use by playback — try again once it has moved on'**
  String get autofillOutcomeInUse;

  /// The result shown beside a file that had ticked changes but was never reached, because the owner cancelled the write first.
  ///
  /// In en, this message translates to:
  /// **'Not written — cancelled first'**
  String get autofillOutcomeNotWritten;

  /// The result shown beside a file the system would not let Orpheus change.
  ///
  /// In en, this message translates to:
  /// **'Orpheus isn\'t allowed to change it'**
  String get autofillOutcomeDenied;

  /// The result shown beside a file whose write failed.
  ///
  /// In en, this message translates to:
  /// **'Could not be written'**
  String get autofillOutcomeFailed;

  /// The result shown beside a file whose kind Orpheus cannot write.
  ///
  /// In en, this message translates to:
  /// **'Orpheus can\'t change this kind of file'**
  String get autofillOutcomeUnsupported;

  /// Shown when the system refused Orpheus write access to the music library.
  ///
  /// In en, this message translates to:
  /// **'Orpheus needs permission to change your music files. Nothing was written.'**
  String get autofillAccessRefused;

  /// The button that opens the system settings where write access can be granted.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get autofillOpenSettings;

  /// The action, in a track's menu, that opens the form its tags are edited in by hand.
  ///
  /// In en, this message translates to:
  /// **'Edit tags…'**
  String get tagEditAction;

  /// The title of the form a track's tags are edited in by hand.
  ///
  /// In en, this message translates to:
  /// **'Edit tags'**
  String get tagEditTitle;

  /// The button on the tag editor that writes the changed tags into the file.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get tagEditSave;

  /// The button on the tag editor that opens the system dialog to pick a picture for the cover.
  ///
  /// In en, this message translates to:
  /// **'Choose image…'**
  String get tagEditChooseCover;

  /// The button on the tag editor that takes the cover out of the file.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get tagEditRemoveCover;

  /// The accessible name of the placeholder the tag editor shows for a file with no cover.
  ///
  /// In en, this message translates to:
  /// **'No cover'**
  String get tagEditNoCover;

  /// Shown on the tag editor when the picked file is not a JPEG or PNG picture; the cover is left as it was.
  ///
  /// In en, this message translates to:
  /// **'Choose a JPEG or PNG image'**
  String get tagEditCoverNotImage;

  /// Shown under a track or disc number field on the tag editor holding something that is not a whole number of one or more.
  ///
  /// In en, this message translates to:
  /// **'Enter a whole number'**
  String get tagEditWholeNumber;

  /// Shown under the year field on the tag editor holding something that is not a year.
  ///
  /// In en, this message translates to:
  /// **'Enter a year from 1 to 9999'**
  String get tagEditYearRange;

  /// Shown under a track or disc number field on the tag editor left blank while its total is not: the file cannot hold a total with no number.
  ///
  /// In en, this message translates to:
  /// **'Enter a number, or clear the total'**
  String get tagEditNumberForTotal;

  /// The button on the tag editor that reads the file again after another program changed it, dropping the edits.
  ///
  /// In en, this message translates to:
  /// **'Reload'**
  String get tagEditReload;

  /// The message shown once the tag editor wrote the changed tags into the file.
  ///
  /// In en, this message translates to:
  /// **'Tags saved'**
  String get tagEditSaved;

  /// Under the title of the form that edits several songs' tags at once: the album or artist being edited, and how many songs it holds.
  ///
  /// In en, this message translates to:
  /// **'{label} · {count, plural, =1{1 song} other{{count} songs}}'**
  String tagEditManySubtitle(String label, int count);

  /// Shown on the form that edits several songs' tags while their files are being read.
  ///
  /// In en, this message translates to:
  /// **'Reading {done} of {total}…'**
  String tagEditManyReading(int done, int total);

  /// Shown on the form that edits several songs' tags while the changes are being written into their files.
  ///
  /// In en, this message translates to:
  /// **'Saving {done} of {total}…'**
  String tagEditManySaving(int done, int total);

  /// The hint in a field of the form that edits several songs' tags when the songs hold different values for it: left blank, each song keeps its own.
  ///
  /// In en, this message translates to:
  /// **'Mixed — leave blank to keep each song\'s own'**
  String get tagEditManyMixed;

  /// Shown in place of the cover on the form that edits several songs' tags when the songs have different covers.
  ///
  /// In en, this message translates to:
  /// **'Different covers'**
  String get tagEditManyMixedCovers;

  /// Shown under the form that edits several songs' tags, which leaves out the title and the track number.
  ///
  /// In en, this message translates to:
  /// **'Title and track number are edited one song at a time.'**
  String get tagEditManyOneAtATime;

  /// Shown above the form that edits several songs' tags when some of the songs cannot be written; it expands to name each and why.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 song can\'t be changed and will be left alone} other{{count} songs can\'t be changed and will be left alone}}'**
  String tagEditManySkipped(int count);

  /// Why a song is left alone by the form that edits several songs' tags: Orpheus only writes MP3 and FLAC files.
  ///
  /// In en, this message translates to:
  /// **'Not an MP3 or FLAC file'**
  String get tagEditManySkippedFormat;

  /// Why a song is left alone by the form that edits several songs' tags: its tags could not be read, or are of a shape Orpheus will not change safely.
  ///
  /// In en, this message translates to:
  /// **'Its tags can\'t be changed safely'**
  String get tagEditManySkippedUnsafe;

  /// Shown on the form that edits several songs' tags after a save some songs could not take; the songs that failed are listed beneath it with why.
  ///
  /// In en, this message translates to:
  /// **'Saved to {written, plural, =0{no songs} =1{1 song} other{{written} songs}}. {failed, plural, =1{1 couldn\'t be changed:} other{{failed} couldn\'t be changed:}}'**
  String tagEditManyPartly(int written, int failed);

  /// The message shown once the form that edits several songs' tags wrote the changes into them.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Tags saved to 1 song} other{Tags saved to {count} songs}}'**
  String tagEditManySaved(int count);

  /// Shown beside a song after the form that edits several songs' tags set a track total: the song has no track number, so its total was not changed.
  ///
  /// In en, this message translates to:
  /// **'Its track total was left as it was: it has no track number'**
  String get tagEditManyTrackTotalLeft;

  /// Shown beside a song after the form that edits several songs' tags set a disc total: the song has no disc number, so its total was not changed.
  ///
  /// In en, this message translates to:
  /// **'Its disc total was left as it was: it has no disc number'**
  String get tagEditManyDiscTotalLeft;

  /// The tooltip of the button that opens the menu of actions for an album or an artist.
  ///
  /// In en, this message translates to:
  /// **'More actions'**
  String get musicGroupActions;

  /// How many songs are selected, shown in the bar above a song list while the owner is selecting songs in it.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 selected} other{{count} selected}}'**
  String musicSelectionCount(int count);

  /// The button in the selection bar above a song list that selects every song in the list.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get musicSelectionAll;

  /// The tooltip of the button in the selection bar above a song list that ends the selection.
  ///
  /// In en, this message translates to:
  /// **'Stop selecting'**
  String get musicSelectionStop;

  /// The accessibility label of the tick box that selects or deselects a song in a song list.
  ///
  /// In en, this message translates to:
  /// **'Select {title}'**
  String musicSelectionSelect(String title);

  /// The button and menu item that open the tag editor over the songs selected in a song list.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Edit tags of 1 song…} other{Edit tags of {count} songs…}}'**
  String musicSelectionEditTags(int count);

  /// What the tag editor calls the songs selected in a song list, in its subtitle.
  ///
  /// In en, this message translates to:
  /// **'Selected songs'**
  String get musicSelectionLabel;

  /// The Playlists destination in the navigation panel, and the content area's heading while it shows.
  ///
  /// In en, this message translates to:
  /// **'Playlists'**
  String get playlistTab;

  /// The button on the Playlists tab that makes a playlist, and the title of the dialog it opens.
  ///
  /// In en, this message translates to:
  /// **'New playlist'**
  String get playlistNew;

  /// The label of the field in which a playlist's name is typed, when making or renaming one.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get playlistNameLabel;

  /// Shown under the name field when the owner submits a blank name for a playlist.
  ///
  /// In en, this message translates to:
  /// **'Give the playlist a name'**
  String get playlistNameRequired;

  /// The button that makes the playlist named in the New playlist dialog.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get playlistCreate;

  /// How many songs a playlist holds, under its name on the Playlists tab.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No songs} =1{1 song} other{{count} songs}}'**
  String playlistSongCount(int count);

  /// What the Playlists tab says when the owner has made none.
  ///
  /// In en, this message translates to:
  /// **'No playlists yet'**
  String get playlistEmpty;

  /// The tooltip of the ⋮ button on a playlist's row or tile, which opens its menu.
  ///
  /// In en, this message translates to:
  /// **'Playlist actions'**
  String get playlistActions;

  /// The tooltip of the button that goes from an open playlist back to the list of them.
  ///
  /// In en, this message translates to:
  /// **'All playlists'**
  String get playlistBackToList;

  /// The accessibility label of a playlist's picture: the owner's own cover, or the mosaic of its records.
  ///
  /// In en, this message translates to:
  /// **'Playlist cover'**
  String get playlistCoverLabel;

  /// The playlist menu item that asks for a new name.
  ///
  /// In en, this message translates to:
  /// **'Rename…'**
  String get playlistRename;

  /// The title of the dialog that asks for a playlist's new name.
  ///
  /// In en, this message translates to:
  /// **'Rename playlist'**
  String get playlistRenameTitle;

  /// The button that gives the playlist the name typed in the rename dialog.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get playlistRenameConfirm;

  /// The playlist menu item that opens the image chooser to give the playlist a picture of the owner's own.
  ///
  /// In en, this message translates to:
  /// **'Choose cover…'**
  String get playlistChooseCover;

  /// The playlist menu item, shown only when the playlist has a picture of the owner's own, that takes it off so the mosaic of its records shows again.
  ///
  /// In en, this message translates to:
  /// **'Remove cover'**
  String get playlistRemoveCover;

  /// Shown when the file chosen as a playlist's cover is not a JPEG or PNG image; nothing is changed.
  ///
  /// In en, this message translates to:
  /// **'Choose a JPEG or PNG image for the cover'**
  String get playlistCoverNotImage;

  /// The playlist menu item that saves the playlist as an .m3u file where the owner chooses.
  ///
  /// In en, this message translates to:
  /// **'Export to .m3u…'**
  String get playlistExport;

  /// Shown once a playlist has been exported, naming the file it was saved as.
  ///
  /// In en, this message translates to:
  /// **'Saved to {path}'**
  String playlistExportSaved(String path);

  /// Shown once a playlist has been exported to a place the system gives no file path for, such as Android's document provider.
  ///
  /// In en, this message translates to:
  /// **'Playlist exported'**
  String get playlistExported;

  /// Shown when a playlist could not be saved as an .m3u file.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t export {name}'**
  String playlistExportFailed(String name);

  /// The playlist menu item that asks before deleting the playlist.
  ///
  /// In en, this message translates to:
  /// **'Delete…'**
  String get playlistDelete;

  /// The question asked before a playlist is deleted.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}?'**
  String playlistDeleteTitle(String name);

  /// Under the question asked before a playlist is deleted: only the playlist goes, never a song or a file.
  ///
  /// In en, this message translates to:
  /// **'The songs stay in your library.'**
  String get playlistDeleteBody;

  /// The button that deletes the playlist, in the question asked first.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get playlistDeleteConfirm;

  /// Shown when making, renaming, giving a cover to or deleting a playlist could not be saved; nothing was changed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the playlists'**
  String get playlistSaveFailed;

  /// The button in an open playlist's header that plays every song in it that is in the library, in an order nobody chose.
  ///
  /// In en, this message translates to:
  /// **'Shuffle'**
  String get playlistShuffle;

  /// Under an open playlist's name: how many songs it holds (already worded, e.g. '4 songs') and how long they last together (e.g. '1:02:15').
  ///
  /// In en, this message translates to:
  /// **'{songs} · {length}'**
  String playlistSummary(String songs, String length);

  /// What an open playlist shows in place of its rows when it holds no songs.
  ///
  /// In en, this message translates to:
  /// **'No songs in this playlist yet'**
  String get playlistNoSongs;

  /// Under the title of a song in a playlist whose file is no longer in the library and whose artist is not known; the row cannot be played.
  ///
  /// In en, this message translates to:
  /// **'Missing'**
  String get playlistMissing;

  /// Under the title of a song in a playlist whose file is no longer in the library, with the artist it had when it was added; the row cannot be played.
  ///
  /// In en, this message translates to:
  /// **'Missing · {artist}'**
  String playlistMissingBy(String artist);

  /// The song menu item, and the selection bar button and menu item, that take the song or the selected songs out of the open playlist; the files stay in the library.
  ///
  /// In en, this message translates to:
  /// **'Remove from playlist'**
  String get playlistRemoveFrom;

  /// The accessibility label of the handle on each row of an open playlist, by which the row is dragged to another place.
  ///
  /// In en, this message translates to:
  /// **'Drag to reorder'**
  String get playlistReorder;

  /// The song, album and artist menu item, the selection menu item and the selection bar button that add the song, the tracks or the selected songs to a playlist the owner then chooses.
  ///
  /// In en, this message translates to:
  /// **'Add to playlist…'**
  String get playlistAddTo;

  /// The title of the dialog that lists the playlists to add songs to.
  ///
  /// In en, this message translates to:
  /// **'Add to playlist'**
  String get playlistAddToTitle;

  /// The first row of the dialog that lists the playlists to add songs to: it asks for a name, makes the playlist and adds the songs to it.
  ///
  /// In en, this message translates to:
  /// **'New playlist…'**
  String get playlistAddToNew;

  /// Shown once songs have been added to a playlist, with how many were added and the playlist's name.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Added 1 song to {name}} other{Added {count} songs to {name}}}'**
  String playlistAdded(int count, String name);

  /// Shown when the owner chose to skip the songs already in a playlist and there were no others, so nothing was added.
  ///
  /// In en, this message translates to:
  /// **'Nothing added'**
  String get playlistNothingAdded;

  /// The question asked when some of the songs about to be added to a playlist are already in it.
  ///
  /// In en, this message translates to:
  /// **'Already in {name} — add again?'**
  String playlistDuplicateTitle(String name);

  /// The answer to the already-in-the-playlist question that adds every song, the ones already there a second time.
  ///
  /// In en, this message translates to:
  /// **'Add anyway'**
  String get playlistAddAnyway;

  /// The answer to the already-in-the-playlist question that adds only the songs that are not there yet.
  ///
  /// In en, this message translates to:
  /// **'Skip those'**
  String get playlistSkipThose;

  /// The heading over the auto playlists at the top of the Playlists tab: the ones Orpheus keeps by itself from what the owner listens to.
  ///
  /// In en, this message translates to:
  /// **'Auto playlists'**
  String get autoPlaylistSection;

  /// The heading over the owner's own playlists in the Playlists tab, below the auto playlists.
  ///
  /// In en, this message translates to:
  /// **'Your playlists'**
  String get autoPlaylistYours;

  /// The name of the auto playlist of the songs the owner has played most in the last 30 days.
  ///
  /// In en, this message translates to:
  /// **'Favourites lately'**
  String get autoPlaylistLately;

  /// The name of the auto playlist of the songs the owner has played most, whenever they were played.
  ///
  /// In en, this message translates to:
  /// **'All-time favourites'**
  String get autoPlaylistAllTime;

  /// Shown under the header of Favourites lately while there are too few recent plays recorded to rank by them, so it is ranked by the songs last played instead.
  ///
  /// In en, this message translates to:
  /// **'Getting to know your recent listening'**
  String get autoPlaylistFallbackNote;

  /// What Favourites lately shows when no song has been played in the last 30 days.
  ///
  /// In en, this message translates to:
  /// **'Play some music and your recent favourites will show here'**
  String get autoPlaylistLatelyEmpty;

  /// What All-time favourites shows when no song in the library has been played yet.
  ///
  /// In en, this message translates to:
  /// **'Play some music and your favourites will show here'**
  String get autoPlaylistAllTimeEmpty;

  /// The preference that shows or hides the auto playlists in the Playlists tab.
  ///
  /// In en, this message translates to:
  /// **'Show auto playlists'**
  String get autoPlaylistShow;

  /// The line under the Show auto playlists preference: what it shows, and that turning it off does not stop plays being recorded.
  ///
  /// In en, this message translates to:
  /// **'Favourites lately and All-time favourites, at the top of Playlists. Your plays are still counted while they are hidden.'**
  String get autoPlaylistShowDetail;
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
