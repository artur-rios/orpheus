import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/di/providers.dart';
import '../../../core/failures/failure.dart';
import '../../../core/failures/failure_messages.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../shell/presentation/confirmation_dialog.dart';
import '../data/default_music_folders.dart';

/// The folders the library is built from, and what the last scan found.
///
/// The only screen in this application that talks about the filesystem, and it
/// says what it does in a sentence: the folders are read, and nothing in them
/// is ever moved, changed or deleted. That promise is the reason an owner
/// points a program at their music collection at all.
class LibraryFoldersView extends ConsumerWidget {
  /// Creates the area.
  const LibraryFoldersView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final folders = ref.watch(libraryFoldersControllerProvider);
    final scan = ref.watch(scanControllerProvider);
    final library = ref.watch(musicLibraryControllerProvider).value;

    return ListView(
      children: [
        Text(l10n.foldersDescription, style: theme.textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.md),

        if (folders.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Text(
              l10n.foldersEmpty,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          for (final folder in folders)
            _FolderRow(folder: folder, key: ValueKey(folder)),

        const SizedBox(height: AppSpacing.md),
        const _Actions(),

        const SizedBox(height: AppSpacing.lg),
        const Divider(),
        const SizedBox(height: AppSpacing.md),

        if (scan.failure case final failure?) _ScanFailure(failure: failure),

        Text(
          library == null || library.scannedAt == null
              ? l10n.scanNever
              : l10n.scanLastAt(
                  DateFormat.yMMMd(
                    Localizations.localeOf(context).toString(),
                  ).add_jm().format(library.scannedAt!.toLocal()),
                ),
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          l10n.scanTracksFound(library?.entries.length ?? 0),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),

        if (scan.report case final report?) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.scanReport(report.tracks, report.added, report.removed),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          for (final folder in report.unreachableFolders)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                l10n.scanUnreachable(folder),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          if (report.unreadable.isNotEmpty)
            _Unreadable(paths: report.unreadable),
        ],
      ],
    );
  }
}

/// One registered folder, and the way to take it out again.
class _FolderRow extends ConsumerWidget {
  const _FolderRow({required this.folder, super.key});

  final String folder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.folder_outlined),
      title: Text(folder, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: IconButton(
        tooltip: l10n.foldersRemove,
        icon: const Icon(Icons.close),
        onPressed: () async {
          // Asked before it happens, because it changes what the library holds
          // — even though nothing on disk is touched, which is what the
          // question says.
          final confirmed = await ConfirmationDialog.ask(
            context,
            title: l10n.foldersRemoveTitle,
            body: l10n.foldersRemoveBody,
            confirmLabel: l10n.remove,
          );
          if (!confirmed) return;

          await ref
              .read(libraryFoldersControllerProvider.notifier)
              .remove(folder);
          await ref.read(scanControllerProvider.notifier).scan();
        },
      ),
    );
  }
}

/// Add a folder, add the conventional one, and scan.
class _Actions extends ConsumerWidget {
  const _Actions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final folders = ref.watch(libraryFoldersControllerProvider);
    final scanning = ref.watch(scanControllerProvider).isRunning;

    // Offered only while it would do something: once the conventional folder
    // is registered, a button to register it again is a button that reports
    // nothing happened.
    final defaults = [
      for (final folder in defaultMusicFolders(
        platform: ref.watch(hostPlatformProvider),
      ))
        if (!folders.contains(folder)) folder,
    ];

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        FilledButton.icon(
          onPressed: () async {
            final added = await ref
                .read(libraryFoldersControllerProvider.notifier)
                .addByPicking();
            if (added) await ref.read(scanControllerProvider.notifier).scan();
          },
          icon: const Icon(Icons.create_new_folder_outlined),
          label: Text(l10n.foldersAdd),
        ),
        if (defaults.isNotEmpty)
          OutlinedButton.icon(
            onPressed: () async {
              final added = await ref
                  .read(libraryFoldersControllerProvider.notifier)
                  .addAll(defaults);
              if (added) await ref.read(scanControllerProvider.notifier).scan();
            },
            icon: const Icon(Icons.library_music_outlined),
            label: Text(l10n.foldersAddDefault),
          ),
        OutlinedButton.icon(
          // Disabled while one runs rather than queued behind it: a second
          // scan would walk the same folders the first is already walking.
          onPressed: scanning || folders.isEmpty
              ? null
              : () => unawaited(ref.read(scanControllerProvider.notifier).scan()),
          icon: const Icon(Icons.refresh),
          label: Text(l10n.scanNow),
        ),
      ],
    );
  }
}

/// Why the last scan could not run, and what can be done about it.
class _ScanFailure extends ConsumerWidget {
  const _ScanFailure({required this.failure});

  final Failure failure;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Card(
      color: theme.colorScheme.errorContainer,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              failure.localizedMessage(l10n),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
            // The settings screen is the only way out of a permission the
            // system will no longer ask about, so it is offered exactly there
            // and nowhere else.
            if (failure case StoragePermissionDenied(permanently: true)) ...[
              const SizedBox(height: AppSpacing.sm),
              FilledButton(
                onPressed: () => unawaited(
                  ref
                      .read(libraryAccessControllerProvider.notifier)
                      .openSettings(),
                ),
                child: Text(l10n.openSettings),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The files whose tags could not be read.
///
/// Named, behind a disclosure: they are still in the library and still play,
/// so this is a list to look at when something is listed as untitled — not a
/// problem the owner has to deal with before they can listen to anything.
class _Unreadable extends StatelessWidget {
  const _Unreadable({required this.paths});

  final List<String> paths;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(
        l10n.scanUnreadable(paths.length),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      children: [
        for (final path in paths)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SelectableText(path, style: theme.textTheme.bodySmall),
            ),
          ),
      ],
    );
  }
}
