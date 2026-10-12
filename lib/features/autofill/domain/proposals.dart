import 'dart:typed_data';

import '../../library/domain/music_entry.dart';
import 'autofill_field.dart';
import 'release.dart';
import 'tag_writer.dart';

/// One tag's proposed change.
class FieldChange {
  /// Creates a change.
  const FieldChange({
    required this.field,
    required this.before,
    required this.after,
    this.accepted = true,
  });

  /// Which tag.
  final AutofillField field;

  /// What the file holds now, or `null` for nothing.
  final Object? before;

  /// What it would hold.
  final Object? after;

  /// Whether the owner has left it ticked.
  final bool accepted;

  /// This change, ticked or not.
  FieldChange withAccepted(bool accepted) =>
      FieldChange(field: field, before: before, after: after, accepted: accepted);
}

/// Why a file has nothing proposed for it.
enum ProposalBlock {
  /// Its format cannot be written.
  unwritableFormat,

  /// Its format can be written, but not its tags: they could not be read, or
  /// are of a shape the writer leaves alone rather than risk.
  unsafeTags,

  /// The release has no track it matched.
  noMatch,
}

/// Everything proposed for one file.
class FileProposal {
  /// Creates a proposal.
  const FileProposal({
    required this.entry,
    this.track,
    this.blockedBecause,
    this.changes = const [],
    this.notWritable = const {},
  });

  /// The file, as the library knows it.
  final MusicEntry entry;

  /// The release track it was matched to.
  final ReleaseTrack? track;

  /// Why nothing is proposed, where nothing is.
  final ProposalBlock? blockedBecause;

  /// The changes, in the order the fields are declared.
  final List<FieldChange> changes;

  /// Chosen fields this file's format cannot hold.
  final Set<AutofillField> notWritable;

  /// How many changes are ticked.
  int get acceptedCount => changes.where((change) => change.accepted).length;

  /// This proposal with [changes] in place of its own.
  FileProposal withChanges(List<FieldChange> changes) => FileProposal(
    entry: entry,
    track: track,
    blockedBecause: blockedBecause,
    changes: changes,
    notWritable: notWritable,
  );
}

/// The changes [release] proposes for every file in [assignment].
///
/// Only real changes are listed: a value equal to the current one once both
/// are trimmed is left out, so the screen shows nothing that would not change.
/// Case is not ignored — `radiohead` → `Radiohead` is a change an owner may
/// want — except in a genre, which MusicBrainz only ever spells in lower
/// case. A value is compared whole: a file holding `Rock; Pop` is changed by
/// `rock`, which a write would leave as its only genre. [tags] holds what
/// each file says now, by path; [fallbackGenres] are
/// the release group's, used where the release has none; [cover] is the
/// release's front cover, where the owner chose it and one was found.
List<FileProposal> proposalsFor({
  required Map<MusicEntry, ReleaseTrack?> assignment,
  required ReleaseDetail release,
  required Set<AutofillField> fields,
  required Map<String, FileTags> tags,
  List<Genre> fallbackGenres = const [],
  Uint8List? cover,
}) {
  final genre = (release.genres.isNotEmpty ? release.genres : fallbackGenres)
      .firstOrNull
      ?.name;

  return [
    for (final MapEntry(key: entry, value: track) in assignment.entries)
      _proposalFor(
        entry,
        track,
        release: release,
        fields: fields,
        current: tags[entry.file.path] ?? FileTags.unwritable,
        genre: genre,
        cover: cover,
      ),
  ];
}

FileProposal _proposalFor(
  MusicEntry entry,
  ReleaseTrack? track, {
  required ReleaseDetail release,
  required Set<AutofillField> fields,
  required FileTags current,
  required String? genre,
  required Uint8List? cover,
}) {
  if (current.writable.isEmpty) {
    return FileProposal(
      entry: entry,
      track: track,
      blockedBecause: canWriteTagsTo(entry.file.path) ? ProposalBlock.unsafeTags : ProposalBlock.unwritableFormat,
    );
  }
  if (track == null) {
    return FileProposal(entry: entry, blockedBecause: ProposalBlock.noMatch);
  }

  final proposed = <AutofillField, Object?>{
    AutofillField.title: track.title,
    AutofillField.artist: track.artist,
    AutofillField.albumArtist: release.release.artist,
    AutofillField.album: release.release.title,
    AutofillField.trackNumber: track.position,
    AutofillField.trackTotal: release.tracksOnDisc(track.disc),
    AutofillField.discNumber: track.disc,
    AutofillField.discTotal: release.discCount,
    AutofillField.year: release.release.year,
    AutofillField.genre: genre,
    AutofillField.cover: cover,
  };

  final changes = <FieldChange>[];
  final notWritable = <AutofillField>{};

  for (final field in AutofillField.values) {
    if (!fields.contains(field)) continue;
    if (!current.writable.contains(field)) {
      notWritable.add(field);
      continue;
    }

    final after = proposed[field];
    // Nothing to propose — no genre anywhere, no year, no cover — is not a
    // proposal to remove what the file has.
    if (after == null || (after is String && after.trim().isEmpty)) continue;

    final before = field == AutofillField.cover ? current.cover : current.values[field];
    if (_same(before, after)) continue;
    // MusicBrainz spells every genre in lower case, so a file's "Rock" is
    // already its rock. A genre that is new is written as MusicBrainz spells
    // it.
    if (field == AutofillField.genre &&
        before is String &&
        after is String &&
        before.trim().toLowerCase() == after.trim().toLowerCase()) {
      continue;
    }

    changes.add(FieldChange(field: field, before: before, after: after));
  }

  return FileProposal(entry: entry, track: track, changes: changes, notWritable: notWritable);
}

bool _same(Object? before, Object? after) {
  if (before is String && after is String) return before.trim() == after.trim();
  if (before is Uint8List && after is Uint8List) {
    if (before.length != after.length) return false;
    for (var i = 0; i < before.length; i++) {
      if (before[i] != after[i]) return false;
    }

    return true;
  }

  return before == after;
}
