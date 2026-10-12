import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import '../../library/domain/audio_file.dart';
import '../domain/autofill_field.dart';
import '../domain/tag_writer.dart';
import 'atomic_write.dart';
import 'flac_tag_editor.dart';

/// [TagWriter] over `audio_metadata_reader`, which this application already
/// reads every tag through.
///
/// FLAC is written by Orpheus's own editor ([editFlacTags]) instead of the
/// package, whose writer rebuilds the comments from its model and drops every
/// one the model does not name.
///
/// Every field is mapped by hand rather than through the package's common
/// setters: those have no album artist, and quietly do nothing for a field a
/// format cannot hold — which on a review screen would be a change the owner
/// confirmed and that never happened. A field a format cannot hold is instead
/// left out of [FileTags.writable], and the screen says so.
///
/// File work runs on an isolate: a cover is hundreds of kilobytes, and an
/// album is a dozen of them.
class AudioMetadataTagWriter implements TagWriter {
  /// Creates the writer.
  const AudioMetadataTagWriter();

  static final Logger _log = Logger('autofill');

  /// The fields the format of [path] can hold — none for a format outside
  /// [writableExtensions], which a write would lose other tags from.
  ///
  /// The sets below are what each format's write was proved to read back;
  /// they apply once the format passes the preservation gate and returns to
  /// [writableExtensions].
  static Set<AutofillField> fieldsFor(String path) {
    if (!canWriteTagsTo(path)) return const {};

    return switch (p.extension(path).toLowerCase()) {
      '.m4a' || '.mp4' => AutofillField.values.toSet()..remove(AutofillField.albumArtist),
      // Written by Orpheus's own editor rather than the package's: every
      // field, each as the comment the reader reads it from.
      '.flac' => AutofillField.values.toSet(),
      // RIFF INFO has no album artist, track total or disc; and the package
      // writes a year as an ICRD it then cannot read back, and writes no
      // picture at all.
      '.wav' => {
        AutofillField.title,
        AutofillField.artist,
        AutofillField.album,
        AutofillField.trackNumber,
        AutofillField.genre,
      },
      _ => AutofillField.values.toSet(),
    };
  }

  @override
  Future<FileTags> inspect(String path) async {
    final writable = fieldsFor(path);
    if (writable.isEmpty) return FileTags.unwritable;

    try {
      return await Isolate.run(() => _inspect(path, writable));
    } on Object catch (error) {
      _log.info('the tags of $path could not be read', error);

      return FileTags.unwritable;
    }
  }

  @override
  Future<WriteOutcome> write(
    String path,
    Map<AutofillField, Object?> values, {
    required AudioFile expected,
  }) async {
    final writable = fieldsFor(path);
    if (writable.isEmpty) return WriteOutcome.unsupported;
    if (values.keys.any((field) => !writable.contains(field))) {
      return WriteOutcome.unsupported;
    }

    try {
      return await Isolate.run(() => _write(path, values, expected));
    } on Object catch (error) {
      _log.warning('the tags of $path could not be written', error);

      return WriteOutcome.failed;
    }
  }
}

