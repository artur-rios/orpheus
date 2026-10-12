import 'dart:convert';
import 'dart:typed_data';

import '../domain/autofill_field.dart';
import '../domain/tag_writer.dart';

/// [file], a whole FLAC file, with [values] written into its tags — and every
/// other byte of it as it was.
///
/// Only the VORBIS_COMMENT block and the front-cover PICTURE blocks change.
/// In the comments, each field in [values] replaces every comment under any
/// of its keys (see [_keys]), in the place of the first of them or at the end
/// where there was none; every other comment is kept byte for byte, in its
/// order, and so is the vendor string. A `null` value removes the field's
/// comments and writes none. Every other block (STREAMINFO, padding, seek
/// table, application data, cue sheet, every other picture), a leading ID3v2
/// tag and the audio are copied as they are. Only the last-block flag moves,
/// onto whichever block is now the last.
///
/// Throws a [FormatException], having changed nothing, where [file] cannot be
/// parsed safely: it is not FLAC, a block or a comment runs past its end, or
/// a block would grow past what a FLAC length can say.
///
/// Pure: it reads nothing and writes nothing but the bytes it returns.
Uint8List editFlacTags(Uint8List file, Map<AutofillField, Object?> values) {
  final source = _parse(file);
  final blocks = [...source.blocks];
  final writesCover = values.containsKey(AutofillField.cover);

  if (values.keys.any((field) => field != AutofillField.cover) || writesCover) {
    final at = blocks.indexWhere((block) => block.type == _vorbisComment);
    if (at == -1) {
      final comments = _editComments(const [], values);
      // After STREAMINFO, which must stay first.
      if (comments.isNotEmpty) {
        blocks.insert(1, (
          type: _vorbisComment,
          body: _encodeComments(utf8.encode('Orpheus'), comments, Uint8List(0)),
        ));
      }
    } else {
      final parsed = _parseComments(blocks[at].body);
      blocks[at] = (
        type: _vorbisComment,
        body: _encodeComments(
          parsed.vendor,
          _editComments(parsed.comments, values),
          parsed.rest,
        ),
      );
    }
  }

  if (writesCover) {
    final firstFront = blocks.indexWhere(_isFrontCover);
    blocks.removeWhere(_isFrontCover);
    final cover = values[AutofillField.cover] as Uint8List?;
    if (cover != null) {
      final comments = blocks.indexWhere(
        (block) => block.type == _vorbisComment,
      );
      final at = firstFront != -1
          ? firstFront
          : (comments != -1 ? comments + 1 : 1);
      blocks.insert(at, (type: _picture, body: _pictureBody(cover)));
    }
  }

  final result = _encode(source.head, blocks, source.audio);

  // What the edit must never do, checked on what it produced rather than
  // trusted: the result parses, and what comes before the metadata and the
  // audio after it are the very bytes they were.
  final written = _parse(result);
  if (!_same(written.head, source.head) ||
      !_same(written.audio, source.audio)) {
    throw StateError('the edit changed bytes outside the tags');
  }

  return result;
}

const _streamInfo = 0;
const _vorbisComment = 4;
const _picture = 6;

/// The largest body a block's 24-bit length can say.
const _maxBlockLength = 0xFFFFFF;

/// One metadata block: its type, and its body as the file holds it.
typedef _Block = ({int type, Uint8List body});

/// A FLAC file split into what precedes its metadata (an optional ID3v2 tag
/// and the `fLaC` marker), its metadata blocks, and its audio.
typedef _Flac = ({Uint8List head, List<_Block> blocks, Uint8List audio});

_Flac _parse(Uint8List file) {
  var offset = 0;

  // Some taggers put an ID3v2 tag in front of the marker. It is kept as it
  // is: it is not this editor's to change.
  if (_startsWith(file, 0, 'ID3')) {
    if (file.length < 10) throw const FormatException('a truncated ID3v2 tag');
    final size = file.sublist(6, 10);
    if (size.any((byte) => byte > 0x7F)) {
      throw const FormatException('an ID3v2 size that is not sync-safe');
    }
    final footer = file[5] & 0x10 != 0 ? 10 : 0;
    offset =
        10 + (size[0] << 21 | size[1] << 14 | size[2] << 7 | size[3]) + footer;
  }
  if (!_startsWith(file, offset, 'fLaC')) {
    throw const FormatException('not a FLAC file');
  }
  offset += 4;
  final head = Uint8List.sublistView(file, 0, offset);

  final blocks = <_Block>[];
  var last = false;
  while (!last) {
    if (offset + 4 > file.length) {
      throw const FormatException('the metadata ends before its last block');
    }
    last = file[offset] & 0x80 != 0;
    final type = file[offset] & 0x7F;
    if (type == 127) {
      throw const FormatException('an invalid metadata block type');
    }
    final end =
        offset +
        4 +
        (file[offset + 1] << 16 | file[offset + 2] << 8 | file[offset + 3]);
    if (end > file.length) {
      throw const FormatException(
        'a metadata block runs past the end of the file',
      );
    }
    blocks.add((
      type: type,
      body: Uint8List.sublistView(file, offset + 4, end),
    ));
    offset = end;
  }

  if (blocks.first.type != _streamInfo) {
    throw const FormatException('the first metadata block is not STREAMINFO');
  }
  if (blocks.where((block) => block.type == _vorbisComment).length > 1) {
    throw const FormatException('more than one VORBIS_COMMENT block');
  }

  return (
    head: head,
    blocks: blocks,
    audio: Uint8List.sublistView(file, offset),
  );
}

