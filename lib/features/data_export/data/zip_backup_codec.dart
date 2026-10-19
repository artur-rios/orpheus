import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';

import '../../tag_editor/domain/tag_edits.dart';
import '../domain/backup.dart';
import '../domain/data_export.dart';

/// [data], [preferences] and [covers] as a backup ZIP.
///
/// `data.json` is [data] encoded exactly as the JSON export writes it. Each
/// cover is stored under `covers/` by its playlist id. Plain values in and
/// bytes out, so it can be run off the UI isolate.
Uint8List encodeBackupZip({
  required Map<String, Object?> data,
  required PreferencesSnapshot preferences,
  required Map<String, Uint8List> covers,
  required DateTime createdAt,
  String? orpheusVersion,
}) {
  final manifest = backupManifest(
    createdAt: createdAt,
    orpheusVersion: orpheusVersion,
    contents: [
      backupDataFile,
      backupPreferencesFile,
      for (final id in covers.keys) '$backupCoversFolder$id',
    ],
  );

  final archive = Archive()
    ..add(ArchiveFile.bytes(backupManifestFile, _json(manifest)))
    ..add(ArchiveFile.bytes(backupDataFile, encodeDataExport(data)))
    ..add(
      ArchiveFile.bytes(backupPreferencesFile, _json(preferences.toJson())),
    );
  for (final MapEntry(:key, :value) in covers.entries) {
    archive.add(ArchiveFile.bytes('$backupCoversFolder$key', value));
  }

  return ZipEncoder().encodeBytes(archive);
}

/// What [bytes], a backup ZIP or a data JSON, hold.
///
/// Throws a [BackupReadFailure]: [NotABackup] for anything that is neither,
/// [NewerBackupVersion] for a file from a release newer than this one. Plain
/// bytes in and plain values out, so it can be run off the UI isolate.
BackupContents readBackup(Uint8List bytes) {
  try {
    return _isZip(bytes) ? _readZip(bytes) : _readDataJson(bytes);
  } on BackupReadFailure {
    rethrow;
  } on Object {
    // A truncated archive, bytes that are not UTF-8, JSON that does not parse:
    // all of them are one answer for the owner.
    throw const NotABackup();
  }
}

BackupContents _readDataJson(Uint8List bytes) {
  final data = _object(bytes);
  checkDataDocument(data);

  return BackupContents(
    data: data,
    preferences: null,
    covers: const {},
    createdAt: _time(data['exportedAt']),
    isFullBackup: false,
  );
}

BackupContents _readZip(Uint8List bytes) {
  final archive = ZipDecoder().decodeBytes(bytes);

  final manifestBytes = archive.findFile(backupManifestFile)?.readBytes();
  if (manifestBytes == null) throw const NotABackup();
  final manifest = _object(manifestBytes);
  checkBackupManifest(manifest);

  final dataBytes = archive.findFile(backupDataFile)?.readBytes();
  if (dataBytes == null) throw const NotABackup();
  final data = _object(dataBytes);
  checkDataDocument(data);

  final (:covers, :skipped) = _covers(archive);

  return BackupContents(
    data: data,
    preferences: _preferences(archive.findFile(backupPreferencesFile)),
    covers: covers,
    skippedCovers: skipped,
    createdAt: _time(manifest['createdAt']),
    isFullBackup: true,
  );
}

/// The covers in [archive] by playlist id: each file directly under
/// `covers/`, and the ids of those left out.
///
/// A cover is left out when it weighs more than [maxBackupCoverBytes]
/// uncompressed, or when it cannot be read: a damaged stream, or bytes that
/// are not a JPEG or a PNG — which is how an entry in a compression this
/// reader does not know comes out, since the ZIP reader takes it for stored.
/// One bad cover is passed over and the rest of the backup is read.
///
/// The weight is judged three ways, because the header that declares it is
/// the file's word and no more. An entry declaring too much is not read. A
/// stored entry is as large as its bytes, which are checked before they are
/// copied. A deflated entry is inflated by [inflateRawWithin], which stops at
/// the limit, so one whose header lies about its size never grows past it in
/// memory.
({Map<String, Uint8List> covers, Set<String> skipped}) _covers(
  Archive archive,
) {
  final covers = <String, Uint8List>{};
  final skipped = <String>{};
  for (final file in archive.files) {
    if (!file.isFile || !file.name.startsWith(backupCoversFolder)) continue;

    final id = file.name.substring(backupCoversFolder.length);
    if (id.isEmpty || id.contains('/')) continue;
    final content = file.rawContent;
    if (content == null) continue;

    Uint8List? bytes;
    try {
      bytes = _coverBytes(file, content);
    } on Object {
      bytes = null;
    }

    if (bytes == null || !isSupportedCover(bytes)) {
      skipped.add(id);
    } else {
      covers[id] = bytes;
    }
  }

  return (covers: covers, skipped: skipped);
}

