import 'dart:convert';
import 'dart:typed_data';

/// An ID3v2 tag, built frame by frame, for the tests about reading one.
///
/// The reader under test walks a tag's own bytes rather than going through the
/// tag-reading package, so the tests have to be able to write those bytes:
/// a version, the header flags, the frame flags, and the encodings — each of
/// which is a branch in the reader and none of which an ordinary fixture file
/// would exercise on purpose.
Uint8List id3Tag({
  required List<Uint8List> frames,
  int major = 4,
  bool unsynchronised = false,
  bool extendedHeader = false,
  bool footer = false,
  List<int> trailing = const [],
}) {
  final body = BytesBuilder();

  if (extendedHeader) body.add(_extendedHeader(major));
  for (final frame in frames) {
    body.add(frame);
  }

  final contents = unsynchronised
      ? unsynchronise(body.toBytes())
      : body.toBytes();

  final tag = BytesBuilder()
    ..add('ID3'.codeUnits)
    ..addByte(major)
    ..addByte(0)
    ..addByte(
      (unsynchronised ? 0x80 : 0) |
          (extendedHeader ? 0x40 : 0) |
          (footer ? 0x10 : 0),
    )
    // The stated size counts the frames and the extended header, and neither
    // the ten-byte header nor the footer that repeats it.
    ..add(syncSafe(contents.length))
    ..add(contents);

  if (footer) {
    tag
      ..add('3DI'.codeUnits)
      ..addByte(major)
      ..addByte(0)
      ..addByte(0x10)
      ..add(syncSafe(contents.length));
  }

  return (tag..add(trailing)).toBytes();
}

/// A `SYLT` frame carrying [entries], each a piece of text and the moment it
/// is sung.
Uint8List syltFrame({
  required List<({Duration at, String text})> entries,
  int major = 4,
  int encoding = 0,
  int timestampFormat = 2,
  int contentType = 1,
  String descriptor = '',
  int flags = 0,
  bool dataLengthIndicator = false,
  bool unsynchronised = false,
}) {
  final body = BytesBuilder()
    ..addByte(encoding)
    ..add('eng'.codeUnits)
    ..addByte(timestampFormat)
    ..addByte(contentType)
    ..add(encodedText(descriptor, encoding));

  for (final entry in entries) {
    body
      ..add(encodedText(entry.text, encoding))
      ..add(_bigEndian(entry.at.inMilliseconds));
  }

  var data = body.toBytes();

  if (dataLengthIndicator) {
    data = (BytesBuilder()
          ..add(syncSafe(data.length))
          ..add(data))
        .toBytes();
  }
  if (unsynchronised) data = unsynchronise(data);

  return frame(
    major == 2 ? 'SLT' : 'SYLT',
    data,
    major: major,
    flags: flags |
        (dataLengthIndicator ? 0x01 : 0) |
        (unsynchronised ? 0x02 : 0),
  );
}

/// A `USLT` frame — the unsynchronised words, which is what every ordinary tag
/// reader surfaces.
Uint8List usltFrame(String text, {int major = 4, int encoding = 0}) => frame(
  'USLT',
  (BytesBuilder()
        ..addByte(encoding)
        ..add('eng'.codeUnits)
        ..add(encodedText('', encoding))
        ..add(encodedText(text, encoding)))
      .toBytes(),
  major: major,
);

/// One frame: its identifier, its length, its flags, and [data].
Uint8List frame(String id, Uint8List data, {int major = 4, int flags = 0}) {
  final out = BytesBuilder()..add(id.codeUnits);

  if (major == 2) {
    out.add([
      (data.length >> 16) & 0xFF,
      (data.length >> 8) & 0xFF,
      data.length & 0xFF,
    ]);
  } else {
    out
      // v2.4 states a frame's length seven bits to the byte; v2.3 states it
      // plainly, and reading one as the other is the classic way to lose every
      // frame after the first long one.
      ..add(major == 4 ? syncSafe(data.length) : _bigEndian(data.length))
      ..addByte(0)
      ..addByte(flags);
  }

  return (out..add(data)).toBytes();
}

/// [text] in the encoding [encoding] names, with its terminator.
Uint8List encodedText(String text, int encoding) {
  final out = BytesBuilder();

  switch (encoding) {
    case 1:
      out
        ..add([0xFF, 0xFE])
        ..add(_utf16(text, bigEndian: false));
    case 2:
      out.add(_utf16(text, bigEndian: true));
    case 3:
      out.add(utf8.encode(text));
    default:
      out.add(latin1.encode(text));
  }

  out.add(encoding == 1 || encoding == 2 ? const [0, 0] : const [0]);

  return out.toBytes();
}

/// [value] as the four synchsafe bytes a tag states a length in.
Uint8List syncSafe(int value) => Uint8List.fromList([
  (value >> 21) & 0x7F,
  (value >> 14) & 0x7F,
  (value >> 7) & 0x7F,
  value & 0x7F,
]);

/// [bytes] with every `$FF` that could be mistaken for the start of audio
/// followed by the `$00` the format inserts to say it is not.
Uint8List unsynchronise(Uint8List bytes) {
  final out = BytesBuilder();

  for (var index = 0; index < bytes.length; index++) {
    out.addByte(bytes[index]);

    final next = index + 1 < bytes.length ? bytes[index + 1] : 0;
    if (bytes[index] == 0xFF && (next == 0x00 || next >= 0xE0)) {
      out.addByte(0x00);
    }
  }

  return out.takeBytes();
}

/// An extended header, which carries nothing this reader wants and has to be
/// stepped over to reach the frames.
Uint8List _extendedHeader(int major) => major == 4
    // v2.4: a synchsafe length counting the whole thing, a flag byte count,
    // and a flag byte.
    ? (BytesBuilder()
            ..add(syncSafe(6))
            ..add([1, 0]))
          .toBytes()
    // v2.3: a plain length counting everything after itself, then that much.
    : (BytesBuilder()
            ..add(_bigEndian(6))
            ..add(List.filled(6, 0)))
          .toBytes();

/// [value] as four plain big-endian bytes.
Uint8List _bigEndian(int value) => Uint8List(4)
  ..[0] = (value >> 24) & 0xFF
  ..[1] = (value >> 16) & 0xFF
  ..[2] = (value >> 8) & 0xFF
  ..[3] = value & 0xFF;

/// [text] as UTF-16 code units, without a byte-order mark.
Uint8List _utf16(String text, {required bool bigEndian}) {
  final out = BytesBuilder();

  for (final unit in text.codeUnits) {
    out.add(
      bigEndian
          ? [(unit >> 8) & 0xFF, unit & 0xFF]
          : [unit & 0xFF, (unit >> 8) & 0xFF],
    );
  }

  return out.toBytes();
}