Uint8List _encode(Uint8List head, List<_Block> blocks, Uint8List audio) {
  final bytes = BytesBuilder(copy: false)..add(head);
  for (final (index, block) in blocks.indexed) {
    final length = block.body.length;
    if (length > _maxBlockLength) {
      throw const FormatException('a metadata block too large for FLAC');
    }
    bytes
      ..add([
        (index == blocks.length - 1 ? 0x80 : 0) | block.type,
        length >> 16 & 0xFF,
        length >> 8 & 0xFF,
        length & 0xFF,
      ])
      ..add(block.body);
  }
  bytes.add(audio);

  return bytes.toBytes();
}

/// A VORBIS_COMMENT body: the vendor string, the comments, each as its raw
/// `KEY=value` bytes, and whatever follows the last comment.
typedef _Comments = ({
  Uint8List vendor,
  List<Uint8List> comments,
  Uint8List rest,
});

/// Every length here is little-endian, unlike every other length in FLAC.
_Comments _parseComments(Uint8List body) {
  final data = ByteData.sublistView(body);
  var offset = 0;
  int length() {
    if (offset + 4 > body.length) {
      throw const FormatException('a VORBIS_COMMENT block that ends early');
    }
    final value = data.getUint32(offset, Endian.little);
    offset += 4;

    return value;
  }

  Uint8List take(int length) {
    if (length > body.length - offset) {
      throw const FormatException('a comment runs past the end of its block');
    }
    final value = Uint8List.sublistView(body, offset, offset + length);
    offset += length;

    return value;
  }

  final vendor = take(length());
  final count = length();
  final comments = [for (var i = 0; i < count; i++) take(length())];

  return (
    vendor: vendor,
    comments: comments,
    rest: Uint8List.sublistView(body, offset),
  );
}

Uint8List _encodeComments(
  Uint8List vendor,
  List<Uint8List> comments,
  Uint8List rest,
) {
  Uint8List length(int value) =>
      (ByteData(4)..setUint32(0, value, Endian.little)).buffer.asUint8List();

  final bytes = BytesBuilder(copy: false)
    ..add(length(vendor.length))
    ..add(vendor)
    ..add(length(comments.length));
  for (final comment in comments) {
    bytes
      ..add(length(comment.length))
      ..add(comment);
  }
  bytes.add(rest);

  return bytes.toBytes();
}

/// The key each field is written under, and every key it replaces — the
/// spellings other taggers use for the same field included, so that the one
/// written is the one read back.
const _keys = <AutofillField, ({String key, Set<String> replaces})>{
  AutofillField.title: (key: 'TITLE', replaces: {'TITLE'}),
  AutofillField.artist: (key: 'ARTIST', replaces: {'ARTIST'}),
  AutofillField.albumArtist: (
    key: 'ALBUMARTIST',
    replaces: {'ALBUMARTIST', 'ALBUM_ARTIST', 'ALBUM ARTIST'},
  ),
  AutofillField.album: (key: 'ALBUM', replaces: {'ALBUM'}),
  // The reader takes iTunes' CDDB track number for a track number too, and
  // the first of them it meets wins: left in place, an old one could still
  // be what is read back.
  AutofillField.trackNumber: (
    key: 'TRACKNUMBER',
    replaces: {'TRACKNUMBER', 'ITUNES_CDDB_TRACKNUMBER'},
  ),
  AutofillField.trackTotal: (
    key: 'TRACKTOTAL',
    replaces: {'TRACKTOTAL', 'TOTALTRACKS'},
  ),
  AutofillField.discNumber: (key: 'DISCNUMBER', replaces: {'DISCNUMBER'}),
  AutofillField.discTotal: (
    key: 'DISCTOTAL',
    replaces: {'DISCTOTAL', 'TOTALDISCS'},
  ),
  AutofillField.year: (key: 'DATE', replaces: {'DATE', 'YEAR'}),
  AutofillField.genre: (key: 'GENRE', replaces: {'GENRE'}),
};

