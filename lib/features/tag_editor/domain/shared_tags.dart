import 'dart:typed_data';

import '../../autofill/domain/autofill_field.dart';
import '../../autofill/domain/tag_writer.dart';
import 'tag_edits.dart';

/// The fields the form over several files edits as text, in the order it shows
/// them: every text field but the title and the track number, which one value
/// for every file would almost always get wrong.
const List<AutofillField> sharedTextFields = [
  AutofillField.artist,
  AutofillField.albumArtist,
  AutofillField.album,
  AutofillField.trackTotal,
  AutofillField.discNumber,
  AutofillField.discTotal,
  AutofillField.year,
  AutofillField.genre,
];

/// What one field holds across several files.
sealed class Shared<T> {
  const Shared();
}

/// Every file holds the same [value] — `null` where none of them has it.
final class Same<T> extends Shared<T> {
  /// Creates it.
  const Same(this.value);

  /// What they all hold, or `null` for none of them holding it.
  final T? value;
}

/// The files hold different values.
final class Mixed<T> extends Shared<T> {
  /// Creates it.
  const Mixed();
}

/// What several files hold in common, field by field.
class SharedTags {
  const SharedTags._({
    required this.values,
    required this.cover,
    required this.writable,
  });

  /// What [files] share. [files] must not be empty.
  ///
  /// Values are compared as [FileTags.values] holds them, so a file holding
  /// `Rock; Pop` differs from one holding `Rock`, and a file without a tag
  /// holds `null` — which another file without it holds too.
  factory SharedTags.of(List<FileTags> files) {
    assert(files.isNotEmpty, 'There is nothing to share between no files.');

    return SharedTags._(
      values: {
        for (final field in sharedTextFields)
          field: _sharedValue([for (final file in files) file.values[field]]),
      },
      cover: _sharedCover([for (final file in files) file.cover]),
      writable: {for (final file in files) ...file.writable},
    );
  }

  /// Each of [sharedTextFields].
  final Map<AutofillField, Shared<Object>> values;

  /// The front cover.
  final Shared<Uint8List> cover;

  /// The fields at least one of the files can hold.
  final Set<AutofillField> writable;

  /// Whether some file has a front cover.
  bool get anyCover => switch (cover) {
    Same(:final value) => value != null,
    Mixed() => true,
  };
}

/// [field] as the form starts out showing it: what the files share as text, or
/// empty where they have none of it or disagree.
String sharedText(SharedTags shared, AutofillField field) =>
    switch (shared.values[field]) {
      Same(:final value) => value?.toString() ?? '',
      Mixed() || null => '',
    };

/// Whether the files disagree on [field].
bool isMixed(SharedTags shared, AutofillField field) =>
    shared.values[field] is Mixed<Object>;

/// The number fields of [form] the owner changed into something that cannot be
/// written.
///
/// Only changed ones: a mixed field starts blank, and blank is no change. The
/// total a file is left without a number for is not a problem here but a note,
/// see [FileEdits.leftForMissingNumber].
Map<AutofillField, NumberProblem> sharedNumberProblems(
  SharedTags shared,
  TagForm form,
) => {
  for (final field in sharedTextFields)
    if (numberFields.contains(field))
      if (_changedText(shared, form, field) case final text?)
        field: ?numberProblem(field, text),
};

/// Whether [form] changes anything: a text field typed over, or a cover other
/// than keeping the files' own.
bool hasSharedChanges(SharedTags shared, TagForm form) =>
    form.cover is! KeepCover ||
    sharedTextFields.any((field) => _changedText(shared, form, field) != null);

/// What [form] does to one file.
class FileEdits {
  /// Creates the edits.
  const FileEdits({
    this.values = const {},
    this.leftForMissingNumber = const {},
  });

  /// Each field to write and its value, `null` removing the tag. Empty when
  /// there is nothing to write to the file.
  final Map<AutofillField, Object?> values;

  /// The totals (`trackTotal`, `discTotal`) the file would have been left
  /// holding without their number, which ID3 cannot say, and so were not
  /// written.
  final Set<AutofillField> leftForMissingNumber;
}

/// Each number field and the total it is the number of.
const List<(AutofillField, AutofillField)> _numberedPairs = [
  (AutofillField.trackNumber, AutofillField.trackTotal),
  (AutofillField.discNumber, AutofillField.discTotal),
];

/// What [form] changes in [file], given what [shared] started the form from:
/// each changed field the file can hold and does not already hold, and the
/// cover where it differs.
///
/// A number with a [numberProblem] is never in it — callers check
/// [sharedNumberProblems] before saving. A pair the edits would leave with a
/// total and no number is left as the file has it, and the total named in
/// [FileEdits.leftForMissingNumber]; the file's other edits stay.
FileEdits editsFor(FileTags file, SharedTags shared, TagForm form) {
  final edits = <AutofillField, Object?>{};

  for (final field in sharedTextFields) {
    final text = _changedText(shared, form, field);
    if (text == null || !file.writable.contains(field)) continue;

    final Object? value;
    if (text.isEmpty) {
      value = null;
    } else if (!numberFields.contains(field)) {
      value = text;
    } else if (numberProblem(field, text) == null) {
      // `03` over a file's 3 is the same number, and no change.
      value = int.parse(text);
    } else {
      continue;
    }

    if (file.values[field] != value) edits[field] = value;
  }

  if (file.writable.contains(AutofillField.cover)) {
    switch (form.cover) {
      case KeepCover():
        break;
      case RemoveCover():
        if (file.cover != null) edits[AutofillField.cover] = null;
      case ReplaceCover(:final bytes):
        if (!_sameBytes(bytes, file.cover)) {
          edits[AutofillField.cover] = bytes;
        }
    }
  }

  final left = <AutofillField>{};
  for (final (number, total) in _numberedPairs) {
    if (!edits.containsKey(number) && !edits.containsKey(total)) continue;

    final holdsNumber = _holds(
      edits.containsKey(number) ? edits[number] : file.values[number],
    );
    final holdsTotal = _holds(
      edits.containsKey(total) ? edits[total] : file.values[total],
    );
    if (holdsTotal && !holdsNumber) {
      edits
        ..remove(number)
        ..remove(total);
      left.add(total);
    }
  }

  return FileEdits(values: edits, leftForMissingNumber: left);
}

/// What [values] share: [Same] where every one is equal, [Mixed] otherwise.
Shared<Object> _sharedValue(List<Object?> values) {
  final first = values.first;

  return values.every((value) => value == first)
      ? Same<Object>(first)
      : const Mixed<Object>();
}

/// The covers as one: [Same] where every file has the same picture, or none
/// has one, [Mixed] otherwise.
Shared<Uint8List> _sharedCover(List<Uint8List?> covers) {
  final first = covers.first;
  final same = covers.every(
    (cover) => first == null ? cover == null : _sameBytes(first, cover),
  );

  return same ? Same<Uint8List>(first) : const Mixed<Uint8List>();
}

/// [field]'s text in [form], trimmed, where the owner changed it from what
/// [shared] started it as; `null` otherwise.
String? _changedText(SharedTags shared, TagForm form, AutofillField field) {
  final typed = form.text[field];
  if (typed == null) return null;

  final trimmed = typed.trim();
  return trimmed == sharedText(shared, field).trim() ? null : trimmed;
}

/// Whether a file holds [value] for a field at all.
bool _holds(Object? value) => value != null && value != '';

bool _sameBytes(Uint8List left, Uint8List? right) {
  if (right == null || left.length != right.length) return false;
  for (var i = 0; i < left.length; i++) {
    if (left[i] != right[i]) return false;
  }

  return true;
}
