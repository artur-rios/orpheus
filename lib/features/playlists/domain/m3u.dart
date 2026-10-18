import 'package:path/path.dart' as p;

import '../../library/domain/music_entry.dart';
import 'playlist.dart';

/// [playlist] as an extended M3U document.
///
/// `#EXTM3U`, then for each entry, present or not, an `#EXTINF` line (the
/// length in seconds, a comma, then `artist - title`) and the file's absolute
/// path, every line ended by `\n`. The tags come from the catalog when the song
/// is in [catalogByPath] and from the entry's own snapshot when it is not; a
/// missing song is written all the same, so another player can decide what to
/// do about it. The result is text: encoding it as UTF-8 is the writer's job.
String playlistToM3u(Playlist playlist, Map<String, MusicEntry> catalogByPath) {
  final out = StringBuffer('#EXTM3U\n');
  for (final entry in playlist.entries) {
    final song = catalogByPath[entry.path];
    final title = song != null ? song.title : entry.title;
    final artist = song != null ? song.artist : entry.artist;
    final duration = song != null ? song.duration : entry.duration;
    final label = _label(artist, title) ?? p.basename(entry.path);
    out
      ..write('#EXTINF:${duration?.inSeconds ?? -1},')
      ..write(label)
      ..write('\n')
      ..write(entry.path)
      ..write('\n');
  }
  return out.toString();
}

/// `artist - title`, or whichever of them there is, kept to one line.
String? _label(String? artist, String? title) {
  final parts = [
    for (final part in [artist, title])
      if (trimmedOrNull(part) != null)
        trimmedOrNull(part)!.replaceAll(RegExp(r'\s*[\r\n]+\s*'), ' '),
  ];
  return parts.isEmpty ? null : parts.join(' - ');
}
