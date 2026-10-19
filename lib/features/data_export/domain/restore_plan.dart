import 'dart:math' as math;
import 'dart:typed_data';

import '../../library/domain/music_entry.dart';
import '../../playlists/domain/playlist.dart';
import '../../stats/domain/play_history.dart';
import 'backup.dart';

/// What a restore does with one part of the owner's data.
enum RestoreChoice {
  /// Keep what is here and add what the backup has that is not.
  merge,

  /// Keep what is here, and add only what is wholly new.
  skip,

  /// Put the backup's in place of what is here.
  replace,
}

/// How far apart two lengths may be for the songs to count as one.
const Duration _lengthTolerance = Duration(seconds: 2);

/// The data document's sections a restore can refuse, when the backup could
/// not read them.
const Set<String> _restorableSections = {_playlistsSection, _historySection};

/// The data document's section holding the playlists.
const String _playlistsSection = 'playlists';

/// The data document's section holding the play history.
const String _historySection = 'playHistory';

/// Finds the library song a backup's song is.
///
/// First by path, and when the backup had exactly one music folder and this
/// device has exactly one ([oldFolder] and [newFolder]), a path under the old
/// one is first moved to the same place under the new one, its separators
/// following the new folder's. Then by tags: the same title, artist and album,
/// trimmed and ignoring case, and a length within two seconds — and only when
/// exactly one library song answers, since a wrong match would hand one song's
/// plays to another. A song with no title or no length is not matched by tags:
/// too little is known about it to tell it apart.
class SongMatcher {
  /// Creates a matcher over [library].
  SongMatcher(List<MusicEntry> library, {String? oldFolder, String? newFolder})
    : _paths = {for (final song in library) song.file.path},
      _byTags = _indexed(library),
      _oldFolder = oldFolder == null ? null : _withoutTrailing(oldFolder),
      _newFolder = newFolder == null ? null : _withoutTrailing(newFolder);

  final Set<String> _paths;
  final Map<_Tags, List<MusicEntry>> _byTags;
  final String? _oldFolder;
  final String? _newFolder;

  /// The library path of [backupSong] — a `songs[]`, playlist entry or
  /// `playHistory[]` object of the data document — or `null` when the library
  /// holds no song that is certainly it.
  String? match(Map<String, Object?> backupSong) {
    final path = backupSong['path'];
    if (path is String) {
      final moved = _moved(path);
      if (_paths.contains(moved)) return moved;
      if (_paths.contains(path)) return path;
    }

    final tags = _Tags.of(
      backupSong['title'],
      backupSong['artist'],
      backupSong['album'],
    );
    final length = backupSong['durationMs'];
    if (tags == null || length is! int) return null;

    final wanted = Duration(milliseconds: length);
    final found = [
      for (final song in _byTags[tags] ?? const <MusicEntry>[])
        if ((song.duration! - wanted).abs() <= _lengthTolerance) song,
    ];

    return found.length == 1 ? found.single.file.path : null;
  }

