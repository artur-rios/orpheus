import '../../library/domain/music_entry.dart';
import 'autofill_field.dart';
import 'batch_plan.dart';
import 'matching.dart';
import 'metadata_source.dart';
import 'proposals.dart';
import 'release.dart';

/// Why a lookup is kept for the owner instead of being written.
enum DoubtReason {
  /// The search found no release.
  noMatch,

  /// The best release is not an official one.
  notOfficial,

  /// The best release is not called what the record is.
  differentAlbum,

  /// The best release is not by the record's artist, or the record names none.
  differentArtist,

  /// Some songs of the record found no track on the release.
  unmatchedSongs,

  /// Some songs found a track that is not plainly theirs.
  differentSongs,

  /// Some songs of the record are not written — left out of the batch, or of
  /// a format no tag is written to — and writing the rest would give them an
  /// album or album artist those songs do not have.
  wouldSplitAlbum,

  /// The recording found for a lone track is not surely the song.
  uncertainTrack,
}

/// Whether a lookup is sure enough to be written without the owner looking.
sealed class Confidence {
  /// Creates an answer.
  const Confidence();
}

/// Sure enough: the tags are written without being reviewed.
final class Confident extends Confidence {
  /// Creates the answer.
  const Confident();
}

/// Not sure enough: the lookup is kept for the owner to review.
final class Doubtful extends Confidence {
  /// Creates the answer, with how many songs it is about where that applies.
  const Doubtful(this.reason, {this.count = 0});

  /// Which rule failed.
  final DoubtReason reason;

  /// How many songs [reason] is about, or 0 where it is not about songs.
  final int count;
}

/// Whether the best release found for [unit] is surely its record, as the
/// design's section 4.3 says.
///
/// Five rules, checked in this order, the first that fails being the reason:
/// the release exists; it is official; its title equals the record's album;
/// its artist credit equals the record's album artist; every song of the
/// batch that can be written is assigned a track with the same title and, where
/// the song is numbered, the same disc and number; and, for a record some of
/// whose songs are not written — left out of the batch, or of a format no tag
/// is written to ([BatchUnit.hasAlbumMatesOutside]) — nothing proposed touches
/// album or album artist, which would split the album in two. Names are
/// compared once [normalised].
///
/// Conservative on purpose: a false doubt costs the owner a review, a false
/// confidence writes wrong tags unreviewed, so anything that cannot be
/// compared — no album, no artist, no title — is a doubt. A song that
/// [proposals] block as [ProposalBlock.unwritableFormat] or
/// [ProposalBlock.unsafeTags] is not going to be written, so it does not
/// decide, and the rest of the record is judged without it.
Confidence recordConfidence(
  BatchUnit unit, {
  required ReleaseQuery query,
  required ReleaseDetail? release,
  required Map<MusicEntry, ReleaseTrack?> assignment,
  required List<FileProposal> proposals,
}) {
  if (release == null) return const Doubtful(DoubtReason.noMatch);

  final candidate = release.release;
  if (candidate.status?.toLowerCase() != 'official') {
    return const Doubtful(DoubtReason.notOfficial);
  }
  if (!_sameName(candidate.title, query.album)) {
    return const Doubtful(DoubtReason.differentAlbum);
  }
  if (!_sameName(candidate.artist, query.artist)) {
    return const Doubtful(DoubtReason.differentArtist);
  }

  final notWritten = {
    for (final proposal in proposals)
      if (proposal.blockedBecause == ProposalBlock.unwritableFormat ||
          proposal.blockedBecause == ProposalBlock.unsafeTags)
        proposal.entry.file.path,
  };
  final trackOf = {
    for (final MapEntry(:key, :value) in assignment.entries)
      key.file.path: value,
  };
  final judged = [
    for (final song in unit.songs)
      if (!notWritten.contains(song.file.path)) song,
  ];
  // A record with nothing left to write is nothing to be sure about.
  if (judged.isEmpty) return const Doubtful(DoubtReason.unmatchedSongs);

  final unmatched = judged
      .where((song) => trackOf[song.file.path] == null)
      .length;
  if (unmatched > 0) {
    return Doubtful(DoubtReason.unmatchedSongs, count: unmatched);
  }

  final different = judged
      .where((song) => !_isTheSong(song, trackOf[song.file.path]!))
      .length;
  if (different > 0) {
    return Doubtful(DoubtReason.differentSongs, count: different);
  }

  final changesTheAlbum = proposals.any(
    (proposal) => proposal.changes.any(
      (change) =>
          change.field == AutofillField.album ||
          change.field == AutofillField.albumArtist,
    ),
  );
  if (unit.hasAlbumMatesOutside && changesTheAlbum) {
    return const Doubtful(DoubtReason.wouldSplitAlbum);
  }

  return const Confident();
}

/// Whether [match], found for the lone track [song], is surely the song, and
/// [appearance] surely the record to file it under, as the design's section 4.3
/// says.
///
/// The recording's title and artist credit equal the song's, once
/// [normalised]; its length is within 3 seconds of the song's, an unknown
/// length on either side being a doubt; and the release is official, of
/// primary type album and not a compilation, since the album, its numbers, the
/// year and the cover all come from it. Anything less is
/// [DoubtReason.uncertainTrack].
Confidence trackConfidence(
  MusicEntry song, {
  required RecordingMatch? match,
  required RecordingAppearance? appearance,
}) {
  const doubtful = Doubtful(DoubtReason.uncertainTrack);
  if (match == null || appearance == null) return doubtful;

  if (!_sameName(match.title, song.title)) return doubtful;
  if (!_sameName(creditedName(match.artistCredit), song.artist)) {
    return doubtful;
  }

  final wanted = song.duration;
  final found = match.length;
  if (wanted == null || found == null) return doubtful;
  if ((wanted - found).abs() > const Duration(seconds: 3)) return doubtful;

  final release = appearance.release;
  final compilation = release.secondaryTypes.any(
    (type) => type.toLowerCase() == 'compilation',
  );
  if (release.status?.toLowerCase() != 'official' ||
      release.primaryType?.toLowerCase() != 'album' ||
      compilation) {
    return doubtful;
  }

  return const Confident();
}

/// Whether [found] and [wanted] are one name once [normalised].
///
/// Never so for a missing name, nor for one that normalises to nothing: two
/// names with no letter or number to compare are not evidence of anything.
bool _sameName(String found, String? wanted) {
  if (wanted == null) return false;

  final name = normalised(found);

  return name.isNotEmpty && name == normalised(wanted);
}

/// Whether [track] is plainly [song]: the same title, and the same disc and
/// number wherever the song carries either.
///
/// A song with a number or a disc is held to both, a missing disc counting as
/// the first as the library orders it; a song with neither has only its title
/// to go by.
bool _isTheSong(MusicEntry song, ReleaseTrack track) {
  if (!_sameName(track.title, song.title)) return false;

  final number = song.metadata.track;
  final disc = song.metadata.disc;
  if (number == null && disc == null) return true;

  return (number == null || number == track.position) &&
      (disc ?? 1) == track.disc;
}