FileTags _inspect(String path, Set<AutofillField> writable) {
  final tags = readAllMetadata(File(path));

  // A FLAC file with an ID3v2 tag in front of its marker is read as an MP3:
  // what the owner would review is that tag, and what a write changes is the
  // Vorbis comments.
  if (p.extension(path).toLowerCase() == '.flac' && tags is! VorbisMetadata) {
    return FileTags.unwritable;
  }

  final values = switch (tags) {
    Mp3Metadata() => {
      AutofillField.title: tags.songName,
      AutofillField.artist: tags.leadPerformer,
      AutofillField.albumArtist: tags.bandOrOrchestra,
      AutofillField.album: tags.album,
      AutofillField.trackNumber: tags.trackNumber,
      AutofillField.trackTotal: tags.trackTotal,
      AutofillField.discNumber: tags.discNumber ?? _first(tags.partOfSet),
      AutofillField.discTotal: tags.totalDics ?? _second(tags.partOfSet),
      AutofillField.year: tags.year,
      AutofillField.genre: tags.genres.firstOrNull,
    },
    Mp4Metadata() => {
      AutofillField.title: tags.title,
      AutofillField.artist: tags.artist,
      AutofillField.album: tags.album,
      AutofillField.trackNumber: tags.trackNumber,
      AutofillField.trackTotal: tags.totalTracks,
      AutofillField.discNumber: tags.discNumber,
      AutofillField.discTotal: tags.totalDiscs,
      AutofillField.year: tags.year?.year,
      AutofillField.genre: tags.genre,
    },
    VorbisMetadata() => {
      AutofillField.title: tags.title.firstOrNull,
      AutofillField.artist: tags.artist.firstOrNull,
      AutofillField.albumArtist: tags.albumArtist.firstOrNull,
      AutofillField.album: tags.album.firstOrNull,
      AutofillField.trackNumber: tags.trackNumber.firstOrNull,
      AutofillField.trackTotal: tags.trackTotal,
      AutofillField.discNumber: tags.discNumber,
      AutofillField.discTotal: tags.discTotal,
      AutofillField.year: tags.date.firstOrNull?.year,
      AutofillField.genre: tags.genres.firstOrNull,
    },
    RiffMetadata() => {
      AutofillField.title: tags.title,
      AutofillField.artist: tags.artist,
      AutofillField.album: tags.album,
      AutofillField.trackNumber: tags.trackNumber,
      AutofillField.year: tags.year?.year,
      AutofillField.genre: tags.genre,
    },
    ApeMetadata() => {
      AutofillField.title: tags.title,
      AutofillField.artist: tags.artist,
      AutofillField.albumArtist: tags.albumArtist,
      AutofillField.album: tags.album,
      AutofillField.trackNumber: tags.trackNumber,
      AutofillField.trackTotal: tags.trackTotal,
      AutofillField.discNumber: tags.discNumber,
      AutofillField.discTotal: tags.discTotal,
      AutofillField.year: tags.date?.year,
      AutofillField.genre: tags.genres.firstOrNull,
    },
  };

  final pictures = switch (tags) {
    Mp3Metadata() => tags.pictures,
    Mp4Metadata() => [?tags.picture],
    VorbisMetadata() => tags.pictures,
    RiffMetadata() => tags.pictures,
    ApeMetadata() => tags.pictures,
  };

  return FileTags(
    writable: writable,
    values: values,
    cover: _front(pictures),
  );
}

WriteOutcome _write(
  String path,
  Map<AutofillField, Object?> values,
  AudioFile expected,
) {
  final file = File(path);

  // The same file the owner reviewed, or nothing: an edit another program
  // made since is not one to overwrite with a proposal made before it.
  final FileStat stat;
  try {
    if (!file.existsSync()) return WriteOutcome.changedSinceRead;
    stat = file.statSync();
  } on FileSystemException {
    return WriteOutcome.denied;
  }
  if (stat.size != expected.sizeInBytes ||
      stat.modified.millisecondsSinceEpoch != expected.modifiedAt.millisecondsSinceEpoch) {
    return WriteOutcome.changedSinceRead;
  }

  if (p.extension(path).toLowerCase() == '.flac') return _writeFlac(path, values, expected);

  try {
    updateMetadata(file, (tags) => _apply(tags, values));
  } on FileSystemException catch (error) {
    return _outcomeOf(error, path);
  }

  return WriteOutcome.written;
}

/// Writes a FLAC file through [editFlacTags], which changes only what it is
/// asked to, and [replaceFileAtomically], which replaces it whole or not at
/// all.
///
/// A file the editor cannot parse safely throws a [FormatException] before
/// anything is written; [AudioMetadataTagWriter.write] logs it and answers
/// [WriteOutcome.failed].
WriteOutcome _writeFlac(
  String path,
  Map<AutofillField, Object?> values,
  AudioFile expected,
) {
  try {
    // The file itself, where the library reaches it through a link: what is
    // read is what is replaced.
    final target = resolvedTarget(path);
    final bytes = File(target).readAsBytesSync();
    // What was read is what is rewritten, so it has to be the file the
    // check above saw.
    if (bytes.length != expected.sizeInBytes) return WriteOutcome.changedSinceRead;

    replaceFileAtomically(target, editFlacTags(bytes, values));
  } on FileSystemException catch (error) {
    return _outcomeOf(error, path);
  }

  return WriteOutcome.written;
}

