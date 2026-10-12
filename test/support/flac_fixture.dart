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
Uint8List _vorbisComment(Map<String, String> tags) => _comments([
  for (final tag in tags.entries) '${tag.key}=${tag.value}',
], 'orpheus-test');

Uint8List _comments(List<String> comments, String vendorString) {
  final vendor = utf8.encode(vendorString);
  final bytes = BytesBuilder()
    ..add(_uint32le(vendor.length))
    ..add(vendor)
    ..add(_uint32le(comments.length));

  for (final comment in comments) {
    // UTF-8, which is what the format specifies — and what makes an accented
    // artist name survive the round trip.
    final entry = utf8.encode(comment);
    bytes
      ..add(_uint32le(entry.length))
      ..add(entry);
  }

  return bytes.toBytes();
}

/// PICTURE: the type, the MIME type, a description, four dimensions, and the
/// bytes. Every length here is big-endian.
Uint8List _picture(Uint8List image, {int pictureType = 3, String mime = 'image/png'}) {
  final bytes = BytesBuilder()
    // 3, the default, is "front cover": the one the reader prefers.
    ..add(_uint32be(pictureType))
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

/// One metadata block of a [flacOf] file: its type, and its body as the file
/// holds it.
typedef FlacBlock = ({int type, Uint8List body});

/// A FLAC file put together block by block, for what [taggedFlac] does not
/// build: blocks in any order, several pictures, padding, a tag in front of
/// the marker and audio after the metadata.
///
/// The last-block flag goes on the final block of [blocks] and nowhere else.
/// [id3v2] goes before the `fLaC` marker and [audio] after the last block,
/// both exactly as given.
Uint8List flacOf(List<FlacBlock> blocks, {Uint8List? id3v2, List<int>? audio}) {
  final bytes = BytesBuilder();
  if (id3v2 != null) bytes.add(id3v2);
  bytes.add('fLaC'.codeUnits);
  for (var index = 0; index < blocks.length; index++) {
    final block = blocks[index];
    bytes.add(_block(block.type, block.body, last: index == blocks.length - 1));
  }
  if (audio != null) bytes.add(audio);

  return bytes.toBytes();
}

/// A STREAMINFO block, as [taggedFlac] writes it.
FlacBlock streamInfoBlock({int durationSeconds = 200, int sampleRate = 44100}) =>
    (type: 0, body: _streamInfo(sampleRate, durationSeconds));

/// A VORBIS_COMMENT block holding [comments] in order, each the whole
/// `KEY=value` text — so a key can repeat, or be spelled in any case.
FlacBlock vorbisCommentBlock(List<String> comments, {String vendor = 'orpheus-test'}) =>
    (type: 4, body: _comments(comments, vendor));

/// A PICTURE block holding [image] as picture [pictureType]: 3 is the front
/// cover, 4 the back.
FlacBlock pictureBlock(Uint8List image, {int pictureType = 3, String mime = 'image/png'}) =>
    (type: 6, body: _picture(image, pictureType: pictureType, mime: mime));

/// A PADDING block of [length] zero bytes.
FlacBlock paddingBlock(int length) => (type: 1, body: Uint8List(length));

/// An APPLICATION block: a four-letter application id, then its own data.
FlacBlock applicationBlock(String id, List<int> data) =>
    (type: 2, body: Uint8List.fromList([...id.codeUnits, ...data]));

/// A SEEKTABLE block with one seek point: sample 0, at offset 0, of 4096
/// samples.
FlacBlock seekTableBlock() {
  final point = ByteData(18)..setUint16(16, 4096);

  return (type: 3, body: point.buffer.asUint8List());
}

/// An ID3v2.4 tag holding one TIT2 frame with [title] — what some taggers
/// put in front of a FLAC file's own marker.
Uint8List id3v2Tag(String title) {
  final text = [3, ...utf8.encode(title)];
  final frame = [...'TIT2'.codeUnits, ..._syncSafe(text.length), 0, 0, ...text];

  return Uint8List.fromList([...'ID3'.codeUnits, 4, 0, 0, ..._syncSafe(frame.length), ...frame]);
}

/// [value] in four bytes of seven bits each, as ID3v2 writes its sizes.
List<int> _syncSafe(int value) => [
  (value >> 21) & 0x7F,
  (value >> 14) & 0x7F,
  (value >> 7) & 0x7F,
  value & 0x7F,
];

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
