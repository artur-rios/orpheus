import 'dart:io';
import 'dart:typed_data';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';

import '../domain/track_metadata.dart';

/// What one file's tags said, and the picture they carried.
class ReadTags {
  /// Creates a result.
  const ReadTags({required this.metadata, this.picture});

  /// The tags, normalised.
  ///
  /// Without a cover id: the picture is stored by whoever is doing the
  /// scanning, and only then is there an id to record.
  final TrackMetadata metadata;

  /// The embedded picture, front cover for preference, or `null` where the
  /// file carries none.
  final Uint8List? picture;
}

/// Reads [file]'s tags.
///
/// Pure Dart, and pure in the other sense too: it touches one file, allocates
/// nothing outside itself, and can therefore be called from an isolate, from a
/// test, and on all three platforms with the same result.
///
/// Throws where the file carries no tags this reader understands, which is a
/// state the scanner records and steps over rather than one it hides — a file
/// whose tags will not parse is very often a file that still plays perfectly
/// well, and it belongs in the library as an untitled track.
ReadTags readTags(File file, {bool withPicture = true}) {
  final tags = readAllMetadata(file, getImage: withPicture);

  return switch (tags) {
    Mp3Metadata() => _fromMp3(tags),
    Mp4Metadata() => _fromMp4(tags),
    VorbisMetadata() => _fromVorbis(tags),
    RiffMetadata() => _fromRiff(tags),
    ApeMetadata() => _fromApe(tags),
  };
}

ReadTags _fromMp3(Mp3Metadata tags) => ReadTags(
  metadata: TrackMetadata(
    title: tags.songName,
    artist: tags.leadPerformer,
    // TPE2. The one common format that carries the record's own artist as a
    // field of its own, which is why an MP3 library groups correctly straight
    // away and the others lean on `albumArtistsAcross`.
    albumArtist: tags.bandOrOrchestra,
    album: tags.album,
    genre: tags.genres.firstOrNull,
    track: tags.trackNumber,
    trackTotal: tags.trackTotal,
    disc: tags.discNumber ?? _discOfPartOfSet(tags.partOfSet),
    year: tags.year,
    duration: tags.duration,
  ),
  picture: _frontCover(tags.pictures),
);

ReadTags _fromMp4(Mp4Metadata tags) => ReadTags(
  metadata: TrackMetadata(
    title: tags.title,
    artist: tags.artist,
    album: tags.album,
    genre: tags.genre,
    track: tags.trackNumber,
    trackTotal: tags.totalTracks,
    disc: tags.discNumber,
    year: tags.year?.year,
    duration: tags.duration,
  ),
  picture: tags.picture?.bytes,
);

ReadTags _fromVorbis(VorbisMetadata tags) => ReadTags(
  metadata: TrackMetadata(
    title: tags.title.firstOrNull,
    // The Vorbis reader folds `ALBUMARTIST` into the same list as `ARTIST`, so
    // the first entry is taken as the performer and the record's own artist is
    // left to `albumArtistsAcross` to work out across the record. That is the
    // same answer for every ordinary album, and for a compilation it is the
    // documented judgement rather than a tag being ignored — see that
    // function.
    artist: tags.artist.firstOrNull,
    album: tags.album.firstOrNull,
    genre: tags.genres.firstOrNull,
    track: tags.trackNumber.firstOrNull,
    trackTotal: tags.trackTotal,
    disc: tags.discNumber,
    year: tags.date.firstOrNull?.year,
    duration: tags.duration,
  ),
  picture: _frontCover(tags.pictures),
);

ReadTags _fromRiff(RiffMetadata tags) => ReadTags(
  metadata: TrackMetadata(
    title: tags.title,
    artist: tags.artist,
    album: tags.album,
    genre: tags.genre,
    track: tags.trackNumber,
    year: tags.year?.year,
    duration: tags.duration,
  ),
  picture: _frontCover(tags.pictures),
);

ReadTags _fromApe(ApeMetadata tags) => ReadTags(
  metadata: TrackMetadata(
    title: tags.title,
    artist: tags.artist,
    albumArtist: tags.albumArtist,
    album: tags.album,
    genre: tags.genres.firstOrNull,
    track: tags.trackNumber,
    trackTotal: tags.trackTotal,
    disc: tags.discNumber,
    year: tags.date?.year,
    duration: tags.duration,
  ),
  picture: _frontCover(tags.pictures),
);

/// The front cover among [pictures], or the first picture where none says it
/// is one.
///
/// A record's back cover, its CD label and the band's logo are all legitimate
/// attachments, and a grid drawn from whichever happened to come first is a
/// grid of the wrong pictures. Where nothing is labelled, the first is as good
/// an answer as there is.
Uint8List? _frontCover(List<Picture> pictures) {
  if (pictures.isEmpty) return null;

  for (final picture in pictures) {
    if (picture.pictureType == PictureType.coverFront) return picture.bytes;
  }

  return pictures.first.bytes;
}

/// The disc number out of an ID3 `TPOS` frame, which is written `1` or `1/2`.
int? _discOfPartOfSet(String? partOfSet) {
  final value = partOfSet?.trim();
  if (value == null || value.isEmpty) return null;

  return int.tryParse(value.split('/').first.trim());
}
