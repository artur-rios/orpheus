import 'dart:typed_data';

import 'data_export.dart';

/// The `format` a backup's `backup.json` names it by.
const String backupFormat = 'orpheus-backup';

/// The `formatVersion` of the layout this release writes and reads.
const int backupFormatVersion = 1;

/// The file holding the manifest: what the ZIP is and when it was made.
const String backupManifestFile = 'backup.json';

/// The file holding step 6's export document, whole.
const String backupDataFile = 'data.json';

/// The file holding the [PreferencesSnapshot].
const String backupPreferencesFile = 'preferences.json';

/// The folder holding the playlist covers, one file per playlist, named by the
/// playlist's id in the data document.
const String backupCoversFolder = 'covers/';

/// The most a cover picture in a backup may weigh, uncompressed: 20 MB.
///
/// A cover is a small picture the owner chose, and the backup file is one
/// somebody else may hand over. An entry declaring more than this, or turning
/// out to hold more, is not read — a cover the size of a movie is not worth
/// the memory it would take — and its playlist is restored without it.
const int maxBackupCoverBytes = 20 * 1024 * 1024;

/// What `backup.json` says about a backup, with its keys in the order they are
/// written.
///
/// [contents] lists the other files in the ZIP, so a person opening it can see
/// what it holds without reading the rest.
Map<String, Object?> backupManifest({
  required DateTime createdAt,
  String? orpheusVersion,
  required List<String> contents,
}) => {
  'format': backupFormat,
  'formatVersion': backupFormatVersion,
  'createdAt': createdAt.toUtc().toIso8601String(),
  'orpheusVersion': orpheusVersion,
  'contents': contents,
};

/// The owner's preferences as a backup carries them.
///
/// Plain values only, so the domain stays free of Flutter: [themeMode] is the
/// name of the `ThemeMode` (`system`, `light` or `dark`) and [locale] is the
/// language tag the settings store keeps (`pt_BR`, `en`), or `null` to follow
/// the system. Whoever applies a snapshot converts at the edge.
///
/// What it leaves out is on purpose: the update version the owner chose to
/// skip is a fact about one device.
class PreferencesSnapshot {
  /// Creates a snapshot.
  const PreferencesSnapshot({
    required this.themeMode,
    required this.locale,
    required this.opensPlayerOnPlay,
    required this.rescansAtStartup,
    required this.fetchesLyricsOnline,
    required this.checksForUpdatesOnStartup,
    required this.showsAutoPlaylists,
    required this.volume,
    required this.libraryFolders,
  });

  /// Reads a snapshot from the `preferences.json` document.
  ///
  /// A key that is missing, or holds something of the wrong kind, stands in as
  /// the default a fresh install would have: a backup written by a release
  /// with fewer preferences still restores the ones it has.
  factory PreferencesSnapshot.fromJson(Map<String, Object?> json) {
    bool flag(String key) => json[key] is bool ? json[key]! as bool : true;

    final theme = json['themeMode'];
    final locale = json['locale'];
    final volume = json['volume'];
    final folders = json['libraryFolders'];

    return PreferencesSnapshot(
      themeMode: theme is String && theme.isNotEmpty ? theme : 'system',
      locale: locale is String && locale.isNotEmpty ? locale : null,
      opensPlayerOnPlay: flag('opensPlayerOnPlay'),
      rescansAtStartup: flag('rescansAtStartup'),
      fetchesLyricsOnline: flag('fetchesLyricsOnline'),
      checksForUpdatesOnStartup: flag('checksForUpdatesOnStartup'),
      showsAutoPlaylists: flag('showsAutoPlaylists'),
      volume: volume is num ? volume.toDouble() : 1,
      libraryFolders: folders is List
          ? [
              for (final folder in folders)
                if (folder is String) folder,
            ]
          : const [],
    );
  }

  /// The name of the owner's `ThemeMode`.
  final String themeMode;

  /// The language tag the owner chose, or `null` to follow the system.
  final String? locale;

  /// Whether the player opens itself when a track starts.
  final bool opensPlayerOnPlay;

  /// Whether the library folders are re-scanned when the application starts.
  final bool rescansAtStartup;

  /// Whether a track with no words on this machine is looked up online.
  final bool fetchesLyricsOnline;

  /// Whether the application looks for a newer release when it starts.
  final bool checksForUpdatesOnStartup;

  /// Whether the auto playlists are shown.
  final bool showsAutoPlaylists;

  /// The playback volume, from 0 to 1.
  final double volume;

  /// The folders the library was built from.
  final List<String> libraryFolders;

