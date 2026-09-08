import 'package:flutter/material.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/story_palette.dart';
import '../domain/music_stats.dart';
import '../domain/stats_story.dart';

/// One card of the story, drawn.
///
/// Stateless and given everything it draws, which is what lets the same widget
/// be the thing on screen and the thing rendered to a picture: what the owner
/// shares is the card they were looking at, not a second layout built to
/// resemble it.
class StoryCardView extends StatelessWidget {
  /// Creates the card.
  const StoryCardView({
    required this.card,
    required this.colours,
    this.showsFooter = false,
    super.key,
  });

  /// What it says.
  final StoryCard card;

  /// What it is drawn in.
  final StoryColours colours;

  /// Whether the "made with Orpheus" line is drawn at the foot of the card.
  ///
  /// It is what says where a card came from once it has left the application,
  /// and it is drawn on screen too rather than added for the capture: the
  /// picture the owner sends should be the card they were looking at, down to
  /// its last line.
  final bool showsFooter;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(gradient: colours.gradient),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: switch (card) {
                  StoryOpening(:final totalPlays, :final distinctTracks) =>
                    _opening(context, l10n, totalPlays, distinctTracks),
                  StoryHeadline(:final topic, :final name, :final share) =>
                    _headline(context, l10n, topic, name, share),
                  StoryRanking(:final topic, :final entries) =>
                    _ranking(context, l10n, topic, entries),
                  StorySummary() => _summary(context, l10n, card as StorySummary),
                },
              ),
            ),
            if (showsFooter)
              Text(
                l10n.storyMadeWith,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colours.muted,
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _opening(
    BuildContext context,
    AppLocalizations l10n,
    int plays,
    int tracks,
  ) => [
    _Heading(l10n.storyOpeningTitle, colours: colours),
    const SizedBox(height: AppSpacing.lg),
    _Big(l10n.storyOpeningPlays(plays), colours: colours),
    const SizedBox(height: AppSpacing.sm),
    _Quiet(l10n.storyOpeningTracks(tracks), colours: colours),
  ];

  List<Widget> _headline(
    BuildContext context,
    AppLocalizations l10n,
    StoryTopic topic,
    String name,
    double share,
  ) => [
    _Heading(
      switch (topic) {
        StoryTopic.artists => l10n.storyTopArtist,
        StoryTopic.albums => l10n.storyTopAlbum,
        StoryTopic.tracks => l10n.storyTopTrack,
        StoryTopic.genres => l10n.storyTopGenre,
      },
      colours: colours,
    ),
    const SizedBox(height: AppSpacing.lg),
    _Big(name, colours: colours),
    const SizedBox(height: AppSpacing.sm),
    // Rounded for reading rather than for accuracy: a story card is a
    // headline, and "37.4%" is a spreadsheet.
    _Quiet(
      l10n.storyShareOfPlays('${(share * 100).round()}'),
      colours: colours,
    ),
  ];

  List<Widget> _ranking(
    BuildContext context,
    AppLocalizations l10n,
    StoryTopic topic,
    List<RankedPlays> entries,
  ) => [
    _Heading(
      switch (topic) {
        StoryTopic.artists => l10n.storyRankingArtists,
        StoryTopic.albums => l10n.storyRankingAlbums,
        StoryTopic.tracks => l10n.storyRankingTracks,
        StoryTopic.genres => l10n.storyRankingGenres,
      },
      colours: colours,
    ),
    const SizedBox(height: AppSpacing.lg),
    for (final (index, entry) in entries.indexed) ...[
      _Line(position: index + 1, name: entry.name, colours: colours),
      if (index < entries.length - 1) const SizedBox(height: AppSpacing.md),
    ],
  ];

  List<Widget> _summary(
    BuildContext context,
    AppLocalizations l10n,
    StorySummary summary,
  ) => [
    _Heading(l10n.storySummaryTitle, colours: colours),
    const SizedBox(height: AppSpacing.lg),
    _Big(l10n.storyOpeningPlays(summary.totalPlays), colours: colours),
    const SizedBox(height: AppSpacing.lg),
    for (final (label, value) in [
      (l10n.storyTopArtist, summary.topArtist),
      (l10n.storyTopAlbum, summary.topAlbum),
      (l10n.storyTopTrack, summary.topTrack),
    ])
      if (value != null) ...[
        _Quiet(label, colours: colours),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: colours.foreground,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
      ],
  ];
}

class _Heading extends StatelessWidget {
  const _Heading(this.text, {required this.colours});

  final String text;
  final StoryColours colours;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.titleMedium?.copyWith(
      color: colours.muted,
      letterSpacing: 1.2,
    ),
  );
}

class _Big extends StatelessWidget {
  const _Big(this.text, {required this.colours});

  final String text;
  final StoryColours colours;

  @override
  Widget build(BuildContext context) => Text(
    text,
    maxLines: 4,
    overflow: TextOverflow.ellipsis,
    style: Theme.of(context).textTheme.displaySmall?.copyWith(
      color: colours.foreground,
      fontWeight: FontWeight.w700,
      height: 1.1,
    ),
  );
}

class _Quiet extends StatelessWidget {
  const _Quiet(this.text, {required this.colours});

  final String text;
  final StoryColours colours;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: colours.muted),
  );
}

/// One line of a ranking card: its position, and what it is.
class _Line extends StatelessWidget {
  const _Line({
    required this.position,
    required this.name,
    required this.colours,
  });

  final int position;
  final String name;
  final StoryColours colours;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        SizedBox(
          width: AppSpacing.xl,
          child: Text(
            '$position',
            style: theme.textTheme.titleLarge?.copyWith(color: colours.muted),
          ),
        ),
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge?.copyWith(
              color: colours.foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