/// The bytes of the cover [file], or `null` when it is over the limit or is
/// stored in a way a backup is not written in.
Uint8List? _coverBytes(ArchiveFile file, FileContent content) {
  if (file.size > maxBackupCoverBytes) return null;

  // The entry as the ZIP holds it, still compressed.
  final raw = content.getStream(decompress: false);
  switch (file.compression) {
    case CompressionType.none:
      return raw.length > maxBackupCoverBytes ? null : raw.toUint8List();
    case CompressionType.deflate:
      return inflateRawWithin(_pieces(raw), maxBackupCoverBytes);
    case CompressionType.bzip2 || null:
      return null;
  }
}

/// [stream] in pieces of 64 KB, read as they are asked for.
Iterable<Uint8List> _pieces(InputStream stream) sync* {
  const size = 64 * 1024;
  while (!stream.isEOS) {
    yield stream.readBytes(size).toUint8List();
  }
}

/// The raw deflate stream made of [compressed], inflated, or `null` once it
/// has produced more than [limit] bytes.
///
/// Fed piece by piece into a decoder whose output is counted as it comes, so
/// the work stops at the limit rather than after the whole stream has been
/// inflated: a few kilobytes can stand for gigabytes, and the size a ZIP
/// declares for an entry says nothing about it. Throws a [FormatException]
/// for a stream that is damaged or ends early.
@visibleForTesting
Uint8List? inflateRawWithin(Iterable<Uint8List> compressed, int limit) {
  final output = BytesBuilder(copy: false);
  final decoder = ZLibCodec(
    raw: true,
  ).decoder.startChunkedConversion(_LimitedSink(output, limit));

  try {
    for (final piece in compressed) {
      decoder.add(piece);
    }
    decoder.close();
  } on _OverTheLimit {
    return null;
  }

  return output.takeBytes();
}

/// Thrown by [_LimitedSink] to stop an inflate that has passed its limit.
class _OverTheLimit implements Exception {
  const _OverTheLimit();
}

/// Collects what a decoder produces, and refuses more than [limit] bytes.
class _LimitedSink implements Sink<List<int>> {
  _LimitedSink(this._output, this._limit);

  final BytesBuilder _output;
  final int _limit;

  @override
  void add(List<int> data) {
    if (_output.length + data.length > _limit) throw const _OverTheLimit();

    _output.add(data);
  }

  @override
  void close() {}
}

/// The preferences in [file], or `null` when it is absent or not a document.
PreferencesSnapshot? _preferences(ArchiveFile? file) {
  final bytes = file?.readBytes();
  if (bytes == null) return null;

  try {
    return PreferencesSnapshot.fromJson(_object(bytes));
  } on Object {
    return null;
  }
}

/// Whether [bytes] start the way a ZIP does (`PK`).
bool _isZip(Uint8List bytes) =>
    bytes.length >= 4 && bytes[0] == 0x50 && bytes[1] == 0x4b;

/// [bytes] as a JSON object, or a [NotABackup] when they are anything else.
Map<String, Object?> _object(Uint8List bytes) {
  final decoded = jsonDecode(utf8.decode(bytes));
  if (decoded is! Map) throw const NotABackup();

  return Map<String, Object?>.from(decoded);
}

DateTime? _time(Object? value) =>
    value is String ? DateTime.tryParse(value)?.toUtc() : null;

Uint8List _json(Map<String, Object?> document) {
  const encoder = JsonEncoder.withIndent('  ');

  return Uint8List.fromList(utf8.encode('${encoder.convert(document)}\n'));
}
