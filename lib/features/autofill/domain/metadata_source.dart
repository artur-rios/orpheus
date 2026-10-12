import 'dart:typed_data';

import 'release.dart';

/// What to look a record up by.
class ReleaseQuery {
  /// Creates a query.
  const ReleaseQuery({this.album, this.artist, this.text});

  /// The record's title.
  final String? album;

  /// The record's artist.
  final String? artist;

  /// The owner's own words, which replace the two fields above when given.
  final String? text;
}

/// What to look a lone track up by.
class RecordingQuery {
  /// Creates a query.
  const RecordingQuery({this.title, this.artist, this.duration, this.text});

  /// The track's title.
  final String? title;

  /// The track's artist.
  final String? artist;

  /// How long the file is, which narrows the search to recordings of about
  /// that length.
  final Duration? duration;

  /// The owner's own words, which replace the fields above when given.
  final String? text;
}

/// Why a lookup could not run.
enum MetadataSourceFailure {
  /// No network, a timeout, or the service answering with an error.
  unreachable,

  /// The service asked for fewer requests, and kept asking.
  rateLimited,

  /// The service answered with something that could not be read.
  malformed,
}

/// A lookup that could not run.
class MetadataSourceException implements Exception {
  /// Creates the exception.
  const MetadataSourceException(this.kind);

  /// Why.
  final MetadataSourceFailure kind;

  @override
  String toString() => 'MetadataSourceException(${kind.name})';
}

/// Where proposed tags come from.
///
/// An interface for the usual reason — nothing in the suite reaches a network
/// — and for one more: identifying a file by its sound would be a second
/// implementation of this, not a change to anything that uses it.
abstract interface class MetadataSource {
  /// Releases that match [query], at most ten, in the service's own order.
  Future<List<ReleaseCandidate>> searchReleases(ReleaseQuery query);

  /// The release [id] in full.
  Future<ReleaseDetail> release(String id);

  /// The genres of the release group [id], most voted first.
  Future<List<Genre>> releaseGroupGenres(String id);

  /// Recordings that match [query], at most ten.
  Future<List<RecordingMatch>> searchRecordings(RecordingQuery query);

  /// The front cover of release [releaseId], or `null` where it has none.
  ///
  /// Throws a [MetadataSourceException] where it could not be downloaded —
  /// which is not the same as there being none.
  Future<Uint8List?> frontCover(String releaseId);
}
