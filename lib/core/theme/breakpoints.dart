import 'package:flutter/widgets.dart';

/// The width thresholds at which the shell changes layout.
///
/// Four tiers rather than the three a desktop-only application needs, because
/// this one has a phone target: a 411-pixel screen is not a narrow desktop
/// window with the labels taken off, it is a different arrangement — the
/// destinations move to the bottom of the screen, where a thumb reaches them.
///
/// The tiers are widths and nothing else. A narrow desktop window gets the
/// phone arrangement, which is the point: there is one set of rules, and the
/// same window laid out the same way whatever is running it.
enum Breakpoint {
  /// Below 600: a phone, or a desktop window narrowed to a phone's width. The
  /// destinations are a bar across the bottom.
  phone,

  /// 600 up to 1023: a tablet, or a small desktop window. The destinations are
  /// a rail of icons with tooltips.
  compact,

  /// 1024 up to 1439: the rail carries its labels beneath the icons.
  medium,

  /// 1440 and wider: the rail is extended, carrying its labels beside the
  /// icons rather than beneath them.
  expanded;

  /// The narrowest desktop window the application supports, in logical pixels.
  ///
  /// Narrow on purpose: the phone tier is a real layout rather than a
  /// degradation, so a desktop window pulled down to it stays a usable player
  /// instead of a clipped one.
  static const Size minimumWindowSize = Size(420, 560);

  /// The size a first desktop launch opens at, in logical pixels.
  static const Size defaultWindowSize = Size(1280, 820);

  /// The width at or above which [Breakpoint.compact] applies.
  static const double compactMinWidth = 600;

  /// The width at or above which [Breakpoint.medium] applies.
  static const double mediumMinWidth = 1024;

  /// The width at or above which [Breakpoint.expanded] applies.
  static const double expandedMinWidth = 1440;

  /// The tier a window of [width] logical pixels falls into.
  static Breakpoint of(double width) {
    if (width >= expandedMinWidth) return Breakpoint.expanded;
    if (width >= mediumMinWidth) return Breakpoint.medium;
    if (width >= compactMinWidth) return Breakpoint.compact;
    return Breakpoint.phone;
  }

  /// The tier the nearest enclosing [MediaQuery] falls into.
  static Breakpoint from(BuildContext context) =>
      of(MediaQuery.sizeOf(context).width);

  /// Whether the destinations are a bar across the bottom rather than a rail
  /// down the side.
  bool get usesBottomNavigation => this == Breakpoint.phone;

  /// Whether the navigation rail shows labels alongside its icons.
  bool get showsNavigationLabels =>
      this == Breakpoint.medium || this == Breakpoint.expanded;

  /// Whether the navigation rail is extended — labels *beside* the icons
  /// rather than beneath them.
  bool get usesExtendedNavigation => this == Breakpoint.expanded;
}
