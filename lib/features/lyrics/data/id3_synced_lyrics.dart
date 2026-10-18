import 'dart:typed_data';

import '../../library/data/id3v2_frames.dart';
import '../domain/lyrics.dart';

export '../../library/data/id3v2_frames.dart'
    show id3HeaderLength, id3TagLengthOf;

/// Reads the synchronised lyrics out of the ID3v2 tag at the start of [bytes],
/// or answers `null` where there are none to read.
///
/// `SYLT` is the one place in a tagged library where synced words are held as
/// *structure* rather than as text: a time and a piece of text, repeated, in
/// the file's own header. The tag reader this application uses for everything
/// else surfaces `USLT` — the unsynchronised frame — and nothing else, so this
/// walks the tag itself. It is a header parse of a few hundred bytes, it
/// touches nothing but the frame it came for, and it is pure Dart over a byte
/// list, which is what lets a test hand it a tag it built.
///
/// What it covers, because real files carry it: ID3v2.2, v2.3 and v2.4; the
/// four text encodings the format defines; unsynchronisation, whole-tag or per
/// frame; an extended header; and a data-length indicator. What it steps over,
/// answering `null` so that the caller falls back to the text frame: a
/// compressed or encrypted frame, a frame whose times are counted in MPEG
/// frames rather than milliseconds — there is no frame rate here to turn those
/// into a position — and a `SYLT` carrying something other than words, which
/// the format also allows it to carry.
Lyrics? parseId3SyncedLyrics(Uint8List bytes) {
  final tag = Id3v2Tag.of(bytes);
  if (tag == null) return null;

  for (final frame in tag.frames()) {
    if (!_isSyncedLyricsFrame(frame.id)) continue;

    final lyrics = _lyricsOfSyltFrame(frame.data);
    if (lyrics != null) return lyrics;
  }

  return null;
}

/// `SYLT` in ID3v2.3 and v2.4, and `SLT` in the three-letter ids of v2.2.
bool _isSyncedLyricsFrame(String id) => id == 'SYLT' || id == 'SLT';

/// The words in one `SYLT` frame's [data], or `null` where it holds none this
/// application can use.
Lyrics? _lyricsOfSyltFrame(Uint8List data) {
  // Encoding, language, time-stamp format, content type, then the descriptor.
  if (data.length < 7) return null;

  final encoding = data[0];
  final timestamps = data[4];
  final content = data[5];

  // 2 is milliseconds. 1 is MPEG frames, which is a position only if you know
  // the frame rate of the audio behind it — and this reads a header, not a
  // stream.
  if (timestamps != 2) return null;

  // 1 is lyrics and 2 is a transcription of them. The frame is also allowed to
  // carry movement names, chords and trivia, none of which is the words.
  if (content != 1 && content != 2) return null;

  final descriptor = _readString(data, 6, encoding);
  if (descriptor == null) return null;

  final entries = <({Duration at, String text})>[];
  var offset = descriptor.next;

  while (offset + 4 < data.length) {
    final text = _readString(data, offset, encoding);
    if (text == null) break;

    offset = text.next;
    if (offset + 4 > data.length) break;

    entries.add((
      at: Duration(
        milliseconds: ByteData.sublistView(
          data,
          offset,
          offset + 4,
        ).getUint32(0),
      ),
      text: text.value,
    ));
    offset += 4;
  }

  return entries.isEmpty ? null : _linesOf(entries);
}

/// The lines the timed [entries] make up.
///
/// A `SYLT` frame is a list of *syllables*, not of lines: a writer is free to
/// give every word its own time, and says where a line begins by starting its
/// text with a newline. So the entries are joined, and a newline is what
/// breaks them apart again — with the timestamp of the entry that opened a
/// line as the time that line is sung at.
///
/// The common case in real files is one entry per line and no newline
/// anywhere, which under that rule alone would join a whole song into one
/// line. So a frame with no newline in it at all is read as one line per
/// entry, which is what its writer meant.
Lyrics _linesOf(List<({Duration at, String text})> entries) {
  final broken = entries.any((entry) => entry.text.contains(_newline));

  if (!broken) {
    return Lyrics.synced([
      for (final entry in entries)
        LyricLine(text: entry.text.trim(), at: entry.at),
    ]);
  }

  final lines = <LyricLine>[];
  final line = StringBuffer();
  Duration? startedAt;

  void endLine() {
    if (startedAt != null) {
      lines.add(LyricLine(text: line.toString().trim(), at: startedAt));
    }
    line.clear();
    startedAt = null;
  }

  for (final entry in entries) {
    final pieces = entry.text.split(_newline);

    for (final (index, piece) in pieces.indexed) {
      // Every piece after the first in an entry follows a newline, and a
      // newline is where one line stops and the next starts.
      if (index > 0) endLine();
      startedAt ??= entry.at;
      line.write(piece);
    }
  }

  endLine();

  return Lyrics.synced(lines);
}

/// The line endings a tag may carry, whichever machine wrote it.
final RegExp _newline = RegExp(r'\r\n|\r|\n');

/// A string read from [data] at [start], and where the next one begins.
typedef _ReadString = ({String value, int next});

/// The terminated string at [start], read in [encoding], or `null` where the
/// frame ends before its terminator does.
_ReadString? _readString(Uint8List data, int start, int encoding) {
  final wide = encoding == 1 || encoding == 2;
  final step = wide ? 2 : 1;

  for (var end = start; end + step <= data.length; end += step) {
    if (data[end] != 0) continue;
    if (wide && data[end + 1] != 0) continue;

    return (
      value: id3DecodeText(Uint8List.sublistView(data, start, end), encoding),
      next: end + step,
    );
  }

  return null;
}