  /// [path] under the new folder, when it is under the old one; otherwise
  /// [path] as it is.
  String _moved(String path) {
    final old = _oldFolder;
    final now = _newFolder;
    if (old == null || now == null) return path;
    if (!path.startsWith(old)) return path;

    final rest = path.substring(old.length);
    // `/music2/a.flac` is not under `/music`.
    if (rest.isEmpty || !_isSeparator(rest[0])) return path;

    final parts = rest
        .split(old.contains(r'\') ? RegExp(r'[\\/]') : RegExp('/'))
        .where((part) => part.isNotEmpty);
    final separator = now.contains(r'\') ? r'\' : '/';

    return [now, ...parts].join(separator);
  }

  static Map<_Tags, List<MusicEntry>> _indexed(List<MusicEntry> library) {
    final index = <_Tags, List<MusicEntry>>{};
    for (final song in library) {
      final tags = _Tags.of(song.title, song.artist, song.album);
      if (tags == null || song.duration == null) continue;
      (index[tags] ??= []).add(song);
    }

    return index;
  }

  static bool _isSeparator(String character) =>
      character == '/' || character == r'\';

  /// [folder] without the separators it ends in, so `C:\Music\` and
  /// `C:\Music` are one folder; the root `/` becomes the empty string.
  static String _withoutTrailing(String folder) {
    var end = folder.length;
    while (end > 0 && _isSeparator(folder[end - 1])) {
      end--;
    }

    return folder.substring(0, end);
  }
}

/// The tags songs are matched by, folded so that spacing and case do not
/// count.
class _Tags {
  const _Tags(this.title, this.artist, this.album);

  /// The tags of a song, or `null` when it has no title.
  static _Tags? of(Object? title, Object? artist, Object? album) {
    final folded = _folded(title);
    if (folded == null) return null;

    return _Tags(folded, _folded(artist), _folded(album));
  }

  final String title;
  final String? artist;
  final String? album;

  static String? _folded(Object? value) =>
      value is String ? trimmedOrNull(value)?.toLowerCase() : null;

  @override
  bool operator ==(Object other) =>
      other is _Tags &&
      other.title == title &&
      other.artist == artist &&
      other.album == album;

  @override
  int get hashCode => Object.hash(title, artist, album);
}

/// What restoring the playlists comes to.
class PlaylistsOutcome {
  /// Creates the outcome.
  const PlaylistsOutcome({
    required this.playlists,
    required this.coversToWrite,
    required this.added,
    required this.merged,
    required this.replaced,
  });

  /// Every playlist there will be, to be written as one list.
  final List<Playlist> playlists;

  /// The covers to write, by the id of the playlist on this device they
  /// belong to.
  final Map<String, Uint8List> coversToWrite;

  /// How many playlists the backup adds.
  final int added;

  /// How many playlists here a backup's playlist changed, by giving them
  /// entries or a cover; one that already held everything is not counted.
  final int merged;

  /// How many playlists here are removed, for a [RestoreChoice.replace].
  final int replaced;
}

/// The playlists [current] becomes when [backup]'s are restored by [choice].
///
/// Playlists are told apart by name. [RestoreChoice.merge] adds the backup's
/// playlists whose name is not here, and appends to the playlist here with
/// that name — the most recently changed, when several share it — the
/// backup's entries whose song it does not hold, in the backup's order; a
/// backup cover is given only to a playlist here that has none.
/// [RestoreChoice.skip] only adds. [RestoreChoice.replace] removes every
/// playlist here and creates the backup's.
///
/// Every playlist added gets an id from [newId], as does every entry added,
/// because a backup's id may be one already used here; its cover is written
/// under the new id. A cover is looked up only by the id of a playlist the
/// data document names. An entry's song is matched with [matcher]; one that
/// is not found keeps the backup's path and the details it was saved with.
///
/// When the backup could not read its playlists ([unreadableParts]), [current]
/// is answered as it is, whatever [choice] says: an empty section is not the
/// owner's playlists, and replacing with it would wipe theirs.
PlaylistsOutcome restorePlaylists(
  List<Playlist> current,
  BackupContents backup,
  SongMatcher matcher,
  RestoreChoice choice, {
  required String Function() newId,
  required DateTime now,
}) {
  if (unreadableParts(backup).contains(_playlistsSection)) {
    return PlaylistsOutcome(
      playlists: current,
      coversToWrite: const {},
      added: 0,
      merged: 0,
      replaced: 0,
    );
  }

  final saved = _savedPlaylists(backup.data, matcher);
  final covers = <String, Uint8List>{};

  Playlist created(_SavedPlaylist playlist) {
    final id = newId();
    final cover = backup.covers[playlist.id];
    if (cover != null) covers[id] = cover;

    return Playlist(
      id: id,
      name: playlist.name,
      entries: [for (final entry in playlist.entries) entry.withId(newId())],
      coverId: cover == null ? null : id,
      createdAt: playlist.createdAt ?? now,
      modifiedAt: playlist.modifiedAt ?? now,
    );
  }

  if (choice == RestoreChoice.replace) {
    return PlaylistsOutcome(
      playlists: [for (final playlist in saved) created(playlist)],
      coversToWrite: covers,
      added: saved.length,
      merged: 0,
      replaced: current.length,
    );
  }

  final names = {for (final playlist in current) playlist.name};
  final playlists = [...current];
  final mergedInto = <String>{};
  var added = 0;

  for (final playlist in saved) {
    if (!names.contains(playlist.name)) {
      playlists.add(created(playlist));
      added++;
      continue;
    }
    if (choice == RestoreChoice.skip) continue;

    final targetId = mostRecentFirst(
      current.where((here) => here.name == playlist.name),
    ).first.id;
    final index = playlists.indexWhere((here) => here.id == targetId);
    final before = playlists[index];
    var target = before;

    final held = target.pathsIn();
    final appended = [
      for (final entry in playlist.entries)
        if (held.add(entry.path)) entry.withId(newId()),
    ];
    if (appended.isNotEmpty) target = target.adding(appended, now);

    final cover = backup.covers[playlist.id];
    if (cover != null && target.coverId == null) {
      covers[target.id] = cover;
      target = target.withCover(target.id, now);
    }

    if (identical(target, before)) continue;
    playlists[index] = target;
    mergedInto.add(targetId);
  }

  return PlaylistsOutcome(
    playlists: playlists,
    coversToWrite: covers,
    added: added,
    merged: mergedInto.length,
    replaced: 0,
  );
}

/// A playlist as the data document saved it, its songs already matched.
class _SavedPlaylist {
  const _SavedPlaylist({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.modifiedAt,
    required this.entries,
  });

  /// The id the document names it by, which is what its cover is filed under.
  final String? id;
  final String name;
  final DateTime? createdAt;
  final DateTime? modifiedAt;
  final List<_SavedEntry> entries;
}

/// A playlist entry as the data document saved it, at the path it is restored
/// to.
class _SavedEntry {
  const _SavedEntry({
    required this.path,
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
  });

  final String path;
  final String? title;
  final String? artist;
  final String? album;
  final Duration? duration;

  PlaylistEntry withId(String id) => PlaylistEntry(
    id: id,
    path: path,
    title: title,
    artist: artist,
    album: album,
    duration: duration,
  );
}

List<_SavedPlaylist> _savedPlaylists(
  Map<String, Object?> data,
  SongMatcher matcher,
) {
  final songs = _songsById(data);

  return [
    for (final playlist in _objects(data[_playlistsSection]))
      if (validPlaylistName(_string(playlist['name']) ?? '') case final name?)
        _SavedPlaylist(
          id: _string(playlist['id']),
          name: name,
          createdAt: _time(playlist['createdAt']),
          modifiedAt: _time(playlist['modifiedAt']),
          entries: [
            for (final entry in _objects(playlist['entries']))
              if (_string(entry['path']) case final path?)
                _SavedEntry(
                  path: matcher.match(_probe(entry, path, songs)) ?? path,
                  title: _string(entry['title']),
                  artist: _string(entry['artist']),
                  album: _string(entry['album']),
                  duration: _duration(entry['durationMs']),
                ),
          ],
        ),
  ];
}

/// What restoring the play history comes to.
class HistoryOutcome {
  /// Creates the outcome.
  const HistoryOutcome({
    required this.history,
    required this.songs,
    required this.notInLibrary,
  });

  /// The history there will be, to be written whole.
  final PlayHistory history;

  /// How many songs the backup's history was applied to.
  final int songs;

  /// How many of those [songs] the library does not hold.
  final int notInLibrary;
}

/// The history [current] becomes when [backup]'s is restored by [choice].
///
/// Each backup song is matched with [matcher], and its plays go to the
/// library song's path; one that is not found keeps the backup's path.
/// [RestoreChoice.merge] takes, per song, the later last play, every dated
/// play either side has and the higher count — raised to the number of those
/// dates within [recentPlaysKept], when that is more — and adds the songs only
/// the backup has; [RestoreChoice.skip] only adds those;
/// [RestoreChoice.replace] puts the backup's history in place of this one.
/// Two backup records that turn out to be one song are combined the same way.
/// Dates of plays more than [recentPlaysKept] before [now] are dropped.
///
/// When the backup could not read its play history ([unreadableParts]),
/// [current] is answered as it is, whatever [choice] says.
HistoryOutcome restoreHistory(
  PlayHistory current,
  BackupContents backup,
  SongMatcher matcher,
  RestoreChoice choice,
  DateTime now,
) {
  if (unreadableParts(backup).contains(_historySection)) {
    return HistoryOutcome(history: current, songs: 0, notInLibrary: 0);
  }

  final cutoff = now.subtract(recentPlaysKept);
  final songs = _songsById(backup.data);
  final restored = <String, TrackPlays>{};
  final unmatched = <String>{};

  for (final played in _objects(backup.data[_historySection])) {
    final path = _string(played['path']);
    final plays = played['plays'];
    final lastPlayedAt = _time(played['lastPlayedAt']);
    if (path == null || plays is! int || lastPlayedAt == null) continue;

    final matched = matcher.match(_probe(played, path, songs));
    final target = matched ?? path;
    if (matched == null) unmatched.add(target);

    final track = TrackPlays(
      path: target,
      plays: plays,
      lastPlayedAt: lastPlayedAt,
      recent: _dates(played['recentPlays']),
    );
    final before = restored[target];
    restored[target] = before == null
        ? track
        : _combined(before, track, cutoff);
  }

  final tracks = choice == RestoreChoice.replace
      ? <String, TrackPlays>{}
      : {...current.tracks};
  var applied = 0;
  var notInLibrary = 0;
  for (final MapEntry(key: path, value: track) in restored.entries) {
    final here = tracks[path];
    if (here != null && choice == RestoreChoice.skip) continue;

    tracks[path] = here == null ? track : _combined(here, track, cutoff);
    applied++;
    if (unmatched.contains(path)) notInLibrary++;
  }

  return HistoryOutcome(
    history: PlayHistory(tracks: tracks).trimmedTo(now),
    songs: applied,
    notInLibrary: notInLibrary,
  );
}

/// [a] and [b], one song's two records, as one: the later last play, every
/// dated play of either from [cutoff] on, once, and the higher count — never
/// fewer than those dates, since each of them is a play.
///
/// The dates before [cutoff] are dropped before they are counted, so plays
/// the history would not keep the dates of cannot raise the count.
TrackPlays _combined(TrackPlays a, TrackPlays b, DateTime cutoff) {
  final dates = {
    for (final at in [...a.recent, ...b.recent])
      if (!at.isBefore(cutoff)) at.toUtc().microsecondsSinceEpoch,
  }.toList()..sort();

  return TrackPlays(
    path: a.path,
    plays: math.max(math.max(a.plays, b.plays), dates.length),
    lastPlayedAt: b.lastPlayedAt.isAfter(a.lastPlayedAt)
        ? b.lastPlayedAt
        : a.lastPlayedAt,
    recent: List.unmodifiable([
      for (final at in dates)
        DateTime.fromMicrosecondsSinceEpoch(at, isUtc: true),
    ]),
  );
}

/// The preferences to apply when [backup]'s are restored by [choice], or
/// `null` when nothing is to change.
///
/// [RestoreChoice.merge] takes the backup's value for each setting whose value
/// here equals its value in [defaults] — the settings store cannot tell a
/// setting never touched from one set back to its default — and keeps the
/// rest. [RestoreChoice.replace] takes every value of the backup's, a `null`
/// locale included. The music folders are always [current]'s: only the
/// restore's first stage changes them.
PreferencesSnapshot? restorePreferences(
  PreferencesSnapshot current,
  PreferencesSnapshot defaults,
  PreferencesSnapshot? backup,
  RestoreChoice choice,
) {
  if (backup == null) return null;

  switch (choice) {
    case RestoreChoice.skip:
      return null;
    case RestoreChoice.replace:
      return PreferencesSnapshot(
        themeMode: backup.themeMode,
        locale: backup.locale,
        opensPlayerOnPlay: backup.opensPlayerOnPlay,
        rescansAtStartup: backup.rescansAtStartup,
        fetchesLyricsOnline: backup.fetchesLyricsOnline,
        checksForUpdatesOnStartup: backup.checksForUpdatesOnStartup,
        showsAutoPlaylists: backup.showsAutoPlaylists,
        volume: backup.volume,
        libraryFolders: current.libraryFolders,
      );
    case RestoreChoice.merge:
      T pick<T>(T Function(PreferencesSnapshot) value) =>
          value(current) == value(defaults) ? value(backup) : value(current);

      return PreferencesSnapshot(
        themeMode: pick((p) => p.themeMode),
        locale: pick((p) => p.locale),
        opensPlayerOnPlay: pick((p) => p.opensPlayerOnPlay),
        rescansAtStartup: pick((p) => p.rescansAtStartup),
        fetchesLyricsOnline: pick((p) => p.fetchesLyricsOnline),
        checksForUpdatesOnStartup: pick((p) => p.checksForUpdatesOnStartup),
        showsAutoPlaylists: pick((p) => p.showsAutoPlaylists),
        volume: pick((p) => p.volume),
        libraryFolders: current.libraryFolders,
      );
  }
}

/// The parts [backup] could not read when it was made — `playlists`,
/// `playHistory` — as its data document's `problems` name them.
///
/// A restore offers none of these, so that replacing can never wipe real data
/// with a section left empty. A `songs` problem is not one: it only means
/// fewer songs to match by.
Set<String> unreadableParts(BackupContents backup) => {
  for (final problem in _objects(backup.data['problems']))
    if (_string(problem['section']) case final section?
        when _restorableSections.contains(section))
      section,
};

/// What [matcher] is asked about an entry at [path] that may name a song of
/// the document: the song's own record when it does, which carries its tags
/// as the library had them, and otherwise the entry itself.
Map<String, Object?> _probe(
  Map<String, Object?> entry,
  String path,
  Map<String, Map<String, Object?>> songs,
) {
  final song = songs[entry['songId']];

  return song == null ? entry : {...song, 'path': path};
}

Map<String, Map<String, Object?>> _songsById(Map<String, Object?> data) => {
  for (final song in _objects(data['songs'])) ?_string(song['id']): song,
};

/// The objects in [value], when it is a list; anything else in it is passed
/// over.
Iterable<Map<String, Object?>> _objects(Object? value) sync* {
  if (value is! List) return;
  for (final item in value) {
    if (item is Map) yield Map<String, Object?>.from(item);
  }
}

String? _string(Object? value) => value is String ? value : null;

DateTime? _time(Object? value) =>
    value is String ? DateTime.tryParse(value)?.toUtc() : null;

Duration? _duration(Object? value) =>
    value is int ? Duration(milliseconds: value) : null;

/// The dates in [value], oldest first; any that do not parse are passed over.
List<DateTime> _dates(Object? value) => List.unmodifiable(
  [
    if (value is List)
      for (final item in value) ?_time(item),
  ]..sort(),
);
