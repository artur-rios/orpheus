import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../../library/domain/audio_file.dart';
import 'autofill_field.dart';

/// The extensions of the formats tags can be written to.
///
/// What `audio_metadata_reader` can write without losing anything, and
/// nothing it can only read: an Ogg or Opus file is in the library and plays,
/// and has its tags left alone.
///
/// None, as of `audio_metadata_reader` 1.8.0. Each format it writes rebuilds
/// the tag from its own model and so drops or rewrites tags it was not asked
/// to change — MP3 its TXXX frames and TDRC date, M4A its album artist
/// (`aART`), comment and encoder, FLAC every comment its model does not name,
/// WAV a year-only ICRD date, APE its `Album Artist` and `Year` items. The
/// preservation tests in `audio_metadata_tag_writer_test.dart` name each loss
/// and are skipped, not deleted: a format comes back here once a package
/// upgrade makes its test pass.
const Set<String> writableExtensions = {};

/// Whether tags can be written to the file at [path] at all.
bool canWriteTagsTo(String path) =>
    writableExtensions.contains(p.extension(path).toLowerCase());

/// What a file's own tags say, and which of them can be written.
///
/// Read from the file rather than from the catalog: the catalog's album artist
/// is partly worked out across the record, and what a change is measured
/// against has to be what the file actually holds.
class FileTags {
  /// Creates the tags.
  const FileTags({required this.writable, this.values = const {}, this.cover});

  /// A file nothing can be written to.
  static const FileTags unwritable = FileTags(writable: {});

  /// The fields this file's format can hold and the writer can write.
  final Set<AutofillField> writable;

  /// The current value of each field the file has: a `String` for the
  /// text fields, an `int` for the numbers and the year.
  final Map<AutofillField, Object?> values;

  /// The embedded front cover, where there is one.
  final Uint8List? cover;
}

/// What became of one file's write.
enum WriteOutcome {
  /// Written.
  written,

  /// Its format cannot be written.
  unsupported,

  /// It is not the file it was when it was read — another program wrote to
  /// it since — so it was left alone rather than overwritten.
  changedSinceRead,

  /// Another program holds it open and the system would not let it be
  /// replaced. On Windows, the track playing.
  inUse,

  /// This process may not write it.
  denied,

  /// Anything else.
  failed,
}

/// Reads and writes a file's tags.
abstract interface class TagWriter {
  /// The tags of the file at [path], and which can be written.
  Future<FileTags> inspect(String path);

  /// Writes [values] into the file at [path], leaving every other tag in it as
  /// it was.
  ///
  /// [expected] is the file as the catalog knows it. A file whose size or
  /// timestamp differs is answered [WriteOutcome.changedSinceRead] and not
  /// touched. A `null` value removes the tag.
  Future<WriteOutcome> write(
    String path,
    Map<AutofillField, Object?> values, {
    required AudioFile expected,
  });
}
