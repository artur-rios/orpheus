import 'dart:convert';
import 'dart:typed_data';

import '../domain/autofill_field.dart';

/// A tag [editId3Tags] will not change: one it could only rewrite by
/// understanding more of the format than it does, and so risk corrupting.
class UnsupportedTagException implements Exception {
  /// Creates the exception, saying what about the tag it is.
  const UnsupportedTagException(this.message);

  /// What about the tag this editor will not touch.
  final String message;

  @override
  String toString() => 'UnsupportedTagException: $message';
}

/// [file], a whole MP3 file, with [values] written into its ID3v2 tag — and
/// every other byte of it as it was.
///
/// Each field in [values] replaces every frame it is read from (see
/// [_slotsFor]), in the place of the first of them or after the last frame
/// where there was none; every other frame is kept byte for byte, flags
/// included, in its order — a compressed or encrypted frame too, unless it is
/// one of those being replaced. A `null` value removes the field's frames and
/// writes none. Text is written as UTF-8 in an ID3v2.4 tag and as UTF-16 in
/// an ID3v2.3 one, which has no UTF-8.
///
/// The tag keeps its size where the frames fit in it, so that the audio does
/// not move; where they do not, it grows to them and a kilobyte of padding,
/// for the next edit to fit in. A file with no ID3v2 tag gets an ID3v2.4 one
/// in front. The audio, and an ID3v1 or APE tag after it, are copied as they
/// are.
///
/// Throws an [UnsupportedTagException], having changed nothing, for a tag
/// this does not edit: ID3v2.2, a version after 2.4, or a tag that is
/// unsynchronised as a whole, has an extended header or sets a flag the
/// version does not define. Throws a [FormatException], having changed
/// nothing, where [file] cannot be parsed safely: a size that runs past the
/// end of what holds it, a frame id that is not one, bytes other than zeros
/// in the padding, or a frame whose content a write depends on and cannot be
/// read.
///
/// Pure: it reads nothing and writes nothing but the bytes it returns.
Uint8List editId3Tags(Uint8List file, Map<AutofillField, Object?> values) {
  final source = _parse(file);
  if (values.isEmpty) return Uint8List.fromList(file);
  final tag = source.tag;
  final major = tag?.major ?? 4;
  final slots = _slotsFor(source.frames, values, major);

  // Every frame, the replaced ones swapped for what replaces them.
  final placed = <int>{};
  final frames = <Uint8List>[];
  for (final frame in source.frames) {
    final slot = slots.indexWhere((slot) => slot.replaces(frame));
    if (slot == -1) {
      frames.add(frame.raw);
    } else if (placed.add(slot)) {
      frames.addAll([?slots[slot].frame]);
    }
  }
  for (final (index, slot) in slots.indexed) {
    if (!placed.contains(index)) frames.addAll([?slot.frame]);
  }

  // Nothing to write, and no tag to write it to: the file is left as it is
  // rather than given an empty tag.
  if (tag == null && frames.isEmpty) return Uint8List.fromList(file);

  final length = frames.fold(0, (sum, frame) => sum + frame.length);
  // A footer is for a tag appended to a file, which this one is not; its
  // ten bytes go to the padding, so the audio stays where it was.
  final room = tag == null ? -1 : tag.size + tag.footer;
  final size = length <= room ? room : length + _padding;
  if (size > _maxSyncSafe) throw const FormatException('a tag too large for ID3v2');

  final bytes = BytesBuilder(copy: false)
    ..add(_id3)
    ..add([major, tag?.revision ?? 0, (tag?.flags ?? 0) & ~_footerFlag])
    ..add(_syncSafe(size));
  for (final frame in frames) {
    bytes.add(frame);
  }
  bytes
    ..add(Uint8List(size - length))
    ..add(source.audio);
  final result = bytes.toBytes();

  // What the edit must never do, checked on what it produced rather than
  // trusted: the result parses, to the very frames it was built from, and
  // the audio after it is the very bytes it was.
  final written = _parse(result);
  if (!_same(written.audio, source.audio) ||
      written.tag?.major != major ||
      written.frames.length != frames.length ||
      [for (final (index, frame) in written.frames.indexed) _same(frame.raw, frames[index])].contains(false)) {
    throw StateError('the edit changed bytes outside the frames it was asked to');
  }

  return result;
}

/// The padding a tag that has to grow is given: room for the next edit to
/// change a title or a year without moving the audio again.
const _padding = 1024;

/// The largest number four sync-safe bytes can say.
const _maxSyncSafe = 0x0FFFFFFF;

