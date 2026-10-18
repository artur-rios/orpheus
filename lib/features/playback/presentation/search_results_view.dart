import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../library/domain/music_catalog.dart';
import '../../library/domain/music_entry.dart';
import '../../shell/application/shell_controller.dart';
import '../../shell/presentation/async_state_view.dart';
import 'music_rows.dart';

/// What matches what the owner typed.
///
/// The search is over the library already in memory, which is why it has no
/// controller of its own and no loading state past the library's: matching a
/// term against a few tens of thousands of strings is work a frame can afford,
/// and a debounce and a spinner would be machinery around a computation that
/// is already finished.
///
/// It matches on the tags and never on the name on disk — the same rule the
/// rest of the music area follows. A file whose tags say nothing is
/// unreachable by search, which is honest: there is nothing to have searched
/// for.
class SearchResultsView extends ConsumerWidget {
  /// Creates the area.
  const SearchResultsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final term = ref.watch(searchTermProvider);
    final field = ref.watch(searchFieldProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Text(
            l10n.searchResults(term.trim()),
            style: theme.textTheme.titleMedium,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // Above the list rather than inside it, so it is still there when the
        // narrowed search finds nothing: the way out of an empty result is to
        // widen the field, and that has to be in reach.
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: _FieldSelector(selected: field),
        ),
        Expanded(
          child: AsyncStateView<MusicCatalog>(
            value: ref.watch(musicLibraryControllerProvider),
            onRetry: () => ref.invalidate(musicLibraryControllerProvider),
            builder: (context, catalog) => MusicTrackList(
              entries: matchesIn(catalog.entries, term, field: field),
              numbered: false,
              // Another term or another field is another list: a selection
              // made among one search's results ends with it.
              selectionScope: ('search', term.trim(), field),
              emptyMessage: l10n.searchEmpty(term.trim()),
            ),
          ),
        ),
      ],
    );
  }
}

/// Which kind of tag the search is matched against.
///
/// Scrolls sideways rather than dividing the row: five labels do not fit a
/// phone in Portuguese, and a label that wraps or is cut off is worse than one
/// a swipe away.
class _FieldSelector extends ConsumerWidget {
  const _FieldSelector({required this.selected});

  final SearchField selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SegmentedButton<SearchField>(
        segments: [
          for (final field in SearchField.values)
            ButtonSegment(value: field, label: Text(field.label(l10n))),
        ],
        selected: {selected},
        showSelectedIcon: false,
        onSelectionChanged: (chosen) =>
            ref.read(searchFieldProvider.notifier).choose(chosen.single),
      ),
    );
  }
}

/// How each choice names itself.
extension _SearchFieldPresentation on SearchField {
  String label(AppLocalizations l10n) => switch (this) {
    SearchField.all => l10n.searchFieldAll,
    SearchField.songs => l10n.searchFieldSongs,
    SearchField.artists => l10n.searchFieldArtists,
    SearchField.albums => l10n.searchFieldAlbums,
    SearchField.genres => l10n.searchFieldGenres,
  };
}

/// The entries in [library] that [term] matches, best first.
///
/// Ranked rather than merely filtered, and the ranking is the whole reason
/// this is a function worth testing: a term is usually the start of a title or
/// an artist, so a match at the beginning of a field is what the owner meant
/// and belongs above a match buried in the middle of some other track's name.
///
/// Case-insensitive, and across title, artist, album artist, album and genre —
/// the things a track is called and filed under. [field] narrows that to one
/// kind of tag: *artists* is the artist and the album artist, which is how an
/// owner says "by". Every field is trimmed through the same rule the rest of
/// the area uses, so a tag of spaces matches nothing rather than everything.
List<MusicEntry> matchesIn(
  List<MusicEntry> library,
  String term, {
  SearchField field = SearchField.all,
}) {
  final needle = term.trim().toLowerCase();
  if (needle.isEmpty) return const [];

  final scored = <(int, MusicEntry)>[];
  for (final entry in library) {
    final rank = _rankOf(entry, needle, field);
    if (rank != null) scored.add((rank, entry));
  }

  scored.sort((a, b) {
    final byRank = a.$1.compareTo(b.$1);
    if (byRank != 0) return byRank;

    // A stable second key, so two equally good matches do not swap places
    // between one keystroke and the next.
    return (a.$2.title ?? '').toLowerCase().compareTo(
      (b.$2.title ?? '').toLowerCase(),
    );
  });

  return [for (final (_, entry) in scored) entry];
}

/// How good a match [entry] is for [needle], or `null` for none.
///
/// Lower is better. The fields are ranked in the order an owner searches them:
/// what the track is called, then who by, then what record it is on, then what
/// it is filed under. Only the fields [choice] covers are looked at.
int? _rankOf(MusicEntry entry, String needle, SearchField choice) {
  bool covers(SearchField kind) => choice == SearchField.all || choice == kind;

  var best = 8;
  var matched = false;

  for (final (offset, value) in [
    if (covers(SearchField.songs)) (0, entry.title),
    if (covers(SearchField.artists)) ...[
      (2, entry.artist),
      (2, entry.albumArtist),
    ],
    if (covers(SearchField.albums)) (4, entry.album),
    if (covers(SearchField.genres))
      for (final genre in entry.genres) (6, genre),
  ]) {
    final field = value?.toLowerCase();
    if (field == null) continue;

    final at = field.indexOf(needle);
    if (at < 0) continue;

    matched = true;
    final rank = offset + (at == 0 ? 0 : 1);
    if (rank < best) best = rank;
  }

  return matched ? best : null;
}
