/// One name in a credit, and what joins it to the next.
///
/// MusicBrainz credits a track to "Queen & David Bowie" as two artists and a
/// join phrase, and the phrase is part of how the credit reads.
class ArtistCredit {
  /// Creates a credit.
  const ArtistCredit({required this.name, this.joinPhrase = ''});

  /// The name as credited here.
  final String name;

  /// What follows it before the next name, or nothing for the last.
  final String joinPhrase;
}

/// [credits] as one line, the way MusicBrainz writes it.
String creditedName(List<ArtistCredit> credits) =>
    credits.map((credit) => '${credit.name}${credit.joinPhrase}').join().trim();

/// A release as a search answers it — enough to rank it and to show it, not
/// yet its tracks.
class ReleaseCandidate {
  /// Creates a candidate.
  const ReleaseCandidate({
    required this.id,
    required this.title,
    required this.artistCredit,
    required this.trackCount,
    this.date,
    this.country,
    this.status,
    this.primaryType,
    this.secondaryTypes = const [],
    this.format,
    this.disambiguation,
    this.score = 0,
  });

  /// Its MusicBrainz id.
  final String id;

  /// Its title.
  final String title;

  /// Who it is credited to.
  final List<ArtistCredit> artistCredit;

  /// How many tracks it has, across every disc.
  final int trackCount;

  /// When it was released, as MusicBrainz writes it: `1997`, `1997-05` or
  /// `1997-05-21`.
  final String? date;

  /// Where it was released.
  final String? country;

  /// `Official`, `Promotion`, `Bootleg` or `Pseudo-Release`.
  final String? status;

  /// `Album`, `Single`, `EP`, `Broadcast` or `Other`.
  final String? primaryType;

  /// `Compilation`, `Live`, `Remix` and the like.
  final List<String> secondaryTypes;

  /// The first medium's format: `CD`, `Digital Media`, `12" Vinyl`…
  final String? format;

  /// What tells it apart from releases of the same name: "2011 remaster".
  final String? disambiguation;

  /// How well the search thinks it matched, 0 to 100.
  final int score;

  /// Who it is credited to, as one line.
  String get artist => creditedName(artistCredit);

  /// The year of [date], or `null` where there is none to read.
  int? get year {
    final value = date;
    if (value == null || value.length < 4) return null;

    return int.tryParse(value.substring(0, 4));
  }
}

/// One track of a release.
class ReleaseTrack {
  /// Creates a track.
  const ReleaseTrack({
    required this.disc,
    required this.position,
    required this.title,
    required this.artistCredit,
    this.length,
    this.recordingId,
  });

  /// Which disc it is on, from 1.
  final int disc;

  /// Where on that disc, from 1.
  final int position;

  /// Its title on this release.
  final String title;

  /// Who it is credited to on this release.
  final List<ArtistCredit> artistCredit;

  /// How long it is, where MusicBrainz knows.
  final Duration? length;

  /// The recording it is, which is what a lone track was matched by.
  final String? recordingId;

  /// Who it is credited to, as one line.
  String get artist => creditedName(artistCredit);
}

/// A genre and how many people voted for it.
class Genre {
  /// Creates a genre.
  const Genre({required this.name, this.votes = 0});

  /// Its name, as MusicBrainz spells it: lower case.
  final String name;

  /// How many votes it has.
  final int votes;
}

/// A release in full: its tracks and its genres.
class ReleaseDetail {
  /// Creates the detail.
  const ReleaseDetail({
    required this.release,
    required this.tracks,
    this.genres = const [],
    this.releaseGroupId,
  });

  /// The release itself.
  final ReleaseCandidate release;

  /// Every track, disc by disc, in order.
  final List<ReleaseTrack> tracks;

  /// Its genres, most voted first.
  final List<Genre> genres;

  /// The release group it belongs to, whose genres stand in where it has none.
  final String? releaseGroupId;

  /// How many discs it has.
  int get discCount => tracks.isEmpty
      ? 1
      : tracks.map((track) => track.disc).reduce((a, b) => a > b ? a : b);

  /// How many tracks disc [disc] has.
  int tracksOnDisc(int disc) =>
      tracks.where((track) => track.disc == disc).length;
}

/// Where a recording appears: a release, and its place on it.
class RecordingAppearance {
  /// Creates an appearance.
  const RecordingAppearance({
    required this.release,
    required this.disc,
    required this.position,
  });

  /// The release.
  final ReleaseCandidate release;

  /// The disc it is on.
  final int disc;

  /// Its place on that disc.
  final int position;
}

/// A recording a lone track was matched to.
class RecordingMatch {
  /// Creates a match.
  const RecordingMatch({
    required this.recordingId,
    required this.title,
    required this.artistCredit,
    required this.appearances,
    this.length,
    this.score = 0,
  });

  /// Its MusicBrainz id.
  final String recordingId;

  /// Its title.
  final String title;

  /// Who it is credited to.
  final List<ArtistCredit> artistCredit;

  /// Every release it appears on.
  final List<RecordingAppearance> appearances;

  /// How long it is, where known.
  final Duration? length;

  /// How well the search thinks it matched, 0 to 100.
  final int score;
}