const _id3 = [0x49, 0x44, 0x33];
const _unsynchronisationFlag = 0x80;
const _extendedHeaderFlag = 0x40;
const _footerFlag = 0x10;

/// What an ID3v2 header says: the version, the flags, and the size of what
/// follows it, without the header and the [footer] (ten bytes, or none).
typedef _Tag = ({int major, int revision, int flags, int size, int footer});

/// One frame: its id, its two flag bytes, its body, and the whole of it as
/// the file holds it, header included.
typedef _Frame = ({String id, int formatFlags, Uint8List body, Uint8List raw});

/// An MP3 file split into its ID3v2 tag ([tag] `null` where it has none), the
/// frames in that tag, and everything after it.
typedef _Mp3 = ({_Tag? tag, List<_Frame> frames, Uint8List audio});

_Mp3 _parse(Uint8List file) {
  if (!_startsWith(file, 0, 'ID3')) {
    // No tag, and so nothing to tell this is an MP3 but its first bytes: an
    // MPEG frame's sync word. A file that is something else under an .mp3
    // name is not one to put a tag in front of.
    if (file.length < 2 || file[0] != 0xFF || file[1] & 0xE0 != 0xE0) {
      throw const FormatException('neither an ID3v2 tag nor MPEG audio');
    }

    return (tag: null, frames: const [], audio: file);
  }

  if (file.length < 10) throw const FormatException('a truncated ID3v2 header');
  final major = file[3];
  if (major < 2) throw const FormatException('an ID3v2 version that does not exist');
  if (major == 2) throw const UnsupportedTagException('an ID3v2.2 tag, whose frames are of another shape');
  if (major > 4) throw UnsupportedTagException('an ID3v2.$major tag, from after this was written');

  final flags = file[5];
  // A tag unsynchronised as a whole has every frame's bytes changed, and an
  // extended header carries a checksum and restrictions this would have to
  // keep true; both are rare, and getting either wrong corrupts the tag.
  if (flags & _unsynchronisationFlag != 0) throw const UnsupportedTagException('an unsynchronised tag');
  if (flags & _extendedHeaderFlag != 0) throw const UnsupportedTagException('a tag with an extended header');
  // Besides those: experimental (0x20), and in v2.4 the footer. Any other
  // flag is one this version does not define.
  if (flags & (major == 4 ? 0x0F : 0x1F) != 0) throw const UnsupportedTagException('a tag flag this does not know');

  final size = _readSyncSafe(file, 6);
  final footer = flags & _footerFlag != 0 ? 10 : 0;
  final end = 10 + size;
  if (end + footer > file.length) throw const FormatException('a tag that runs past the end of the file');
  if (footer != 0 && !_startsWith(file, end, '3DI')) throw const FormatException('a footer that is not one');

  final frames = <_Frame>[];
  var offset = 10;
  while (offset < end) {
    // A zero byte where an id would start begins the padding — which is
    // zeros to the end of the tag, or something this cannot account for:
    // audio, say, under a size that overstates the tag, which rewriting the
    // padding would overwrite.
    if (file[offset] == 0) {
      if (Uint8List.sublistView(file, offset, end).any((byte) => byte != 0)) {
        throw const FormatException('bytes other than zeros in the padding');
      }
      break;
    }

    if (offset + 10 > end) throw const FormatException('a frame header that runs past the end of the tag');
    final id = String.fromCharCodes(file, offset, offset + 4);
    if (!_frameId.hasMatch(id)) throw const FormatException('a frame id that is not one');
    // v2.4 states a frame's size seven bits to the byte, v2.3 plainly.
    final length = major == 4 ? _readSyncSafe(file, offset + 4) : ByteData.sublistView(file).getUint32(offset + 4);
    final frameEnd = offset + 10 + length;
    if (frameEnd > end) throw const FormatException('a frame that runs past the end of the tag');

    frames.add((
      id: id,
      formatFlags: file[offset + 9],
      body: Uint8List.sublistView(file, offset + 10, frameEnd),
      raw: Uint8List.sublistView(file, offset, frameEnd),
    ));
    offset = frameEnd;
  }

  return (
    tag: (major: major, revision: file[4], flags: flags, size: size, footer: footer),
    frames: frames,
    audio: Uint8List.sublistView(file, end + footer),
  );
}

final _frameId = RegExp(r'^[A-Z0-9]{4}$');

/// What writing one field (or a number and its total) does: which frames it
/// replaces, and the frame it writes in their place — `null` for none.
typedef _Slot = ({bool Function(_Frame frame) replaces, Uint8List? frame});

