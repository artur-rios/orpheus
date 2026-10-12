import 'dart:convert';
import 'dart:typed_data';

/// A file carrying an APEv2 tag, small enough to write from a test and
/// complete enough for the tag reader to open — the APE counterpart of
/// `taggedFlac`.
///
/// A Monkey's Audio marker, a run of zeros standing in for the audio, then
/// the tag: its items, and the 32-byte footer a reader finds it by at the end
/// of the file. No header before the items, which the format leaves optional.
///
/// [tags] are text items, keyed as a tagger writes them — `Album Artist`,
/// `Year` — since what a rewrite does to those keys is part of what the
/// preservation tests check.
Uint8List taggedApe({required Map<String, String> tags}) {
  final items = BytesBuilder();
  for (final tag in tags.entries) {
    final value = utf8.encode(tag.value);
    items
      ..add(_uint32le(value.length))
      // Item flags: a UTF-8 text item, read-write.
      ..add(_uint32le(0))
      ..add(ascii.encode(tag.key))
      ..addByte(0)
      ..add(value);
  }
  final itemBytes = items.toBytes();

  final footer = BytesBuilder()
    ..add(ascii.encode('APETAGEX'))
    ..add(_uint32le(2000))
    // The tag's size: its items and this footer, without the optional header.
    ..add(_uint32le(itemBytes.length + 32))
    ..add(_uint32le(tags.length))
    ..add(_uint32le(0))
    ..add(Uint8List(8));

  return (BytesBuilder()
        ..add(ascii.encode('MAC '))
        ..add(Uint8List(60))
        ..add(itemBytes)
        ..add(footer.toBytes()))
      .toBytes();
}

Uint8List _uint32le(int value) =>
    (ByteData(4)..setUint32(0, value, Endian.little)).buffer.asUint8List();
