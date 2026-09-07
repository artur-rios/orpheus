import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/breakpoints.dart';
import '../../library/presentation/library_folders_view.dart';
import '../../library/presentation/scan_strip.dart';
import '../../playback/presentation/music_library_view.dart';
import '../../playback/presentation/now_playing_screen.dart';
import '../../playback/presentation/queue_view.dart';
import '../../playback/presentation/search_results_view.dart';
import '../../stats/presentation/music_stats_screen.dart';
import '../application/shell_controller.dart';
import '../domain/shell_destination.dart';
import 'playback_bar.dart';
import 'preferences_dialog.dart';
import 'shell_navigation.dart';

/// The application shell.
///
/// Four regions and no more: the bar across the top, the destinations, the
/// content area, and the playback bar across the bottom. Everything the owner
/// does happens inside the content area, which is why this widget stays this
/// small — it is a frame, and a frame that grew feature logic would be the
/// thing every later change has to edit.
///
/// Where the destinations go is the one thing that changes with the window: a
/// rail down the side where there is width for one, a bar across the bottom on
/// a phone.
class ShellScreen extends ConsumerWidget {
  /// Creates the shell.
  const ShellScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final destination = ref.watch(shellControllerProvider);
    final breakpoint = Breakpoint.from(context);

    // The player opens itself when a track starts, from wherever it was
    // started — the shell is where every path into playback converges, so a
    // listener here is the one place that covers all of them without any call
    // site having to remember to open it.
    //
    // `ref.listen` rather than reading the queue in `build` and pushing from
    // inside it: a route push is a side effect, and Riverpod only calls the
    // callback once the state change has been committed — after this build,
    // not during it — which is what lets `Navigator.push` run here safely.
    ref.listen(audioPlaybackControllerProvider, (previous, next) {
      final started = next.current?.path;
      if (started == null || started == previous?.current?.path) return;
      // The owner's own switch: off means a track starts where they left the
      // player, rather than in front of it.
      if (!ref.read(preferencesControllerProvider).opensPlayerOnPlay) return;

      unawaited(NowPlayingScreen.show(context));
    });

    final bottom = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Whatever the scan is doing, above the playback bar and below
        // everything else. It takes no height when there is nothing to say.
        //
        // Not its failures while the folders screen is open: that screen says
        // the same thing at length and offers the settings button a permanent
        // refusal needs, and the same sentence twice on one screen reads as
        // two problems.
        ScanStrip(showsFailure: destination != ShellDestination.folders),
        const Divider(height: 1, thickness: 1),
        const PlaybackBar(),
        if (breakpoint.usesBottomNavigation)
          ShellNavigationBar(
            selected: destination,
            onSelected: ref.read(shellControllerProvider.notifier).go,
          ),
      ],
    );

    return Scaffold(
      appBar: _ShellAppBar(destination: destination),
      body: breakpoint.usesBottomNavigation
          ? _Content(destination: destination)
          : Row(
              children: [
                ShellNavigationRail(
                  selected: destination,
                  onSelected: ref.read(shellControllerProvider.notifier).go,
                ),
                const VerticalDivider(width: 1, thickness: 1),
                Expanded(child: _Content(destination: destination)),
              ],
            ),
      bottomNavigationBar: bottom,
    );
  }
}

/// The bar across the top: where the owner is, what they are searching for,
/// and the preferences.
class _ShellAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const _ShellAppBar({required this.destination});

  final ShellDestination destination;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final phone = Breakpoint.from(context).usesBottomNavigation;

    return AppBar(
      title: Text(destination.label(l10n)),
      titleSpacing: AppSpacing.md,
      actions: [
        // The field itself where there is room for it, and a field that takes
        // the bar over when there is not: a search box squeezed into a phone's
        // app bar beside a title is a box too small to read what was typed
        // into it.
        if (!phone)
          const SizedBox(width: 320, child: _SearchField())
        else
          const _PhoneSearchButton(),
        IconButton(
          tooltip: l10n.statsOpen,
          icon: const Icon(Icons.insights_outlined),
          onPressed: () => unawaited(MusicStatsScreen.show(context)),
        ),
        IconButton(
          tooltip: l10n.settingsTitle,
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => unawaited(PreferencesDialog.show(context)),
        ),
        const SizedBox(width: AppSpacing.sm),
      ],
    );
  }
}

