import 'dart:typed_data';

import '../../autofill/domain/autofill_field.dart';
import '../../autofill/domain/tag_writer.dart';

/// The fields the form edits as text, in the order it shows them: every field
/// but the cover.
const List<AutofillField> editableTextFields = [
  AutofillField.title,
  AutofillField.artist,
  AutofillField.albumArtist,
  AutofillField.album,
  AutofillField.trackNumber,
  AutofillField.trackTotal,
  AutofillField.discNumber,
  AutofillField.discTotal,
  AutofillField.year,
  AutofillField.genre,
];

/// The fields that hold a number, and are written as one.
const Set<AutofillField> numberFields = {
  AutofillField.trackNumber,
  AutofillField.trackTotal,
  AutofillField.discNumber,
  AutofillField.discTotal,
  AutofillField.year,
};

/// What the owner wants done with the front cover.
sealed class CoverChoice {
  const CoverChoice();
}

/// Leave the cover as the file has it.
final class KeepCover extends CoverChoice {
  /// Creates the choice.
  const KeepCover();
}

/// Take the front cover out of the file.
final class RemoveCover extends CoverChoice {
  /// Creates the choice.
  const RemoveCover();
}

/// Put [bytes] in the file as its front cover.
final class ReplaceCover extends CoverChoice {
  /// Creates the choice.
  const ReplaceCover(this.bytes);

  /// The picture, a JPEG or a PNG.
  final Uint8List bytes;
}

/// What the owner typed or picked, field by field.
class TagForm {
  /// Creates a form.
  const TagForm({this.text = const {}, this.cover = const KeepCover()});

  /// Each text field as typed, untrimmed. A field missing here is no change.
  final Map<AutofillField, String> text;

  /// The cover.
  final CoverChoice cover;
}

/// Why a number field's text cannot be written.
enum NumberProblem {
  /// Not a whole number of one or more.
  notAWholeNumber,

  /// Not a year from 1 to 9999.
  yearOutOfRange,
}

/// [field] of [before] as the form shows it: the text of what the file holds,
/// with several values already joined by `shownAsOne` (`Rock; Pop`), or empty.
String shownText(FileTags before, AutofillField field) =>
    before.values[field]?.toString() ?? '';

/// Digits only: `int.tryParse` alone would take `0x10` and `+3`.
final RegExp _digits = RegExp(r'^[0-9]+$');

/// Why [text] is not a value the number [field] can be written as, or `null`
/// where it is — blank included, which removes the tag.
NumberProblem? numberProblem(AutofillField field, String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;

  // `tryParse` answers null for a number too large for an int.
  final value = _digits.hasMatch(trimmed) ? int.tryParse(trimmed) : null;
  if (field == AutofillField.year) {
    return value == null || value < 1 || value > 9999
        ? NumberProblem.yearOutOfRange
        : null;
  }

  return value == null || value < 1 ? NumberProblem.notAWholeNumber : null;
}

/// The number fields of [form] the owner changed into something that cannot
/// be written.
///
/// Only changed ones: a field the file holds twice is shown as `3; 4`, which
/// is not a number, and must not stop a save the owner made elsewhere.
Map<AutofillField, NumberProblem> numberProblems(
  FileTags before,
  TagForm form,
) => {
  for (final field in numberFields)
    if (_changedText(before, form, field) case final text?)
      field: ?numberProblem(field, text),
};

/// What [form] changes in a file holding [before]: each changed field and
/// the value to write, `null` removing the tag. Empty when nothing changed.
///
/// A field [before] cannot write is never in it, nor is a number with a
/// [numberProblem] — callers check [numberProblems] before saving.
Map<AutofillField, Object?> tagEdits(FileTags before, TagForm form) {
  final edits = <AutofillField, Object?>{};

  for (final field in editableTextFields) {
    final text = _changedText(before, form, field);
    if (text == null) continue;

    if (text.isEmpty) {
      edits[field] = null;
    } else if (!numberFields.contains(field)) {
      edits[field] = text;
    } else if (numberProblem(field, text) == null) {
      // `03` over a file's 3 is the same number, and no change.
      final number = int.parse(text);
      if (number != before.values[field]) edits[field] = number;
    }
  }

  if (before.writable.contains(AutofillField.cover)) {
    switch (form.cover) {
      case KeepCover():
        break;
      case RemoveCover():
        if (before.cover != null) edits[AutofillField.cover] = null;
      case ReplaceCover(:final bytes):
        if (!_sameBytes(bytes, before.cover)) {
          edits[AutofillField.cover] = bytes;
        }
    }
  }

  return edits;
}

/// Whether [bytes] are a JPEG or a PNG, by their first bytes — the two
/// pictures every tag format and every reader agree on.
bool isSupportedCover(Uint8List bytes) =>
    _startsWith(bytes, const [0xFF, 0xD8, 0xFF]) ||
    _startsWith(bytes, const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);

/// [field]'s text in [form], trimmed, where the owner changed it and the file
/// can hold it; `null` otherwise.
String? _changedText(FileTags before, TagForm form, AutofillField field) {
  if (!before.writable.contains(field)) return null;

  final typed = form.text[field];
  if (typed == null) return null;

  final trimmed = typed.trim();
  return trimmed == shownText(before, field).trim() ? null : trimmed;
}

bool _startsWith(Uint8List bytes, List<int> prefix) {
  if (bytes.length < prefix.length) return false;
  for (var i = 0; i < prefix.length; i++) {
    if (bytes[i] != prefix[i]) return false;
  }

  return true;
}

bool _sameBytes(Uint8List left, Uint8List? right) {
  if (right == null || left.length != right.length) return false;
  for (var i = 0; i < left.length; i++) {
    if (left[i] != right[i]) return false;
  }

  return true;
}