/// A slot for each field in [values], in the order a frame is appended in
/// where none was replaced.
///
/// Each field is written as the frame the reader reads it from, and replaces
/// every frame the reader reads it from — the v2.3 year (`TYER`) and the v2.4
/// one (`TDRC`) both, whichever the version, so that the one written is the
/// one read back. The day and time of a v2.3 date (`TDAT`, `TIME`) are not a
/// year, and are kept.
List<_Slot> _slotsFor(List<_Frame> frames, Map<AutofillField, Object?> values, int major) {
  final slots = <_Slot>[];

  void write(Set<String> replaced, String id, String? text) => slots.add((
    replaces: (frame) => replaced.contains(frame.id),
    frame: text == null ? null : _frame(id, _textBody(text, major), major),
  ));

  for (final (field, id) in const [
    (AutofillField.title, 'TIT2'),
    (AutofillField.artist, 'TPE1'),
    (AutofillField.albumArtist, 'TPE2'),
    (AutofillField.album, 'TALB'),
  ]) {
    if (values.containsKey(field)) write({id}, id, _textOf(field, values[field]));
  }

  for (final (number, total, id) in const [
    (AutofillField.trackNumber, AutofillField.trackTotal, 'TRCK'),
    (AutofillField.discNumber, AutofillField.discTotal, 'TPOS'),
  ]) {
    if (!values.containsKey(number) && !values.containsKey(total)) continue;

    // The half not being written is the file's own, as the file spells it.
    final existing = values.containsKey(number) && values.containsKey(total)
        ? (number: null, total: null)
        : _numberAndTotal(frames, id);
    final numberText = values.containsKey(number) ? _numberOf(number, values[number]) : existing.number;
    final totalText = values.containsKey(total) ? _numberOf(total, values[total]) : existing.total;
    // A total with no number to be the total of is not something ID3 can
    // say: `/12` is not a position. Nothing is written for it.
    write({id}, id, numberText == null ? null : (totalText == null ? numberText : '$numberText/$totalText'));
  }

  if (values.containsKey(AutofillField.year)) {
    write({'TDRC', 'TYER'}, major == 4 ? 'TDRC' : 'TYER', _yearOf(values[AutofillField.year]));
  }

  if (values.containsKey(AutofillField.genre)) {
    write({'TCON'}, 'TCON', _textOf(AutofillField.genre, values[AutofillField.genre]));
  }

  if (values.containsKey(AutofillField.cover)) {
    final cover = switch (values[AutofillField.cover]) {
      null => null,
      final Uint8List image => image,
      final other => throw ArgumentError.value(other, AutofillField.cover.name, 'not a value this field holds'),
    };
    slots.add((replaces: _isFrontCover, frame: cover == null ? null : _frame('APIC', _pictureBody(cover), major)));
  }

  return slots;
}

String? _textOf(AutofillField field, Object? value) => switch (value) {
  null => null,
  final String text => text,
  _ => throw ArgumentError.value(value, field.name, 'not a value this field holds'),
};

String? _numberOf(AutofillField field, Object? value) => switch (value) {
  null => null,
  final int number when number >= 0 => '$number',
  _ => throw ArgumentError.value(value, field.name, 'not a value this field holds'),
};

/// A year as v2.3 requires it, four digits — and as v2.4 takes it, the
/// start of a timestamp.
String? _yearOf(Object? value) => switch (value) {
  null => null,
  final int year when year >= 0 && year <= 9999 => '$year'.padLeft(4, '0'),
  _ => throw ArgumentError.value(value, AutofillField.year.name, 'not a value this field holds'),
};

/// The number and the total of the last [id] frame in [frames] — the one
/// the reader reads — each as the file spells it (`03` stays `03`), or
/// `null` for a half it does not have.
///
/// Throws where there is a frame and this cannot read it: writing half of
/// it would lose the other half.
({String? number, String? total}) _numberAndTotal(List<_Frame> frames, String id) {
  final frame = frames.where((frame) => frame.id == id).lastOrNull;
  if (frame == null) return (number: null, total: null);
  if (frame.formatFlags != 0) {
    throw UnsupportedTagException('a compressed or encrypted $id, half of which a write would have to keep');
  }

  final match = _numberAndTotalPattern.firstMatch(_decodeText(frame.body));
  if (match == null) throw FormatException('a $id that is not a number and a total, half of which a write would lose');
  String? part(String? digits) => digits == null || digits.isEmpty ? null : digits;

  return (number: part(match[1]), total: part(match[2]));
}

final _numberAndTotalPattern = RegExp(r'^\s*(\d*)\s*(?:/\s*(\d*)\s*)?$');

