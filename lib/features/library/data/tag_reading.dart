import 'dart:io';
import 'dart:typed_data';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';

import '../domain/genres.dart';
import '../domain/track_metadata.dart';
import 'id3_genres.dart';
import 'id3v2_frames.dart';

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
    Mp3Metadata() => _fromMp3(tags, file),
    Mp4Metadata() => _fromMp4(tags),
    VorbisMetadata() => _fromVorbis(tags),
    RiffMetadata() => _fromRiff(tags),
    ApeMetadata() => _fromApe(tags),
  };
}

ReadTags _fromMp3(Mp3Metadata tags, File file) => ReadTags(
  metadata: TrackMetadata(
    title: tags.songName,
    artist: tags.leadPerformer,
    // TPE2: the record's own artist, as a field of its own. Where a file
    // leaves it out, `albumArtistsAcross` works the answer out across the
    // record.
    albumArtist: tags.bandOrOrchestra,
    album: tags.album,
    genres: splitGenres(_mp3Genres(tags, file)),
    track: tags.trackNumber,
    trackTotal: tags.trackTotal,
    disc: tags.discNumber ?? _discOfPartOfSet(tags.partOfSet),
    year: tags.year,
    duration: tags.duration,
  ),
  picture: _frontCover(tags.pictures),
);

/// The genre values of an MP3, before they are split.
///
/// Read from the ID3v2 tag's own genre frame where there is one, because the
/// package keeps only the first value of a v2.4 frame and cuts *Hip-Hop/Rap* in
/// two at its slash. A file with no ID3v2 genre frame — an ID3v1-only file, for
/// one — has the package's answer instead; a frame that exists and resolves to
/// nothing is an answer too, and is not second-guessed.
Iterable<String?> _mp3Genres(Mp3Metadata tags, File file) {
  try {
    final tag = readId3v2Tag(file);
    final values = tag == null ? null : id3GenreValues(tag);
    if (values != null) return values;
  } on Object {
    // Broad by intent: a tag head that cannot be read again is not worth
    // losing the whole file's tags over, and the package has already read
    // everything else from it.
  }

  return tags.genres;
}

/// MP4 carries a record's own artist in `aART`, and this reader folds it into
/// the same `artist` field as `©ART` rather than surfacing it separately —
/// there is no album-artist field here to read. So an MP4 library leans on
/// `albumArtistsAcross` to work the record out across its tracks.
ReadTags _fromMp4(Mp4Metadata tags) => ReadTags(
  metadata: TrackMetadata(
    title: tags.title,
    artist: tags.artist,
    album: tags.album,
    genres: splitGenres([tags.genre]),
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
    artist: tags.artist.firstOrNull,
    // `ALBUMARTIST`, or `ALBUM_ARTIST` as FFmpeg spells it, which the reader
    // keeps in a list of its own. An earlier version of the reader folded it
    // into `ARTIST`, and this went on assuming so after it stopped — which
    // left every FLAC and Ogg compilation to `albumArtistsAcross` to guess at,
    // and filed it under whichever guest had the most tracks on it, while the
    // tag that said "Various Artists" sat unread.
    //
    // The first value that says anything: a comment can be present and blank,
    // and a blank album artist is no album artist at all.
    albumArtist: _firstNonBlank(tags.albumArtist),
    album: tags.album.firstOrNull,
    genres: splitGenres(tags.genres),
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
    genres: splitGenres([tags.genre]),
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
    genres: splitGenres(tags.genres),
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

/// The first of [values] that is not blank, or `null` where none says
/// anything.
String? _firstNonBlank(List<String> values) {
  for (final value in values) {
    if (value.trim().isNotEmpty) return value;
  }

  return null;
}

/// The disc number out of an ID3 `TPOS` frame, which is written `1` or `1/2`.
int? _discOfPartOfSet(String? partOfSet) {
  final value = partOfSet?.trim();
  if (value == null || value.isEmpty) return null;

  return int.tryParse(value.split('/').first.trim());
}
