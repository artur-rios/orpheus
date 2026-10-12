import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import '../../library/domain/audio_file.dart';
import '../domain/autofill_field.dart';
import '../domain/tag_writer.dart';

/// [TagWriter] over `audio_metadata_reader`, which this application already
/// reads every tag through.
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

  /// The fields the format of [path] can hold.
  static Set<AutofillField> fieldsFor(String path) {
    if (!canWriteTagsTo(path)) return const {};

    return switch (p.extension(path).toLowerCase()) {
      '.m4a' || '.mp4' => AutofillField.values.toSet()..remove(AutofillField.albumArtist),
      '.wav' => {
        AutofillField.title,
        AutofillField.artist,
        AutofillField.album,
        AutofillField.trackNumber,
        AutofillField.year,
        AutofillField.genre,
        AutofillField.cover,
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
  }) => throw UnimplementedError('Task 8');
}

FileTags _inspect(String path, Set<AutofillField> writable) {
  final tags = readAllMetadata(File(path));

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