/// What a write of each field into [file], a whole FLAC file, replaces: the
/// value of every comment under every key [editFlacTags] removes for it (see
/// [_keys]), in the order the file holds them, as [shownAsOne] puts them —
/// what the owner reviews as the field's "before".
///
/// The reader reads some of those keys and not others: `ALBUM ARTIST` and
/// `YEAR` it leaves alone, and a write removes them all the same. A text
/// field is every value, as the comment spells it. A number or a year is
/// each value read as the reader reads it.
///
/// A field with no comment is left out, for the reader to say.
///
/// Throws a [FormatException], as [editFlacTags] does, where [file] cannot be
/// parsed safely.
///
/// Pure: it reads nothing but [file].
Map<AutofillField, Object?> flacReplacedValues(Uint8List file) {
  final block = _parse(file).blocks
      .where((block) => block.type == _vorbisComment)
      .firstOrNull;
  if (block == null) return {};
  final comments = _parseComments(block.body).comments;
  final replaced = <AutofillField, Object?>{};

  for (final MapEntry(key: field, value: (:replaces, key: _))
      in _keys.entries) {
    final texts = [
      for (final comment in comments)
        if (replaces.contains(_keyOf(comment)))
          utf8.decode(
            Uint8List.sublistView(comment, comment.indexOf(0x3D) + 1),
            allowMalformed: true,
          ),
    ];
    if (texts.isEmpty) continue;

    replaced[field] = shownAsOne(switch (field) {
      AutofillField.trackNumber || AutofillField.discNumber => texts.map(
        (text) => int.tryParse(text.split('/').first),
      ),
      AutofillField.trackTotal ||
      AutofillField.discTotal => texts.map(int.tryParse),
      AutofillField.year => texts.map(_year),
      _ => texts,
    });
  }

  return replaced;
}

/// The year of a `DATE` (or `YEAR`) value, as the reader reads a date: a
/// whole date, or what comes before a `/`, or a bare number.
int? _year(String text) =>
    DateTime.tryParse(text)?.year ??
    (text.contains('/')
        ? int.tryParse(text.split('/').first)
        : int.tryParse(text));

/// The fields a comment can hold a number and its total in, as `3/12`.
const _numbered = [
  (number: AutofillField.trackNumber, total: AutofillField.trackTotal),
  (number: AutofillField.discNumber, total: AutofillField.discTotal),
];

List<Uint8List> _editComments(
  List<Uint8List> comments,
  Map<AutofillField, Object?> values,
) {
  final fields = [
    for (final field in AutofillField.values)
      if (field != AutofillField.cover && values.containsKey(field)) field,
  ];
  final replacedBy = <String, AutofillField>{
    for (final field in fields)
      for (final key in _keys[field]!.replaces) key: field,
  };
  final written = <AutofillField, Uint8List?>{
    for (final field in fields) field: _comment(field, values[field]),
  };

  // A number written on its own leaves a total in `3/12` with nowhere to go,
  // and a total written on its own leaves the `/12` disagreeing with it. So
  // the number is made plain and the total gets a comment of its own.
  final rewritten = <int, Uint8List?>{};
  final appended = <Uint8List>[];
  for (final (:number, :total) in _numbered) {
    if (!values.containsKey(number) && !values.containsKey(total)) continue;

    Uint8List? movedTotal;
    for (final (index, comment) in comments.indexed) {
      if (!_keys[number]!.replaces.contains(_keyOf(comment))) continue;
      final equals = comment.indexOf(0x3D);
      final slash = comment.indexOf(0x2F, equals);
      if (slash == -1) continue;

      movedTotal ??= _trim(Uint8List.sublistView(comment, slash + 1));
      if (!values.containsKey(number)) {
        // The number as the file spells it (`03` stays `03`), under the key
        // as the file spells it.
        final plain = _trim(Uint8List.sublistView(comment, equals + 1, slash));
        rewritten[index] = plain.isEmpty
            ? null
            : Uint8List.fromList([
                ...Uint8List.sublistView(comment, 0, equals + 1),
                ...plain,
              ]);
      }
    }

    final hasTotal = comments.any(
      (comment) => _keys[total]!.replaces.contains(_keyOf(comment)),
    );
    if (!values.containsKey(total) &&
        !hasTotal &&
        movedTotal != null &&
        movedTotal.isNotEmpty) {
      // Moved only as a number, which is all the reader takes a total as: a
      // total it cannot parse would make the whole file unreadable to it.
      if (movedTotal.any((byte) => byte < 0x30 || byte > 0x39)) {
        throw const FormatException(
          'a total that is not a number, which making the number plain would lose',
        );
      }
      appended.add(
        Uint8List.fromList([
          ...utf8.encode('${_keys[total]!.key}='),
          ...movedTotal,
        ]),
      );
    }
  }

  final replacesFrontCover = values.containsKey(AutofillField.cover);
  final placed = <AutofillField>{};
  final result = <Uint8List>[];
  for (final (index, comment) in comments.indexed) {
    final field = replacedBy[_keyOf(comment)];
    if (field != null) {
      if (placed.add(field)) result.addAll([?written[field]]);
    } else if (rewritten.containsKey(index)) {
      result.addAll([?rewritten[index]]);
    } else if (!(replacesFrontCover && _isEmbeddedFrontCover(comment))) {
      result.add(comment);
    }
  }
  for (final field in fields) {
    if (!placed.contains(field)) result.addAll([?written[field]]);
  }

  return result..addAll(appended);
}

