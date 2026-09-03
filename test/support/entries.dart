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
}) => MusicEntry(
  file: file(id),
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

/// A file at a deterministic path, named nothing like anything it holds.
AudioFile file(String id) => AudioFile(
  path: '/library/zzz-$id.flac',
  sizeInBytes: 1024,
  modifiedAt: DateTime.utc(2026),
);
