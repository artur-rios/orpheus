import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

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
/// `covers/`, however its bytes turn out to be stored, and the ids of those
/// left unread for weighing more than [maxBackupCoverBytes].
///
/// An entry is judged by the size its header declares before it is
/// decompressed, so one that declares too much is never inflated; and again by
/// the bytes it yields, because a header can say less than the entry holds.
({Map<String, Uint8List> covers, Set<String> skipped}) _covers(
  Archive archive,
) {
  final covers = <String, Uint8List>{};
  final skipped = <String>{};
  for (final file in archive.files) {
    if (!file.isFile || !file.name.startsWith(backupCoversFolder)) continue;

    final id = file.name.substring(backupCoversFolder.length);
    if (id.isEmpty || id.contains('/')) continue;
    if (file.size > maxBackupCoverBytes) {
      skipped.add(id);
      continue;
    }

    final bytes = file.readBytes();
    if (bytes == null) continue;
    if (bytes.length > maxBackupCoverBytes) {
      skipped.add(id);
      continue;
    }

    covers[id] = bytes;
  }

  return (covers: covers, skipped: skipped);
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