/// The comment [field] is written as, holding [value]; `null` for none.
Uint8List? _comment(AutofillField field, Object? value) {
  if (value == null) return null;

  final text = switch ((field, value)) {
    (AutofillField.year, final int year) => '$year'.padLeft(4, '0'),
    (
      AutofillField.trackNumber ||
          AutofillField.trackTotal ||
          AutofillField.discNumber ||
          AutofillField.discTotal,
      final int number,
    ) =>
      '$number',
    (
      AutofillField.title ||
          AutofillField.artist ||
          AutofillField.albumArtist ||
          AutofillField.album ||
          AutofillField.genre,
      final String text,
    ) =>
      text,
    _ => throw ArgumentError.value(
      value,
      field.name,
      'not a value this field holds',
    ),
  };

  return utf8.encode('${_keys[field]!.key}=$text');
}

/// [comment]'s key in upper case, or `null` for a comment with no `=`.
///
/// Keys are ASCII and compared without regard to case; only ASCII letters
/// are folded, so no other byte can fold into a key this editor writes.
String? _keyOf(Uint8List comment) {
  final equals = comment.indexOf(0x3D);
  if (equals == -1) return null;

  return String.fromCharCodes([
    for (final byte in Uint8List.sublistView(comment, 0, equals))
      byte >= 0x61 && byte <= 0x7A ? byte - 0x20 : byte,
  ]);
}

/// Whether [comment] is a picture embedded the Ogg way, base64 in a
/// `METADATA_BLOCK_PICTURE` comment, and a front cover — which the reader
/// takes for one as readily as a PICTURE block.
bool _isEmbeddedFrontCover(Uint8List comment) {
  if (_keyOf(comment) != 'METADATA_BLOCK_PICTURE') return false;

  // The first eight characters are the first six bytes, the picture type
  // among them.
  final start = comment.indexOf(0x3D) + 1;
  if (comment.length - start < 8) return false;
  try {
    final head = base64Decode(
      String.fromCharCodes(Uint8List.sublistView(comment, start, start + 8)),
    );

    return ByteData.sublistView(head).getUint32(0) == 3;
  } on FormatException {
    // Not a picture this can read, and so not one to remove.
    return false;
  }
}

/// Whether [block] is a picture of type 3, the front cover. A picture too
/// short to say its type is kept, as every block this cannot read is.
bool _isFrontCover(_Block block) =>
    block.type == _picture &&
    block.body.length >= 4 &&
    ByteData.sublistView(block.body).getUint32(0) == 3;

/// A front-cover PICTURE body for [image]: no description, and no
/// dimensions, colour depth or palette size — zero says "not given", and
/// every reader takes them from the image itself.
Uint8List _pictureBody(Uint8List image) {
  final mime = ascii.encode(_isPng(image) ? 'image/png' : 'image/jpeg');
  Uint8List u32(int value) =>
      (ByteData(4)..setUint32(0, value)).buffer.asUint8List();

  return (BytesBuilder(copy: false)
        ..add(u32(3))
        ..add(u32(mime.length))
        ..add(mime)
        ..add(u32(0))
        ..add(u32(0))
        ..add(u32(0))
        ..add(u32(0))
        ..add(u32(0))
        ..add(u32(image.length))
        ..add(image))
      .toBytes();
}

const _pngSignature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

bool _isPng(Uint8List image) =>
    image.length >= _pngSignature.length &&
    [
      for (var i = 0; i < _pngSignature.length; i++)
        image[i] == _pngSignature[i],
    ].every((same) => same);

bool _startsWith(Uint8List bytes, int offset, String marker) {
  if (bytes.length < offset + marker.length) return false;
  for (var i = 0; i < marker.length; i++) {
    if (bytes[offset + i] != marker.codeUnitAt(i)) return false;
  }

  return true;
}

/// [bytes] without the spaces and tabs around them.
Uint8List _trim(Uint8List bytes) {
  bool blank(int byte) => byte == 0x20 || byte == 0x09;
  var start = 0;
  var end = bytes.length;
  while (start < end && blank(bytes[start])) {
    start++;
  }
  while (end > start && blank(bytes[end - 1])) {
    end--;
  }

  return Uint8List.sublistView(bytes, start, end);
}

bool _same(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }

  return true;
}
