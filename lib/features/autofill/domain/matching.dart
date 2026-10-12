import 'package:path/path.dart' as p;

import '../../library/domain/music_entry.dart';
import 'metadata_source.dart';
import 'release.dart';

/// [value] reduced to what two spellings of one name have in common.
///
/// Lower case, accents folded to their letters, typographic quotes and every
/// other piece of punctuation dropped, and runs of space collapsed: `Sigur
/// Rós` and `sigur ros` are one band, and `Don’t` and `Don't` one song.
String normalised(String value) {
  final folded = StringBuffer();
  for (final rune in value.toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    folded.write(_folds[char] ?? char);
  }

  return folded
      .toString()
      .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

const Map<String, String> _folds = {
  'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a',
  'ç': 'c',
  'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
  'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
  'ñ': 'n',
  'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', 'ø': 'o',
  'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u',
  'ý': 'y', 'ÿ': 'y',
};

/// How closely [candidate] matches [wanted]: 2 equal, 1 one contains the
/// other, 0 neither — and 0 where nothing was wanted.
int _closeness(String? wanted, String candidate) {
  if (wanted == null || wanted.trim().isEmpty) return 0;

  final a = normalised(wanted);
  final b = normalised(candidate);
  if (a == b) return 2;
  if (a.isNotEmpty && b.isNotEmpty && (a.contains(b) || b.contains(a))) {
    return 1;
  }

  return 0;
}

int _statusRank(String? status) => switch (status?.toLowerCase()) {
  'official' => 0,
  'promotion' => 1,
  null => 2,
  _ => 3,
};

/// [candidates] best first, by what the search already said about them.
///
/// The order the spec gives, each key breaking the previous one's ties:
/// as many tracks as the owner has files, then an official release, then the
/// title, then the artist, then the service's own score, then the earliest
/// date, then the id — so the same answer always ranks the same way.
List<ReleaseCandidate> rankCandidates(
  List<ReleaseCandidate> candidates, {
  required int fileCount,
  String? album,
  String? artist,
}) {
  int compare(ReleaseCandidate a, ReleaseCandidate b) {
    final byCount = (b.trackCount == fileCount ? 1 : 0)
        .compareTo(a.trackCount == fileCount ? 1 : 0);
    if (byCount != 0) return byCount;

    final byStatus = _statusRank(a.status).compareTo(_statusRank(b.status));
    if (byStatus != 0) return byStatus;

    final byTitle = _closeness(album, b.title).compareTo(_closeness(album, a.title));
    if (byTitle != 0) return byTitle;

    final byArtist = _closeness(artist, b.artist).compareTo(_closeness(artist, a.artist));
    if (byArtist != 0) return byArtist;

    final byScore = b.score.compareTo(a.score);
    if (byScore != 0) return byScore;

    final byDate = (a.date ?? '9999').compareTo(b.date ?? '9999');
    if (byDate != 0) return byDate;

    return a.id.compareTo(b.id);
  }

  return [...candidates]..sort(compare);
}

int _typeRank(ReleaseCandidate release) {
  if (release.secondaryTypes.any((type) => type.toLowerCase() == 'compilation')) {
    return 3;
  }

  return switch (release.primaryType?.toLowerCase()) {
    'album' => 0,
    'ep' => 1,
    'single' => 2,
    _ => 2,
  };
}

/// Every place the recordings in [matches] appear, best first.
///
/// For a lone track the question is which record to file it under, and the
/// answer an owner expects is the album it was released on: an official
/// album before an EP or a single, a compilation last, and the earliest of
/// equals.
List<RecordingAppearance> rankAppearances(
  List<RecordingMatch> matches, {
  String? title,
  String? artist,
}) {
  final scored = [
    for (final match in matches)
      for (final appearance in match.appearances)
        (match: match, appearance: appearance),
  ];

  scored.sort((a, b) {
    final byTitle = _closeness(title, b.match.title)
        .compareTo(_closeness(title, a.match.title));
    if (byTitle != 0) return byTitle;

    final byArtist = _closeness(artist, creditedName(b.match.artistCredit))
        .compareTo(_closeness(artist, creditedName(a.match.artistCredit)));
    if (byArtist != 0) return byArtist;

    final byStatus = _statusRank(a.appearance.release.status)
        .compareTo(_statusRank(b.appearance.release.status));
    if (byStatus != 0) return byStatus;

    final byType = _typeRank(a.appearance.release)
        .compareTo(_typeRank(b.appearance.release));
    if (byType != 0) return byType;

    final byDate = (a.appearance.release.date ?? '9999')
        .compareTo(b.appearance.release.date ?? '9999');
    if (byDate != 0) return byDate;

    return a.appearance.release.id.compareTo(b.appearance.release.id);
  });

  return [for (final item in scored) item.appearance];
}

/// The commonest non-blank value among [values], or `null` for none.
String? _commonest(Iterable<String?> values) {
  final counts = <String, int>{};
  for (final value in values) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) continue;
    counts.update(trimmed, (count) => count + 1, ifAbsent: () => 1);
  }
  if (counts.isEmpty) return null;

  final ranked = counts.entries.toList()
    ..sort((a, b) {
      final byCount = b.value.compareTo(a.value);
      return byCount != 0 ? byCount : a.key.compareTo(b.key);
    });

  return ranked.first.key;
}

/// What to search for a record made of [entries] by.
///
/// The commonest album and album artist across them, so one mis-tagged track
/// does not steer the search; the folder's name where nothing is tagged.
ReleaseQuery releaseQueryFor(List<MusicEntry> entries) => ReleaseQuery(
  album:
      _commonest(entries.map((entry) => entry.album)) ??
      _commonest(entries.map((entry) => p.basename(entry.file.directory))),
  artist: _commonest(entries.map((entry) => entry.albumArtist)),
);

/// What to search for the lone track [entry] by.
///
/// Its title, or its file name without the extension and any leading track
/// number (`03 - Lucky.flac` → `Lucky`) where it has none.
RecordingQuery recordingQueryFor(MusicEntry entry) => RecordingQuery(
  title:
      entry.title ??
      p
          .basenameWithoutExtension(entry.file.path)
          .replaceFirst(RegExp(r'^\s*\d+\s*[-._)\]]*\s*'), '')
          .trim(),
  artist: entry.artist,
  duration: entry.duration,
);