/// The text of a text frame's [body]: its first value, without terminator.
String _decodeText(Uint8List body) {
  if (body.isEmpty) return '';

  final bytes = Uint8List.sublistView(body, 1);
  final text = switch (body[0]) {
    0 => latin1.decode(bytes),
    1 => _utf16(bytes, bigEndian: bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF, bom: true),
    2 => _utf16(bytes, bigEndian: true, bom: false),
    3 => utf8.decode(bytes),
    _ => throw const FormatException('a text encoding that does not exist'),
  };
  final terminator = text.indexOf('\u0000');

  return terminator == -1 ? text : text.substring(0, terminator);
}

String _utf16(Uint8List bytes, {required bool bigEndian, required bool bom}) {
  final data = ByteData.sublistView(bytes);
  final start = bom && bytes.length >= 2 && (bytes[0] == 0xFF && bytes[1] == 0xFE || bytes[0] == 0xFE && bytes[1] == 0xFF)
      ? 2
      : 0;
  if ((bytes.length - start).isOdd) throw const FormatException('UTF-16 text of an odd length');

  return String.fromCharCodes([
    for (var i = start; i < bytes.length; i += 2) data.getUint16(i, bigEndian ? Endian.big : Endian.little),
  ]);
}

/// A text frame's body for [text]: UTF-8 in v2.4, and in v2.3, which has no
/// UTF-8, UTF-16 with a little-endian byte-order mark. No terminator: the
/// frame's length ends the text.
Uint8List _textBody(String text, int major) => major == 4
    ? Uint8List.fromList([3, ...utf8.encode(text)])
    : Uint8List.fromList([
        1,
        0xFF,
        0xFE,
        for (final unit in text.codeUnits) ...[unit & 0xFF, unit >> 8],
      ]);

/// Whether [frame] is a picture of type 3, the front cover.
///
/// Throws where it is a picture whose type this cannot read: whether it is
/// one the cover replaces cannot be known, and guessing either way is wrong.
bool _isFrontCover(_Frame frame) {
  if (frame.id != 'APIC') return false;
  if (frame.formatFlags != 0) {
    throw const UnsupportedTagException('a compressed or encrypted picture, whose type this cannot read');
  }

  final body = frame.body;
  final mimeEnd = body.isEmpty ? -1 : body.indexOf(0, 1);
  if (mimeEnd == -1 || mimeEnd + 1 >= body.length) throw const FormatException('a picture too short to say its type');

  return body[mimeEnd + 1] == 3;
}

/// A front-cover `APIC` body for [image]: no description. Latin-1 is the
/// encoding every version has, and an empty description is the same in all
/// of them.
Uint8List _pictureBody(Uint8List image) => (BytesBuilder(copy: false)
      ..addByte(0)
      ..add(ascii.encode(_isPng(image) ? 'image/png' : 'image/jpeg'))
      ..add([0, 3, 0])
      ..add(image))
    .toBytes();

/// A frame of [id] holding [body], with no flags.
Uint8List _frame(String id, Uint8List body, int major) {
  final length = body.length;
  if (length > (major == 4 ? _maxSyncSafe : 0xFFFFFFFF)) throw const FormatException('a frame too large for ID3v2');

  return (BytesBuilder(copy: false)
        ..add(ascii.encode(id))
        ..add(major == 4 ? _syncSafe(length) : (ByteData(4)..setUint32(0, length)).buffer.asUint8List())
        ..add(const [0, 0])
        ..add(body))
      .toBytes();
}

/// The number four sync-safe bytes at [offset] say: seven bits to the byte,
/// whose top bit is always clear — and where it is not, not a number this
/// can trust.
int _readSyncSafe(Uint8List bytes, int offset) {
  var value = 0;
  for (var i = offset; i < offset + 4; i++) {
    if (bytes[i] > 0x7F) throw const FormatException('a size that is not sync-safe');
    value = value << 7 | bytes[i];
  }

  return value;
}

Uint8List _syncSafe(int value) =>
    Uint8List.fromList([value >> 21 & 0x7F, value >> 14 & 0x7F, value >> 7 & 0x7F, value & 0x7F]);

const _pngSignature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

bool _isPng(Uint8List image) =>
    image.length >= _pngSignature.length &&
    [for (var i = 0; i < _pngSignature.length; i++) image[i] == _pngSignature[i]].every((same) => same);

bool _startsWith(Uint8List bytes, int offset, String marker) {
  if (bytes.length < offset + marker.length) return false;
  for (var i = 0; i < marker.length; i++) {
    if (bytes[offset + i] != marker.codeUnitAt(i)) return false;
  }

  return true;
}

bool _same(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }

  return true;
}
