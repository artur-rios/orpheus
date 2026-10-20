import 'dart:typed_data';

import 'package:logging/logging.dart';

import '../domain/autofill_field.dart';
import '../domain/metadata_source.dart';
import '../domain/proposals.dart';
import '../domain/release.dart';

final Logger _log = Logger('autofill');

/// A release with the extras the chosen tags need.
class FetchedRelease {
  /// Creates a fetched release.
  const FetchedRelease({
    required this.detail,
    this.fallbackGenres = const [],
    this.cover,
    this.coverUnavailable = false,
  });

  /// The release and its tracks.
  final ReleaseDetail detail;

  /// The release group's genres, where genre was chosen and the release has
  /// none of its own.
  final List<Genre> fallbackGenres;

  /// The front cover, where cover was chosen and the release has one.
  final Uint8List? cover;

  /// Whether the cover was chosen and could not be downloaded: the release
  /// may well have one.
  final bool coverUnavailable;
}

/// The release [releaseId] and what [fields] ask of it besides its tracks.
///
/// The release group's genres are fetched when genre is chosen and the release
/// has none; the front cover when cover is chosen. Either failing leaves the
/// other changes standing, so only the lookup of the release itself throws a
/// [MetadataSourceException].
Future<FetchedRelease> fetchRelease(
  MetadataSource source,
  String releaseId,
  Set<AutofillField> fields,
) async {
  final detail = await source.release(releaseId);

  var fallback = const <Genre>[];
  final groupId = detail.releaseGroupId;
  if (fields.contains(AutofillField.genre) &&
      detail.genres.isEmpty &&
      groupId != null) {
    try {
      fallback = await source.releaseGroupGenres(groupId);
    } on MetadataSourceException catch (error) {
      // A stand-in that could not be fetched is no genre to propose, not a
      // release that cannot be: the other changes stand.
      _log.info('the release group genres could not be fetched', error);
    }
  }

  Uint8List? cover;
  var coverUnavailable = false;
  if (fields.contains(AutofillField.cover)) {
    try {
      cover = await source.frontCover(releaseId);
    } on MetadataSourceException catch (error) {
      // Not "no cover": the owner is told it could not be downloaded, and can
      // look the release up again for another try.
      _log.info('the cover could not be fetched', error);
      coverUnavailable = true;
    }
  }

  return FetchedRelease(
    detail: detail,
    fallbackGenres: fallback,
    cover: cover,
    coverUnavailable: coverUnavailable,
  );
}

/// [proposals] with the one for [playingPath] moved last.
///
/// On Windows the player holds the playing file open and the write may be
/// refused, so everything else should be done by then.
List<FileProposal> playingLast(
  List<FileProposal> proposals,
  String? playingPath,
) => [
  ...proposals.where((p) => p.entry.file.path != playingPath),
  ...proposals.where((p) => p.entry.file.path == playingPath),
];