/// What a refused write was, probing the file where its error alone cannot
/// tell.
///
/// Runs on the writing isolate, so the probe does too.
WriteOutcome _outcomeOf(FileSystemException error, String path) {
  final windows = Platform.isWindows;
  final code = error.osError?.errorCode;
  if (!windows || code != 5) return outcomeFor(windows: windows, code: code);

  // Opening the file for writing, and nothing more: whether it is the file
  // that refuses (read-only) or the rename over it (held open elsewhere).
  // Never on a file that is not there, which opening to append would create.
  if (!File(path).existsSync()) return WriteOutcome.failed;
  try {
    File(path).openSync(mode: FileMode.append).closeSync();
  } on FileSystemException catch (probe) {
    return outcomeFor(windows: windows, code: code, probeCode: probe.osError?.errorCode);
  }

  return outcomeFor(windows: windows, code: code, probeOpened: true);
}

/// What a write that failed with the system error [code] was.
///
/// Windows answers a file another process holds open — the track playing,
/// which libmpv has open — with a sharing (32) or lock (33) violation, and a
/// write-protected medium with 19. Access denied (5) is either: the rename
/// over a file held open, or a read-only file. A probe opening the file for
/// writing tells them apart — [probeOpened] when it could, [probeCode] the
/// error when it could not: opened or held open is in use, denied again is
/// denied.
///
/// Elsewhere a permission error (EPERM 1, EACCES 13, EROFS 30) is denied, and
/// anything else failed.
WriteOutcome outcomeFor({
  required bool windows,
  required int? code,
  int? probeCode,
  bool probeOpened = false,
}) {
  if (!windows) {
    return code == 13 || code == 1 || code == 30 ? WriteOutcome.denied : WriteOutcome.failed;
  }

  return switch (code) {
    32 || 33 => WriteOutcome.inUse,
    19 => WriteOutcome.denied,
    5 when probeOpened || probeCode == 32 || probeCode == 33 => WriteOutcome.inUse,
    5 when probeCode == 5 => WriteOutcome.denied,
    _ => WriteOutcome.failed,
  };
}

