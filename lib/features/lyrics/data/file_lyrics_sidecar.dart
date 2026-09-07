import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import '../domain/lyrics_sidecar.dart';
import 'file_lyrics_source.dart';

/// [LyricsSidecar] that writes the `.lrc` next to the track.
///
/// The one writer in this application that puts a file anywhere but its own
/// support directory, and the rules it follows are what keep that defensible:
///
/// - It writes one file, `<track>.lrc`, in the folder the track is already in.
/// - It never touches the audio file. No tag is written, nothing is renamed,
///   and the track is not even opened.
/// - It never replaces a `.lrc` that is already there. A sidecar the owner
///   wrote, or one a previous lookup left, is the answer for that track; this
///   is only ever filling a gap.
/// - A refusal is reported, not thrown. Read-only mounts, network shares
///   mounted without write access and Android's scoped storage are all
///   ordinary conditions rather than faults, and none of them is a reason to
///   withhold words the panel already has in hand.
///
/// The write is atomic in the only sense that matters to a reader: the text
/// goes to a temporary file in the same folder and is renamed into place, so a
/// process killed mid-write leaves either no sidecar or a whole one, never a
/// half of one that the parser would read as a truncated sheet.
class FileLyricsSidecar implements LyricsSidecar {
  /// Creates the writer.
  const FileLyricsSidecar();

  static final Logger _log = Logger('lyrics');

  @override
  Future<bool> write(String path, String text) async {
    final base = p.withoutExtension(path);
    final target = File('$base${FileLyricsSource.sidecarExtension}');

    // Both spellings, matching what the reader probes for: writing `.lrc`
    // beside an existing `.LRC` on a case-sensitive file system would leave
    // two sheets for one track, and the reader would go on preferring the
    // other one.
    for (final extension in const [
      FileLyricsSource.sidecarExtension,
      '.LRC',
    ]) {
      if (File('$base$extension').existsSync()) return false;
    }

    // The temporary file carries the process id so that two Orpheus windows
    // over the same library — the same folder on a share, opened twice — do
    // not write through each other's half-written file.
    final scratch = File('$base.lrc.$pid.part');

    try {
      // UTF-8 without asking: it is what every writer of LRC produces now, it
      // is what the reader assumes, and it is the only encoding that can hold
      // the whole of what a lyrics service returns.
      await scratch.writeAsString(text, encoding: utf8, flush: true);
      await scratch.rename(target.path);

      return true;
    } on Object catch (error) {
      // Broad, and the breadth is the point: a folder on a read-only mount, a
      // share the owner has read access to and no more, and Android's sandbox
      // all refuse here, and none of them is a failure the owner needs a
      // dialog about. They get the words for this session and a lookup again
      // next launch.
      _log.fine('could not write the lyrics beside $path', error);

      // A rename that failed leaves the scratch file behind, and a stray
      // `.part` in somebody's music folder is exactly the kind of litter this
      // application promises not to leave.
      try {
        if (scratch.existsSync()) await scratch.delete();
      } on Object catch (error) {
        _log.fine('could not clean up after a refused lyrics write', error);
      }

      return false;
    }
  }
}
