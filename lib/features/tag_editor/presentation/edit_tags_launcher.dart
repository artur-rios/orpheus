import 'package:flutter/material.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../library/domain/music_entry.dart';
import 'edit_many_tags_dialog.dart';
import 'edit_tags_dialog.dart';

/// Opens the tag editor for [entry], and says so once its edit is written.
///
/// Answers `true` when the file was written, `false` when the editor was
/// closed without writing it.
Future<bool> startTagEdit(BuildContext context, MusicEntry entry) async {
  // Both taken now: the menu that opened the editor may be gone by the time
  // it closes.
  final messenger = ScaffoldMessenger.maybeOf(context);
  final saved = AppLocalizations.of(context).tagEditSaved;

  final written = await showDialog<bool>(
    context: context,
    builder: (_) => EditTagsDialog(entry: entry),
  );

  if (written ?? false) {
    messenger?.showSnackBar(SnackBar(content: Text(saved)));

    return true;
  }

  return false;
}

/// Opens the form over [entries] — an album's or an artist's tracks, named
/// [label] — and says how many were written once it closes.
///
/// One track is the one-track form, title and track number included.
///
/// Answers `true` when at least one file was written, so that a caller can
/// tell an edit that changed something from one that was cancelled.
Future<bool> startManyTagEdit(
  BuildContext context,
  List<MusicEntry> entries, {
  required String label,
}) async {
  if (entries.isEmpty) return false;
  if (entries.length == 1) return startTagEdit(context, entries.single);

  // Both taken now, as for one track.
  final messenger = ScaffoldMessenger.maybeOf(context);
  final saved = AppLocalizations.of(context).tagEditManySaved;

  final written = await showDialog<int>(
    context: context,
    // A tap beside the form while it writes must not close it.
    barrierDismissible: false,
    builder: (_) => EditManyTagsDialog(entries: entries, label: label),
  );

  if (written != null && written > 0) {
    messenger?.showSnackBar(SnackBar(content: Text(saved(written))));

    return true;
  }

  return false;
}
