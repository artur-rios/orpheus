import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// One frame's identifier and its contents, with the frame header taken off.
class Id3Frame {
  /// A frame called [id] holding [data].
  const Id3Frame(this.id, this.data);

  /// The identifier: four characters in v2.3 and v2.4, three in v2.2.
  final String id;

  /// The frame's contents, with its header, flags and any data-length
  /// indicator taken off and per-frame unsynchronisation undone.
  final Uint8List data;
}

/// An ID3v2 tag, far enough parsed to walk its frames.
///
/// The read-only walker began in the synced-lyrics reader and lives here
/// because the library scan needs the same walk to read every genre in a genre
/// frame, which the tag-reading package stops short of.
class Id3v2Tag {
  const Id3v2Tag._({required this.major, required this.body});

  /// The version's major number: 2, 3 or 4.
  final int major;

  /// The frames, with the tag header taken off and whole-tag
  /// unsynchronisation undone.
  final Uint8List body;

  /// The tag at the start of [bytes], or `null` where there is not one.
  static Id3v2Tag? of(Uint8List bytes) {
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

    return Id3v2Tag._(major: major, body: body);
  }

  /// The tag's frames, in the order they are written, stopping at the padding.
  Iterable<Id3Frame> frames() sync* {
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

      yield Id3Frame(id, data);
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
  final size = major == 4 ? _syncSafe(body, 0) : _bigEndian(body, 0, 4) + 4;

  return size <= 0 || size > body.length
      ? body
      : Uint8List.sublistView(body, size);
}

/// The values in one text frame's [data], in the order they are written.
///
/// The first byte names the encoding: 0 is Latin-1, 1 is UTF-16 with a
/// byte-order mark, 2 is UTF-16 big-endian and 3 is UTF-8; anything else is read
/// as Latin-1, which is the reading that at least cannot throw. ID3v2.4 lets one
/// frame hold several values, each ended by that encoding's terminator — one
/// zero byte, or a zero 16-bit unit — so this splits there, and drops the empty
/// values a trailing terminator or a stray double one leaves behind.
///
/// Lenient by design: a scan reads thousands of files it did not write, and
/// malformed bytes are replaced rather than thrown.
List<String> id3TextValues(Uint8List data) {
  if (data.isEmpty) return const [];

  final encoding = data[0];
  final wide = encoding == 1 || encoding == 2;
  final step = wide ? 2 : 1;

  final values = <String>[];
  var start = 1;

  void take(int end) {
    final value = id3DecodeText(
      Uint8List.sublistView(data, start, end),
      encoding,
    );
    if (value.isNotEmpty) values.add(value);
  }

  for (var end = start; end + step <= data.length; end += step) {
    if (data[end] != 0) continue;
    if (wide && data[end + 1] != 0) continue;

    take(end);
    start = end + step;
  }

  if (start < data.length) take(data.length);

  return values;
}

/// The ID3v2 tag at the start of [file] as bytes, or `null` where it opens with
/// none.
///
/// Reads [id3HeaderLength] bytes, asks [id3TagLengthOf] how long the tag is and
/// reads exactly that: a tag with a sleeve in it runs to megabytes and one
/// without to a few hundred bytes, and neither should cost the audio behind it.
/// A tag that claims more than the file holds is cut at the file's end. A file
/// that is not there, or is too short to hold a header, has no tag; an I/O error
/// on a file that is there is the caller's to handle.
Uint8List? readId3v2Tag(File file) {
  if (!file.existsSync()) return null;

  final handle = file.openSync();
  try {
    final header = handle.readSync(id3HeaderLength);
    final length = id3TagLengthOf(header);
    if (length == null) return null;

    handle.setPositionSync(0);

    // Never past the end of the file: the length is whatever the header says,
    // and a damaged one can say hundreds of megabytes. Reading what is there
    // also lets the frames before a truncation still be read.
    final fileLength = handle.lengthSync();

    return handle.readSync(length < fileLength ? length : fileLength);
  } finally {
    handle.closeSync();
  }
}

/// [bytes] as text, in the encoding a frame declared: 0 is Latin-1, 1 is UTF-16
/// with a byte-order mark, 2 is UTF-16 big-endian and 3 is UTF-8.
///
/// Lenient: an encoding the format does not define is read as Latin-1, which is
/// the reading that at least cannot throw, and malformed bytes are replaced.
/// Shared by every reader that walks a tag's own frames, so that they agree on
/// what a frame says.
String id3DecodeText(Uint8List bytes, int encoding) => switch (encoding) {
  0 => latin1.decode(bytes, allowInvalid: true),
  1 => _utf16(bytes, bigEndian: _isBigEndianBom(bytes)),
  2 => _utf16(bytes, bigEndian: true),
  3 => utf8.decode(bytes, allowMalformed: true),
  _ => latin1.decode(bytes, allowInvalid: true),
};

/// Whether [bytes] opens with a big-endian byte-order mark.
///
/// Where a writer left the mark out, little-endian is the assumption, because
/// that is what the writers that leave it out produce.
bool _isBigEndianBom(Uint8List bytes) =>
    bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF;

/// [bytes] as UTF-16 text, with a byte-order mark taken off where there is one.
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

  return String.fromCharCodes(units);
}