// The package's ParserTag, which it does not export: one of the five models
// switched over below.
void _apply(Object tags, Map<AutofillField, Object?> values) {
  String? text(AutofillField field) => values[field] as String?;
  int? number(AutofillField field) => values[field] as int?;
  bool has(AutofillField field) => values.containsKey(field);
  final cover = values[AutofillField.cover] as Uint8List?;
  final picture = cover == null ? null : Picture(cover, _mimeOf(cover), PictureType.coverFront);

  switch (tags) {
    case final Mp3Metadata m:
      if (has(AutofillField.title)) m.songName = text(AutofillField.title);
      if (has(AutofillField.artist)) m.leadPerformer = text(AutofillField.artist);
      if (has(AutofillField.albumArtist)) m.bandOrOrchestra = text(AutofillField.albumArtist);
      if (has(AutofillField.album)) m.album = text(AutofillField.album);
      if (has(AutofillField.trackNumber)) m.trackNumber = number(AutofillField.trackNumber);
      if (has(AutofillField.trackTotal)) m.trackTotal = number(AutofillField.trackTotal);
      if (has(AutofillField.discNumber) || has(AutofillField.discTotal)) {
        final disc = has(AutofillField.discNumber) ? number(AutofillField.discNumber) : (m.discNumber ?? _first(m.partOfSet));
        final total = has(AutofillField.discTotal) ? number(AutofillField.discTotal) : (m.totalDics ?? _second(m.partOfSet));
        m.discNumber = disc;
        m.totalDics = total;
        m.partOfSet = disc == null ? null : (total == null ? '$disc' : '$disc/$total');
      }
      if (has(AutofillField.year)) m.year = number(AutofillField.year);
      if (has(AutofillField.genre)) m.genres = [?text(AutofillField.genre)];
      if (picture != null) {
        m.pictures = [picture, ...m.pictures.where((p) => p.pictureType != PictureType.coverFront)];
      }
    case final Mp4Metadata m:
      if (has(AutofillField.title)) m.title = text(AutofillField.title);
      if (has(AutofillField.artist)) m.artist = text(AutofillField.artist);
      if (has(AutofillField.album)) m.album = text(AutofillField.album);
      if (has(AutofillField.trackNumber)) m.trackNumber = number(AutofillField.trackNumber);
      if (has(AutofillField.trackTotal)) m.totalTracks = number(AutofillField.trackTotal);
      if (has(AutofillField.discNumber)) m.discNumber = number(AutofillField.discNumber);
      if (has(AutofillField.discTotal)) m.totalDiscs = number(AutofillField.discTotal);
      if (has(AutofillField.year)) {
        final year = number(AutofillField.year);
        m.year = year == null ? null : DateTime(year);
      }
      if (has(AutofillField.genre)) m.genre = text(AutofillField.genre);
      if (picture != null) m.picture = picture;
    case final VorbisMetadata m:
      if (has(AutofillField.title)) m.title = [?text(AutofillField.title)];
      if (has(AutofillField.artist)) m.artist = [?text(AutofillField.artist)];
      if (has(AutofillField.albumArtist)) m.albumArtist = [?text(AutofillField.albumArtist)];
      if (has(AutofillField.album)) m.album = [?text(AutofillField.album)];
      if (has(AutofillField.trackNumber)) m.trackNumber = [?number(AutofillField.trackNumber)];
      if (has(AutofillField.trackTotal)) m.trackTotal = number(AutofillField.trackTotal);
      if (has(AutofillField.discNumber)) m.discNumber = number(AutofillField.discNumber);
      if (has(AutofillField.discTotal)) m.discTotal = number(AutofillField.discTotal);
      if (has(AutofillField.year)) {
        final year = number(AutofillField.year);
        m.date = year == null ? [] : [DateTime(year)];
      }
      if (has(AutofillField.genre)) m.genres = [?text(AutofillField.genre)];
      if (picture != null) {
        m.pictures = [picture, ...m.pictures.where((p) => p.pictureType != PictureType.coverFront)];
      }
    case final RiffMetadata m:
      if (has(AutofillField.title)) m.title = text(AutofillField.title);
      if (has(AutofillField.artist)) m.artist = text(AutofillField.artist);
      if (has(AutofillField.album)) m.album = text(AutofillField.album);
      if (has(AutofillField.trackNumber)) m.trackNumber = number(AutofillField.trackNumber);
      if (has(AutofillField.year)) {
        final year = number(AutofillField.year);
        m.year = year == null ? null : DateTime(year);
      }
      if (has(AutofillField.genre)) m.genre = text(AutofillField.genre);
      if (picture != null) {
        m.pictures = [picture, ...m.pictures.where((p) => p.pictureType != PictureType.coverFront)];
      }
    case final ApeMetadata m:
      if (has(AutofillField.title)) m.title = text(AutofillField.title);
      if (has(AutofillField.artist)) m.artist = text(AutofillField.artist);
      if (has(AutofillField.albumArtist)) m.albumArtist = text(AutofillField.albumArtist);
      if (has(AutofillField.album)) m.album = text(AutofillField.album);
      if (has(AutofillField.trackNumber)) m.trackNumber = number(AutofillField.trackNumber);
      if (has(AutofillField.trackTotal)) m.trackTotal = number(AutofillField.trackTotal);
      if (has(AutofillField.discNumber)) m.discNumber = number(AutofillField.discNumber);
      if (has(AutofillField.discTotal)) m.discTotal = number(AutofillField.discTotal);
      if (has(AutofillField.year)) {
        final year = number(AutofillField.year);
        m.date = year == null ? null : DateTime(year);
      }
      if (has(AutofillField.genre)) m.genres = [?text(AutofillField.genre)];
      if (picture != null) {
        m.pictures = [picture, ...m.pictures.where((p) => p.pictureType != PictureType.coverFront)];
      }
  }
}

String _mimeOf(Uint8List bytes) =>
    bytes.length > 3 && bytes[0] == 0x89 && bytes[1] == 0x50 ? 'image/png' : 'image/jpeg';

Uint8List? _front(List<Picture> pictures) {
  for (final picture in pictures) {
    if (picture.pictureType == PictureType.coverFront) return picture.bytes;
  }

  return pictures.firstOrNull?.bytes;
}

int? _first(String? partOfSet) => int.tryParse((partOfSet ?? '').split('/').first.trim());

int? _second(String? partOfSet) {
  final parts = (partOfSet ?? '').split('/');

  return parts.length < 2 ? null : int.tryParse(parts[1].trim());
}