  /// The `preferences.json` document, with its keys in the order they are
  /// written.
  Map<String, Object?> toJson() => {
    'themeMode': themeMode,
    'locale': locale,
    'opensPlayerOnPlay': opensPlayerOnPlay,
    'rescansAtStartup': rescansAtStartup,
    'fetchesLyricsOnline': fetchesLyricsOnline,
    'checksForUpdatesOnStartup': checksForUpdatesOnStartup,
    'showsAutoPlaylists': showsAutoPlaylists,
    'volume': volume,
    'libraryFolders': libraryFolders,
  };

  @override
  bool operator ==(Object other) =>
      other is PreferencesSnapshot &&
      other.themeMode == themeMode &&
      other.locale == locale &&
      other.opensPlayerOnPlay == opensPlayerOnPlay &&
      other.rescansAtStartup == rescansAtStartup &&
      other.fetchesLyricsOnline == fetchesLyricsOnline &&
      other.checksForUpdatesOnStartup == checksForUpdatesOnStartup &&
      other.showsAutoPlaylists == showsAutoPlaylists &&
      other.volume == volume &&
      _sameStrings(other.libraryFolders, libraryFolders);

  @override
  int get hashCode => Object.hash(
    themeMode,
    locale,
    opensPlayerOnPlay,
    rescansAtStartup,
    fetchesLyricsOnline,
    checksForUpdatesOnStartup,
    showsAutoPlaylists,
    volume,
    Object.hashAll(libraryFolders),
  );
}

/// The preferences of a fresh install: what the settings store answers for
/// each one never set, and what a restore's *Merge* compares the owner's with.
const PreferencesSnapshot freshInstallPreferences = PreferencesSnapshot(
  themeMode: 'system',
  locale: null,
  opensPlayerOnPlay: true,
  rescansAtStartup: true,
  fetchesLyricsOnline: true,
  checksForUpdatesOnStartup: true,
  showsAutoPlaylists: true,
  volume: 1,
  libraryFolders: [],
);

bool _sameStrings(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }

  return true;
}

/// What a file the owner picked turned out to hold.
class BackupContents {
  /// Creates the contents.
  const BackupContents({
    required this.data,
    required this.preferences,
    required this.covers,
    required this.createdAt,
    required this.isFullBackup,
    this.skippedCovers = const {},
  });

  /// Step 6's export document.
  final Map<String, Object?> data;

  /// The preferences, or `null` when the file carries none: a data JSON never
  /// does, and a backup whose `preferences.json` is absent or unreadable
  /// does not either.
  final PreferencesSnapshot? preferences;

  /// The playlists' custom covers by playlist id, as the data document names
  /// the playlist; empty for a data JSON.
  final Map<String, Uint8List> covers;

  /// The ids of the playlists whose cover the file holds but was not read,
  /// because it weighs more than [maxBackupCoverBytes]. Such a playlist is
  /// restored without a picture, and the restore says so.
  final Set<String> skippedCovers;

  /// When the file was made: the backup's `createdAt`, or for a data JSON its
  /// `exportedAt`. `null` when the file does not say, or says it unreadably.
  final DateTime? createdAt;

  /// Whether this is a backup ZIP rather than a data JSON on its own.
  final bool isFullBackup;
}

/// Why a file was not read as a backup.
///
/// Thrown by `readBackup`, so a caller can tell the owner which of the two
/// things to do about it.
sealed class BackupReadFailure implements Exception {
  const BackupReadFailure();
}

/// The file is not an Orpheus backup: not a ZIP or a JSON document, or one of
/// them without the files and `format` names a backup has.
final class NotABackup extends BackupReadFailure {
  /// Creates the failure.
  const NotABackup();

  @override
  String toString() => 'NotABackup';
}

/// The file is a backup, from a release newer than this one reads.
final class NewerBackupVersion extends BackupReadFailure {
  /// Creates the failure for a file of [version].
  const NewerBackupVersion(this.version);

  /// The `formatVersion` the file declares.
  final int version;

  @override
  String toString() => 'NewerBackupVersion($version)';
}

/// Checks that [document] names itself [format] and a [supported] version.
///
/// Throws [NotABackup] when the format is something else or the version is not
/// a positive whole number, and [NewerBackupVersion] when it is newer than
/// [supported].
void checkFormat(
  Map<String, Object?> document, {
  required String format,
  required int supported,
}) {
  if (document['format'] != format) throw const NotABackup();

  final version = document['formatVersion'];
  if (version is! int || version < 1) throw const NotABackup();
  if (version > supported) throw NewerBackupVersion(version);
}

/// Checks that [document] is a data export this release reads.
void checkDataDocument(Map<String, Object?> document) => checkFormat(
  document,
  format: dataExportFormat,
  supported: dataExportFormatVersion,
);

/// Checks that [document] is a `backup.json` this release reads.
void checkBackupManifest(Map<String, Object?> document) =>
    checkFormat(document, format: backupFormat, supported: backupFormatVersion);
