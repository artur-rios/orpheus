import 'package:flutter/material.dart';

/// The colours one story card is drawn in.
class StoryColours {
  /// Creates a set.
  const StoryColours({
    required this.top,
    required this.bottom,
    required this.foreground,
    required this.muted,
  });

  /// The top of the card's gradient.
  final Color top;

  /// The bottom of it.
  final Color bottom;

  /// What text on it is drawn in.
  final Color foreground;

  /// What the quieter text on it is drawn in.
  final Color muted;

  /// The gradient itself.
  LinearGradient get gradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [top, bottom],
  );
}

/// The colours the story cards are drawn in.
///
/// Derived from the same seed as everything else rather than picked per card.
/// A story is the one screen in this application that wants a different colour
/// every few seconds, and the temptation is a list of hand-chosen brights —
/// which is a second palette, drifting from the first the moment either
/// changes.
///
/// So the hue is rotated instead. Each card turns the seed's hue by a fixed
/// step, which gives cards that are plainly different from their neighbours
/// and plainly from the same application; and the saturation and lightness are
/// pinned, so no card comes out muddy or unreadable however the seed moves.
abstract final class StoryPalette {
  /// How far the hue turns from one card to the next, in degrees.
  ///
  /// Coprime with 360 so a story longer than a handful of cards keeps moving
  /// rather than cycling back onto a colour it has just shown.
  static const double _step = 47;

  /// The colours for the card at [index], seeded from [scheme].
  static StoryColours forCard(int index, ColorScheme scheme) {
    final seed = HSLColor.fromColor(scheme.primary);
    final hue = (seed.hue + index * _step) % 360;

    // Deep enough that white text sits on it comfortably at any hue, and two
    // stops apart so the card has a direction rather than being a flat field.
    final top = HSLColor.fromAHSL(1, hue, 0.62, 0.32).toColor();
    final bottom = HSLColor.fromAHSL(1, (hue + 24) % 360, 0.58, 0.18).toColor();

    return StoryColours(
      top: top,
      bottom: bottom,
      // Not white, but the palette's own near-white: a story card is still
      // this application, and pure white against a coloured field is the one
      // thing that reads as somebody else's screenshot.
      foreground: HSLColor.fromAHSL(1, hue, 0.16, 0.97).toColor(),
      muted: HSLColor.fromAHSL(1, hue, 0.20, 0.80).toColor(),
    );
  }
}