/// The search field.
class _SearchField extends ConsumerStatefulWidget {
  const _SearchField({this.autofocus = false});

  final bool autofocus;

  @override
  ConsumerState<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends ConsumerState<_SearchField> {
  late final TextEditingController _text = TextEditingController(
    text: ref.read(searchTermProvider),
  );

  @override
  void initState() {
    super.initState();
    // Only to bring the clear button in and out; the results themselves come
    // from the provider. Watching the controller rather than the keystrokes
    // means it follows a term cleared from anywhere too.
    _text.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _text
      ..removeListener(_onTextChanged)
      ..dispose();
    super.dispose();
  }

  void _onTextChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // The field follows the term, not only the other way about. The back
    // gesture clears a search from outside this widget, and a box still
    // showing what it was cleared of is a box that disagrees with the listing
    // under it about whether anything is being searched for.
    ref.listen(searchTermProvider, (_, term) {
      if (_text.text == term) return;

      _text.value = TextEditingValue(
        text: term,
        selection: TextSelection.collapsed(offset: term.length),
      );
    });

    return TextField(
      controller: _text,
      autofocus: widget.autofocus,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: l10n.searchHint,
        isDense: true,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _text.text.isEmpty
            ? null
            : IconButton(
                tooltip: l10n.searchClear,
                icon: const Icon(Icons.close),
                onPressed: () {
                  _text.clear();
                  ref.read(searchTermProvider.notifier).clear();
                },
              ),
      ),
      onChanged: ref.read(searchTermProvider.notifier).type,
    );
  }
}

/// Search on a phone: a button that opens a sheet with the field in it.
class _PhoneSearchButton extends ConsumerWidget {
  const _PhoneSearchButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final searching = isSearchable(ref.watch(searchTermProvider));

    return IconButton(
      tooltip: l10n.searchHint,
      // Filled once a term is active, so an owner who left the sheet with
      // something typed can see why their library is showing results.
      icon: Icon(searching ? Icons.search_off : Icons.search),
      onPressed: () {
        if (searching) {
          ref.read(searchTermProvider.notifier).clear();

          return;
        }

        unawaited(
          showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            builder: (context) => Padding(
              padding: EdgeInsets.only(
                left: AppSpacing.md,
                right: AppSpacing.md,
                top: AppSpacing.md,
                // Above the keyboard, which is most of a phone's screen while
                // this is open.
                bottom:
                    MediaQuery.viewInsetsOf(context).bottom + AppSpacing.md,
              ),
              child: const _SearchField(autofocus: true),
            ),
          ),
        );
      },
    );
  }
}

/// The content area.
class _Content extends ConsumerWidget {
  const _Content({required this.destination});

  final ShellDestination destination;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The search is across the whole library, so it belongs to the shell
    // rather than to any one area — and while a term is present, the results
    // are what the content area shows.
    final searching = isSearchable(ref.watch(searchTermProvider));

    return Padding(
      padding: EdgeInsets.all(musicAreaPadding(context)),
      child: switch (destination) {
        // An empty term is not a search, and the library is already what an
        // absent search shows. The folders area is exempt: it lists folders,
        // not tracks, and a term left over from the music area must not
        // replace it with matching files.
        _ when searching && destination != ShellDestination.folders =>
          const SearchResultsView(),
        ShellDestination.music => const MusicLibraryView(),
        ShellDestination.queue => const QueueView(),
        ShellDestination.folders => const LibraryFoldersView(),
      },
    );
  }
}
