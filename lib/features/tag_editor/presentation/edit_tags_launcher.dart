import 'package:flutter/material.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../library/domain/music_entry.dart';
import 'edit_tags_dialog.dart';

/// Opens the tag editor for [entry], and says so once its edit is written.
Future<void> startTagEdit(BuildContext context, MusicEntry entry) async {
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
  }
}
