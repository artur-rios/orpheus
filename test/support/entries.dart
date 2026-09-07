import 'package:orpheus/features/library/domain/audio_file.dart';
import 'package:orpheus/features/library/domain/music_entry.dart';
import 'package:orpheus/features/library/domain/track_metadata.dart';

/// An entry whose file name is deliberately unlike its title.
///
/// A grouping, a queue or a row that fell back to the name on disk would be
/// visible in the assertions rather than hidden by a fixture that named the
/// file after the song.
MusicEntry entry({
  required String id,
  String? title,
  String? artist,
  String? albumArtist,
  String? album,
  int? track,
  int? disc,
  int? year,
  String? coverId,
  Duration? duration,
  String directory = defaultLibraryDirectory,
}) => MusicEntry(
  file: file(id, directory: directory),
  metadata: TrackMetadata(
    title: title,
    artist: artist,
    albumArtist: albumArtist,
    album: album,
    track: track,
    disc: disc,
    year: year,
    coverId: coverId,
    duration: duration,
  ),
);

/// The folder the fixtures sit in unless a test says otherwise.
///
/// Named because the folder is part of what identifies a record — see
/// `albumArtistsAcross` — so a test about two records that share a title has
/// to be able to put them in two places, exactly as a real library would.
const String defaultLibraryDirectory = '/library';

/// A file at a deterministic path, named nothing like anything it holds.
AudioFile file(String id, {String directory = defaultLibraryDirectory}) =>
    AudioFile(
      path: '$directory/zzz-$id.flac',
      sizeInBytes: 1024,
      modifiedAt: DateTime.utc(2026),
    );
