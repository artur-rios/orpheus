import 'dart:convert';
import 'dart:typed_data';

import '../domain/lyrics.dart';

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
  final tag = _Id3Tag.of(bytes);
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

/// One frame's identifier and its contents, with the frame header taken off.
class _Frame {
  const _Frame(this.id, this.data);

  final String id;
  final Uint8List data;
}

/// An ID3v2 tag, far enough parsed to walk its frames.
class _Id3Tag {
  const _Id3Tag._({required this.major, required this.body});

  /// The version's major number: 2, 3 or 4.
  final int major;

  /// The frames, with the tag header taken off and whole-tag
  /// unsynchronisation undone.
  final Uint8List body;

  /// The tag at the start of [bytes], or `null` where there is not one.
  static _Id3Tag? of(Uint8List bytes) {
    if (bytes.length < id3HeaderLength) return null;
    if (bytes[0] != 0x49 || bytes[1] != 0x44 || bytes[2] != 0x33) return null;

    final major = bytes[3];
    if (major < 2 || major > 4) return null;

    final flags = bytes[5];
    final size = _syncSafe(bytes, 6);
    final end = id3HeaderLength + size;
    var body = Uint8List.sublistView(
      bytes,
      id3HeaderLength,
      end > bytes.length ? bytes.length : end,
    );

    // Unsynchronisation is a whole-tag transformation before v2.4 and a
    // per-frame one from v2.4 on, and the header flag says which files are
    // written the old way.
    if (flags & 0x80 != 0 && major < 4) body = _deUnsynchronise(body);

    // The extended header carries a CRC and, in v2.4, restrictions. Nothing
    // here reads either; both are stepped over.
    if (flags & 0x40 != 0) body = _withoutExtendedHeader(body, major);

    return _Id3Tag._(major: major, body: body);
  }

  /// The tag's frames, in the order they are written, stopping at the padding.
  Iterable<_Frame> frames() sync* {
    final idLength = major == 2 ? 3 : 4;
    final headerLength = major == 2 ? 6 : 10;
    var offset = 0;

    while (offset + headerLength <= body.length) {
      final id = String.fromCharCodes(body, offset, offset + idLength);

      // A tag is padded with zeroes to whatever length its writer left room
      // for, and the first zero byte where an identifier belongs is the end of
      // the frames.
      if (id.codeUnits.first == 0) return;

      final size = major == 2
          ? _bigEndian(body, offset + 3, 3)
          : major == 3
          ? _bigEndian(body, offset + 4, 4)
          : _syncSafe(body, offset + 4);

      var start = offset + headerLength;
      final end = start + size;
      if (size <= 0 || end > body.length) return;

      offset = end;

      final flags = major == 2 ? 0 : body[start - 1];
      // Compressed and encrypted frames are stepped over rather than
      // half-read: undoing either needs a decompressor or a key this
      // application does not have, and a caller that gets nothing here falls
      // back to the text frame.
      if (major == 3 && flags & 0xC0 != 0) continue;
      if (major == 4 && flags & 0x0C != 0) continue;

      if (major == 3 && flags & 0x20 != 0) start++;
      if (major == 4 && flags & 0x40 != 0) start++;

      // The data-length indicator: four synchsafe bytes stating what the frame
      // would be once undone. Not needed to read it, and taken off so that the
      // frame's own contents start where they are expected to.
      if (major == 4 && flags & 0x01 != 0) start += 4;

      if (start > end) continue;

      var data = Uint8List.sublistView(body, start, end);
      if (major == 4 && flags & 0x02 != 0) data = _deUnsynchronise(data);

      yield _Frame(id, data);
    }
  }
}

/// How long an ID3v2 tag header is, before the frames start.
///
/// What a caller reads first: those ten bytes say whether there is a tag at
/// all and, through [id3TagLengthOf], how much of the file is it.
const int id3HeaderLength = 10;

