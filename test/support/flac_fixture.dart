import 'dart:convert';
import 'dart:typed_data';

/// A real FLAC file, small enough to write from a test and complete enough for
/// the tag reader to open.
///
/// The header is the whole file: a `fLaC` marker, a STREAMINFO block (the only
/// mandatory one), a VORBIS_COMMENT block carrying the tags, and optionally a
/// PICTURE block carrying a sleeve. There are no audio frames at all, which no
/// reader minds — the duration comes from STREAMINFO's sample count, not from
/// the frames.
///
/// It exists so that the one thing an owner sees most of — what the library
/// says a track is called and who it is by — is provable against a real file
/// rather than only against a fake reader.
Uint8List taggedFlac({
  required Map<String, String> tags,
  int durationSeconds = 200,
  int sampleRate = 44100,
  Uint8List? picture,
}) {
  final bytes = BytesBuilder()..add('fLaC'.codeUnits);
  bytes.add(_block(0, _streamInfo(sampleRate, durationSeconds)));
  bytes.add(
    _block(4, _vorbisComment(tags), last: picture == null),
  );
  if (picture != null) {
    bytes.add(_block(6, _picture(picture), last: true));
  }

  return bytes.toBytes();
}

/// One metadata block: a type byte (with the last-block flag in its top bit)
/// and a 24-bit big-endian length.
Uint8List _block(int type, Uint8List payload, {bool last = false}) {
  final header = Uint8List(4);
  header[0] = (last ? 0x80 : 0) | type;
  header[1] = (payload.length >> 16) & 0xFF;
  header[2] = (payload.length >> 8) & 0xFF;
  header[3] = payload.length & 0xFF;

  return (BytesBuilder()
        ..add(header)
        ..add(payload))
      .toBytes();
}

/// STREAMINFO: block sizes, frame sizes, then a packed field carrying the
/// sample rate, the channel count, the bit depth and the total sample count —
/// which is what a reader divides to answer a duration.
Uint8List _streamInfo(int sampleRate, int durationSeconds) {
  final data = ByteData(34);
  data.setUint16(0, 4096);
  data.setUint16(2, 4096);
  // Minimum and maximum frame size, 24 bits each: unknown, which is what a
  // file with no frames should say.
  for (var offset = 4; offset < 10; offset++) {
    data.setUint8(offset, 0);
  }

  const channels = 2;
  const bitsPerSample = 16;
  final packed =
      (BigInt.from(sampleRate) << 44) |
      (BigInt.from(channels - 1) << 41) |
      (BigInt.from(bitsPerSample - 1) << 36) |
      BigInt.from(sampleRate * durationSeconds);
  for (var byte = 0; byte < 8; byte++) {
    data.setUint8(
      10 + byte,
      ((packed >> ((7 - byte) * 8)) & BigInt.from(0xFF)).toInt(),
    );
  }

  // The MD5 of the unencoded audio, left zeroed: the value means "unknown",
  // which is exactly true of a file with no audio in it.
  return data.buffer.asUint8List();
}

/// VORBIS_COMMENT: a vendor string, a count, then `NAME=value` entries — all
/// lengths little-endian, unlike every other length in the format.
Uint8List _vorbisComment(Map<String, String> tags) {
  final vendor = utf8.encode('orpheus-test');
  final bytes = BytesBuilder()
    ..add(_uint32le(vendor.length))
    ..add(vendor)
    ..add(_uint32le(tags.length));

  for (final tag in tags.entries) {
    // UTF-8, which is what the format specifies — and what makes an accented
    // artist name survive the round trip.
    final entry = utf8.encode('${tag.key}=${tag.value}');
    bytes
      ..add(_uint32le(entry.length))
      ..add(entry);
  }

  return bytes.toBytes();
}

/// PICTURE: the type, the MIME type, a description, four dimensions, and the
/// bytes. Every length here is big-endian.
Uint8List _picture(Uint8List image) {
  const mime = 'image/png';
  final bytes = BytesBuilder()
    // 3 is "front cover", which is the one the reader prefers.
    ..add(_uint32be(3))
    ..add(_uint32be(mime.length))
    ..add(mime.codeUnits)
    ..add(_uint32be(0))
    ..add(_uint32be(1))
    ..add(_uint32be(1))
    ..add(_uint32be(24))
    ..add(_uint32be(0))
    ..add(_uint32be(image.length))
    ..add(image);

  return bytes.toBytes();
}

Uint8List _uint32le(int value) =>
    (ByteData(4)..setUint32(0, value, Endian.little)).buffer.asUint8List();

Uint8List _uint32be(int value) =>
    (ByteData(4)..setUint32(0, value)).buffer.asUint8List();

/// A one-pixel PNG, which is a real picture and forty-odd bytes.
Uint8List onePixelPng() => Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
]);
