import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../library/domain/audio_file.dart';
import '../../library/domain/music_catalog.dart';
import '../../library/domain/music_entry.dart';
import '../../library/domain/music_grouping.dart';
import '../domain/playback_queue.dart';

/// The metadata-first naming rule and its Unknown fallbacks, in one place so
/// the views and the search results cannot disagree.
///
/// Everything here answers the same question — what does this track, artist,
/// album or queue get called — from a [MusicEntry] or a [PlaybackQueue], and
/// never from a file's name on disk.

/// A tag, trimmed, or [whenAbsent] for a file whose tags carry none.
///
/// The one place a blank or absent tag becomes a word, so nothing that names a
/// track has to remember the rule itself. That is what keeps "never the file
/// name" one rule instead of one remembered at every call site.
String tagOr(String? value, String whenAbsent) =>
    trimmedOrNull(value) ?? whenAbsent;

/// A track's title, or the word for a file whose tags carry none.
String musicTitleOf(MusicEntry entry, AppLocalizations l10n) =>
    tagOr(entry.metadata.title, l10n.musicUnknownTitle);

/// A track's performer, or the word for a file whose tags carry none.
String musicArtistOf(MusicEntry entry, AppLocalizations l10n) =>
    tagOr(entry.metadata.artist, l10n.musicUnknownArtist);

/// The artist the record is by, or the word for a file whose tags carry none.
///
/// Not [musicArtistOf]: that names who played the track, which is what a track
/// row shows; this names whose record it is, which is what the browsing area
/// groups by.
String musicAlbumArtistOf(MusicEntry entry, AppLocalizations l10n) =>
    tagOr(entry.albumArtist, l10n.musicUnknownArtist);

/// A track's own album tag, or the word for a file whose tags carry none.
///
/// Not [musicTitleOf]: a track's title is its own name, and its album is the
/// record it belongs to — two different tags that share a fallback word only
/// by the coincidence of both being "unknown".
String musicAlbumOf(MusicEntry entry, AppLocalizations l10n) =>
    tagOr(entry.metadata.album, l10n.musicUnknownAlbum);

/// [file] read as a [MusicEntry], never by its name on disk.
///
/// Shared by the bar, the skip notice and the full player, so nothing that
/// names the file currently playing can disagree with what the browsing area
/// already agreed a track is called.
///
/// Watches the library, because playback is reachable without the music area
/// ever being opened — from the queue, from a search result — and nothing else
/// would otherwise start the read this entry is drawn from. While the library
/// is still loading, the file reads as untitled, which is what an entry with
/// no title does too.
MusicEntry musicEntryForFile(WidgetRef ref, AudioFile file) =>
    (ref.watch(musicLibraryControllerProvider).value ?? MusicCatalog.empty)
        .entryFor(file);

/// [file]'s title from its metadata, never its name on disk.
String musicTitleForFile(
  WidgetRef ref,
  AudioFile file,
  AppLocalizations l10n,
) => musicTitleOf(musicEntryForFile(ref, file), l10n);

/// [file]'s album artist from its metadata, never its name on disk.
String musicAlbumArtistForFile(
  WidgetRef ref,
  AudioFile file,
  AppLocalizations l10n,
) => musicAlbumArtistOf(musicEntryForFile(ref, file), l10n);

/// [file]'s own album tag from its metadata, never its name on disk.
String musicAlbumForFile(
  WidgetRef ref,
  AudioFile file,
  AppLocalizations l10n,
) => musicAlbumOf(musicEntryForFile(ref, file), l10n);

/// The queue's own name, or `null` when there is none to show.
///
/// `null` for a single track: the bar and the full player already show that
/// track's own title beside this label, so repeating it here would be noise
/// rather than information. For an album or an artist, an absent
/// [PlaybackQueue.label] means the *tag* is absent, so this reads through
/// [tagOr] to the same rule an absent album or artist tag gets everywhere else.
///
/// A shuffle-everything queue's label is not a tag at all — it is a phrase this
/// application wrote — so it is shown as it is, with no Unknown word behind it.
String? queueLabelOf(PlaybackQueue queue, AppLocalizations l10n) =>
    switch (queue.kind) {
      QueueKind.track => null,
      QueueKind.album => tagOr(queue.label, l10n.musicUnknownAlbum),
      QueueKind.artist => tagOr(queue.label, l10n.musicUnknownArtist),
      QueueKind.playlist => trimmedOrNull(queue.label),
    };

/// What a group of tracks is.
enum MusicGroupKind {
  /// An artist, which drills into their albums.
  artist,

  /// An album, which drills into its tracks.
  album,
}

/// A group's name, or the word for the files that name none.
String musicGroupName(
  MusicGroup group,
  AppLocalizations l10n, {
  required MusicGroupKind kind,
}) =>
    group.name ??
    switch (kind) {
      MusicGroupKind.artist => l10n.musicUnknownArtist,
      MusicGroupKind.album => l10n.musicUnknownAlbum,
    };

/// A duration as the players show it.
///
/// Shared between the bar, the player and the listings, because a position
/// written by one is offered by the other and reading differently would be two
/// answers to the same question.
String formatPlaybackPosition(Duration duration) {
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  final hours = duration.inHours;

  return hours == 0 ? '$minutes:$seconds' : '$hours:$minutes:$seconds';
}
