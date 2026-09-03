import 'package:flutter/material.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/breakpoints.dart';
import '../domain/shell_destination.dart';

/// The navigation panel, down the side.
///
/// It collapses rather than hides: at the narrow tiers it is a rail of icons
/// with tooltips, and at the wider ones the same entries carry their labels.
/// No entry is ever dropped, which is the distinction between adapting a
/// layout and clipping it.
class ShellNavigationRail extends StatelessWidget {
  /// Creates the rail.
  const ShellNavigationRail({
    required this.selected,
    required this.onSelected,
    super.key,
  });

  /// The destination currently shown.
  final ShellDestination selected;

  /// Called when the owner picks a destination.
  final ValueChanged<ShellDestination> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final breakpoint = Breakpoint.from(context);

    // A window can be wide and short. Scrolling is how the rail keeps every
    // entry reachable there; the constrained intrinsic height is what lets it
    // still fill a tall window, which a bare scroll view would collapse.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: IntrinsicHeight(
            child: NavigationRail(
              selectedIndex: ShellDestination.values.indexOf(selected),
              onDestinationSelected: (index) =>
                  onSelected(ShellDestination.values[index]),
              // An extended rail carries its labels itself, and Material
              // requires the label type be `none` when it does.
              extended: breakpoint.usesExtendedNavigation,
              labelType:
                  breakpoint.showsNavigationLabels &&
                      !breakpoint.usesExtendedNavigation
                  ? NavigationRailLabelType.all
                  : NavigationRailLabelType.none,
              groupAlignment: -1,
              destinations: [
                for (final destination in ShellDestination.values)
                  NavigationRailDestination(
                    icon: Icon(destination.icon),
                    selectedIcon: Icon(destination.selectedIcon),
                    label: Text(destination.label(l10n)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The navigation bar, across the bottom.
///
/// The phone arrangement, and not a fallback for one: a rail down the side of
/// a 411-pixel screen takes a fifth of its width, and the entries end up where
/// a thumb cannot reach them.
class ShellNavigationBar extends StatelessWidget {
  /// Creates the bar.
  const ShellNavigationBar({
    required this.selected,
    required this.onSelected,
    super.key,
  });

  /// The destination currently shown.
  final ShellDestination selected;

  /// Called when the owner picks a destination.
  final ValueChanged<ShellDestination> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return NavigationBar(
      selectedIndex: ShellDestination.values.indexOf(selected),
      onDestinationSelected: (index) =>
          onSelected(ShellDestination.values[index]),
      destinations: [
        for (final destination in ShellDestination.values)
          NavigationDestination(
            icon: Icon(destination.icon),
            selectedIcon: Icon(destination.selectedIcon),
            label: destination.label(l10n),
          ),
      ],
    );
  }
}

/// How each destination presents itself.
///
/// An extension in the presentation layer rather than fields on the enum: an
/// icon and a localized label are what this destination *looks like*, and the
/// domain has no business holding either.
extension ShellDestinationPresentation on ShellDestination {
  /// The icon in the navigation panel.
  IconData get icon => switch (this) {
    ShellDestination.music => Icons.library_music_outlined,
    ShellDestination.queue => Icons.queue_music_outlined,
    ShellDestination.folders => Icons.folder_outlined,
  };

  /// The icon shown for the selected destination.
  IconData get selectedIcon => switch (this) {
    ShellDestination.music => Icons.library_music,
    ShellDestination.queue => Icons.queue_music,
    ShellDestination.folders => Icons.folder,
  };

  /// The localized label, in the panel and as the content area's heading.
  String label(AppLocalizations l10n) => switch (this) {
    ShellDestination.music => l10n.destinationMusic,
    ShellDestination.queue => l10n.destinationQueue,
    ShellDestination.folders => l10n.destinationFolders,
  };
}
