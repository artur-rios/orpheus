import 'dart:io';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import '../domain/lyrics.dart';
import '../domain/lyrics_source.dart';
import 'id3_synced_lyrics.dart';
import 'lrc_parsing.dart';

/// [LyricsSource] over what is already on the machine.
///
/// Two places, in this order:
///
/// 1. A `.lrc` file beside the track, named after it — `airbag.flac` and
///    `airbag.lrc`. This is where every tool that writes synced lyrics puts
///    them, and it is the one an owner can add to, correct, or delete with a
///    text editor and no help from this application.
/// 2. The track's own `SYLT` frame — ID3's synchronised lyrics, where a time
///    and a piece of text are written as structure rather than as text. It is
///    read straight out of the file's header by [parseId3SyncedLyrics].
/// 3. The track's own lyrics text tag — `USLT` in an MP3, `©lyr` in an MP4,
///    `LYRICS` in a Vorbis comment or an APE tag. Often plain words, and
///    sometimes LRC pasted into the tag, which is why the same parser reads
///    that and the sidecar.
///
/// The sidecar wins over both, deliberately: it is the one of the three the
/// owner can change without a tag editor, and a person who has written a
/// `.lrc` for a track has said what they want that track's words to be. `SYLT`
/// then comes before the text tag because it is the frame that carries times —
/// a file with both is a file whose writer put the timed copy in `SYLT` and
/// the readable one in `USLT`.
class FileLyricsSource implements LyricsSource {
  /// Creates the source.
  const FileLyricsSource();

  /// What a sidecar is called.
  static const String sidecarExtension = '.lrc';

  static final Logger _log = Logger('lyrics');

  @override
  Future<Lyrics?> of(String path) async {
    final sidecar = await _sidecarBeside(path);
    if (sidecar != null) {
      final lyrics = parseLrc(sidecar);
      if (lyrics != null) return lyrics;
    }

    return await _syncedFrameIn(path) ?? await _embeddedIn(path);
  }

  /// What the `.lrc` beside the track at [path] says, or `null` where there is
  /// none.
  ///
  /// Two probes rather than a listing of the folder: a folder of a thousand
  /// files would be walked for every track the player opened, and the only
  /// spellings worth covering are the two that occur — the extension as
  /// written by tools, and the one shouted by a file system that came from a
  /// case-insensitive machine.
  Future<String?> _sidecarBeside(String path) async {
    final base = p.withoutExtension(path);

    for (final extension in const [sidecarExtension, '.LRC']) {
      final file = File('$base$extension');
      if (!file.existsSync()) continue;

      try {
        return await file.readAsString();
      } on Object catch (error) {
        // A sidecar that is there but unreadable — a permission, a bad
        // encoding — is not a failure the owner needs a dialog about. It is a
        // track whose words fall back to its tags. Broad, like every other
        // read of a file the owner wrote in this application.
        _log.fine('could not read the lyrics beside $path', error);
      }
    }

    return null;
  }

  /// What the track at [path] carries in its `SYLT` frame, or `null` for a
  /// file with no ID3 tag, no such frame, or one this cannot use.
  ///
  /// Read here rather than through the tag reader the rest of the application
  /// uses: that reader surfaces `USLT` and stops, and `USLT` is by definition
  /// the copy with no times in it. Only the tag itself is read — its own
  /// header says how long it is, and nothing past it is touched.
  Future<Lyrics?> _syncedFrameIn(String path) async {
    final file = File(path);
    if (!file.existsSync()) return null;

    RandomAccessFile? handle;
    try {
      handle = await file.open();
      final length = id3TagLengthOf(await handle.read(id3HeaderLength));
      if (length == null) return null;

      await handle.setPosition(0);

      // Never past the end of the file: a truncated download states a length
      // its bytes do not reach, and reading what is there is what lets the
      // frames before the truncation still be read.
      final fileLength = await handle.length();

      return parseId3SyncedLyrics(
        await handle.read(length < fileLength ? length : fileLength),
      );
    } on Object catch (error) {
      // Broad by intent, as it is where the scanner reads the same files: a
      // malformed header does not politely throw a `FileSystemException`, it
      // walks off the end of a byte list and throws a `RangeError` — an
      // `Error`, which a narrower catch here let past and turned into a lyrics
      // panel showing a failure for a track that simply has no words.
      _log.fine('could not read the tag of $path for synced lyrics', error);

      return null;
    } finally {
      await handle?.close();
    }
  }

  /// What the track at [path] carries in its own text tags, or `null` for a
  /// file that carries none.
  ///
  /// Read here rather than taken from the catalog, and that is a size
  /// decision: the whole words of every track would be several times the rest
  /// of the catalog document put together, held in memory for the life of the
  /// application, to show one track's worth at a time. The player asks for one
  /// track, when it is opened, and the controller keeps that.
  Future<Lyrics?> _embeddedIn(String path) async {
    final file = File(path);
    if (!file.existsSync()) return null;

    final String? words;
    try {
      // Without the picture: this is the one read where the sleeve is
      // certainly not wanted, and skipping it is the difference between
      // parsing a header and parsing a header plus a megabyte of JPEG.
      words = switch (readAllMetadata(file, getImage: false)) {
        Mp3Metadata(:final lyric) => lyric,
        Mp4Metadata(:final lyrics) => lyrics,
        VorbisMetadata(:final lyric) => lyric,
        ApeMetadata(:final lyric) => lyric,
        // RIFF carries no lyrics field at all.
        RiffMetadata() => null,
      };
    } on Object catch (error) {
      // The same judgement — and the same breadth — the scanner makes about a
      // file whose tags will not parse: it is very often a file that plays
      // perfectly well, it is certainly not one to interrupt playback over,
      // and what a truncated tag actually throws is as often an `Error` as an
      // `Exception`.
      _log.fine('could not read the tags of $path for lyrics', error);

      return null;
    }

    return words == null || words.trim().isEmpty ? null : parseLrc(words);
  }
}