/// How many bytes from the start of a file its ID3v2 tag occupies, given its
/// first [id3HeaderLength] bytes, or `null` where the file opens with no tag.
///
/// This is what keeps [parseId3SyncedLyrics] off the audio: a caller reads ten
/// bytes, is told the tag is (say) forty kilobytes, and reads exactly those —
/// rather than a fixed guess that would be too small for a tag carrying a
/// sleeve and far too large for one that is not.
int? id3TagLengthOf(Uint8List header) {
  if (header.length < id3HeaderLength) return null;
  if (header[0] != 0x49 || header[1] != 0x44 || header[2] != 0x33) return null;
  if (header[3] < 2 || header[3] > 4) return null;

  // The footer, where a v2.4 writer added one, is a second copy of the header
  // after the frames and is counted in as well.
  final footer = header[5] & 0x10 != 0 ? id3HeaderLength : 0;

  return id3HeaderLength + _syncSafe(header, 6) + footer;
}

/// The [length]-byte big-endian number at [offset].
int _bigEndian(Uint8List bytes, int offset, int length) {
  var value = 0;
  for (var index = 0; index < length; index++) {
    value = (value << 8) | bytes[offset + index];
  }

  return value;
}

/// The four-byte synchsafe number at [offset] — seven bits of each byte, so
/// that a size can never itself look like the start of an audio frame.
int _syncSafe(Uint8List bytes, int offset) {
  var value = 0;
  for (var index = 0; index < 4; index++) {
    value = (value << 7) | (bytes[offset + index] & 0x7F);
  }

  return value;
}

/// [bytes] with the unsynchronisation undone: every `$FF $00` written to keep
/// a tag from looking like audio becomes the `$FF` it stands for.
Uint8List _deUnsynchronise(Uint8List bytes) {
  final out = BytesBuilder(copy: false);

  for (var index = 0; index < bytes.length; index++) {
    out.addByte(bytes[index]);
    if (bytes[index] == 0xFF &&
        index + 1 < bytes.length &&
        bytes[index + 1] == 0x00) {
      index++;
    }
  }

  return out.takeBytes();
}

/// [body] with its extended header taken off.
Uint8List _withoutExtendedHeader(Uint8List body, int major) {
  if (body.length < 4) return body;

  // v2.4 states a synchsafe size that counts the whole extended header; v2.3
  // states a plain one that counts everything after the four size bytes.
  final size = major == 4
      ? _syncSafe(body, 0)
      : _bigEndian(body, 0, 4) + 4;

  return size <= 0 || size > body.length
      ? body
      : Uint8List.sublistView(body, size);
}

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
      at: Duration(milliseconds: _bigEndian(data, offset, 4)),
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
      value: _decode(Uint8List.sublistView(data, start, end), encoding),
      next: end + step,
    );
  }

  return null;
}

/// [bytes] as text, in the encoding the frame declared.
String _decode(Uint8List bytes, int encoding) => switch (encoding) {
  // ISO-8859-1, which is what a tag written before the century says.
  0 => latin1.decode(bytes, allowInvalid: true),
  1 => _utf16(bytes, bigEndian: _isBigEndianBom(bytes)),
  2 => _utf16(bytes, bigEndian: true),
  3 => utf8.decode(bytes, allowMalformed: true),
  // A frame declaring an encoding the format does not define is read as
  // Latin-1, which is the reading that at least cannot throw.
  _ => latin1.decode(bytes, allowInvalid: true),
};

/// Whether [bytes] opens with a big-endian byte-order mark.
///
/// The format requires UTF-16 here to carry one. Where a writer left it out,
/// little-endian is the assumption, because that is what the writers that
/// leave it out produce.
bool _isBigEndianBom(Uint8List bytes) =>
    bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF;

/// [bytes] as UTF-16 text, with a byte-order mark taken off where there is
/// one.
String _utf16(Uint8List bytes, {required bool bigEndian}) {
  var start = 0;
  if (bytes.length >= 2 &&
      ((bytes[0] == 0xFF && bytes[1] == 0xFE) ||
          (bytes[0] == 0xFE && bytes[1] == 0xFF))) {
    start = 2;
  }

  final units = <int>[];
  for (var index = start; index + 1 < bytes.length; index += 2) {
    units.add(
      bigEndian
          ? (bytes[index] << 8) | bytes[index + 1]
          : (bytes[index + 1] << 8) | bytes[index],
    );
  }

  // Dart strings are UTF-16 themselves, so a surrogate pair needs no handling
  // of its own: the two units it is written as are the two units it is stored
  // as.
  return String.fromCharCodes(units);
}
