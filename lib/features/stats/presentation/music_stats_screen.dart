import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../shell/presentation/async_state_view.dart';
import '../domain/music_stats.dart';
import '../domain/stats_story.dart';
import 'stats_story_screen.dart';

/// What the owner listens to: a summary, and four rankings under it.
///
/// A screen of its own rather than a fourth destination in the shell. The
/// navigation panel lists the three places music is *found*; what has already
/// been played is a thing to go and look at, not a place to be, and a fourth
/// entry would be a fourth answer to "where do you want to be before you have
/// heard anything".
class MusicStatsScreen extends ConsumerWidget {
  /// Creates the screen.
  const MusicStatsScreen({super.key});

  /// Opens the screen over whatever is showing.
  static Future<void> show(BuildContext context) => Navigator.of(context)
      .push<void>(
        MaterialPageRoute(builder: (context) => const MusicStatsScreen()),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final stats = ref.watch(musicStatsControllerProvider);
    final controller = ref.read(musicStatsControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.statsTitle),
        actions: [
          // Offered only where there is a story to tell. A button that opens
          // an empty sequence of cards is a button that lies about what is
          // behind it.
          if (stats.value?.isEmpty == false)
            IconButton(
              tooltip: l10n.statsStory,
              icon: const Icon(Icons.auto_stories_outlined),
              onPressed: () => StatsStoryScreen.show(
                context,
                storyFrom(stats.requireValue),
              ),
            ),
          IconButton(
            tooltip: l10n.statsReadAgain,
            icon: const Icon(Icons.refresh),
            onPressed: () => controller.readAgain(),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: AsyncStateView<MusicStats>(
        value: stats,
        onRetry: controller.readAgain,
        isEmpty: (data) => data.isEmpty,
        emptyBuilder: (context) => const _NothingCounted(),
        builder: (context, data) => _Statistics(stats: data),
      ),
    );
  }
}

/// The state before anything has been listened to.
///
/// It says what has to happen rather than only that nothing has: an owner who
/// has been playing music and sees a blank screen is owed the rule, not the
/// absence.
class _NothingCounted extends StatelessWidget {
  const _NothingCounted();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.insights_outlined,
                size: AppSpacing.xl,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                l10n.statsEmptyTitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.statsEmptyBody,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The summary and the rankings.
class _Statistics extends StatelessWidget {
  const _Statistics({required this.stats});

  final MusicStats stats;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        _Summary(stats: stats),
        const SizedBox(height: AppSpacing.lg),
        // Every ranking is drawn even when it is empty. A heading with nothing
        // under it says the ranking exists and has nothing in it; dropping it
        // says the application forgot about artists.
        _Ranking(title: l10n.statsTopTracks, lines: stats.tracks),
        _Ranking(title: l10n.statsTopArtists, lines: stats.artists),
        _Ranking(title: l10n.statsTopAlbums, lines: stats.albums),
        _Ranking(title: l10n.statsTopGenres, lines: stats.genres),
        if (stats.untaggedTracks > 0) ...[
          const SizedBox(height: AppSpacing.sm),
          _UntaggedNote(count: stats.untaggedTracks),
        ],
      ],
    );
  }
}

/// The two numbers at the top: how much listening, across how many tracks.
class _Summary extends StatelessWidget {
  const _Summary({required this.stats});

  final MusicStats stats;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Row(
      children: [
        Expanded(
          child: _Total(
            value: stats.totalPlays,
            label: l10n.statsTotalPlays,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _Total(
            value: stats.distinctTracks,
            label: l10n.statsDistinctTracks,
          ),
        ),
      ],
    );
  }
}

/// One large number with its word under it.
class _Total extends StatelessWidget {
  const _Total({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.lg,
          horizontal: AppSpacing.md,
        ),
        child: Column(
          children: [
            Text('$value', style: theme.textTheme.headlineMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One ranking: a heading, and the rows under it.
class _Ranking extends StatelessWidget {
  const _Ranking({required this.title, required this.lines});

  final String title;
  final List<RankedPlays> lines;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            top: AppSpacing.md,
            bottom: AppSpacing.sm,
          ),
          child: Text(title, style: theme.textTheme.titleMedium),
        ),
        if (lines.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              l10n.statsRankingEmpty,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          for (final (index, line) in lines.indexed)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Text(
                '${index + 1}',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              title: Text(line.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: Text(
                l10n.statsPlaysCount(line.plays),
                style: theme.textTheme.bodySmall,
              ),
            ),
        const Divider(height: 1),
      ],
    );
  }
}

/// Why the totals can be larger than the rankings.
class _UntaggedNote extends StatelessWidget {
  const _UntaggedNote({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Text(
        AppLocalizations.of(context).statsUntaggedNote(count),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
