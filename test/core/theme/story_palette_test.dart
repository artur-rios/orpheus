import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:orpheus/core/theme/app_theme.dart';
import 'package:orpheus/core/theme/story_palette.dart';

/// The colours the story cards are drawn in: a different hue per card, from
/// the application's own seed, and always readable.
void main() {
  final scheme = AppTheme.light.colorScheme;

  double hueOf(Color colour) => HSLColor.fromColor(colour).hue;

  /// How far apart two hues are, the short way round the wheel.
  double hueDistance(double a, double b) {
    final distance = (a - b).abs() % 360;
    return distance > 180 ? 360 - distance : distance;
  }

  /// The WCAG contrast ratio between two colours.
  double contrast(Color a, Color b) {
    final first = a.computeLuminance();
    final second = b.computeLuminance();
    final lighter = first > second ? first : second;
    final darker = first > second ? second : first;
    return (lighter + 0.05) / (darker + 0.05);
  }

  test(
    'GivenTheFirstCard_WhenItsColoursAreAsked_ThenItsHueIsTheSeeds',
    () {
      final colours = StoryPalette.forCard(0, scheme);

      expect(
        hueDistance(hueOf(colours.top), HSLColor.fromColor(scheme.primary).hue),
        lessThan(2),
      );
    },
  );

  test(
    'GivenTwoNeighbouringCards_WhenTheirColoursAreAsked_ThenTheirHuesAreApart',
    () {
      for (var index = 0; index < 20; index++) {
        final here = StoryPalette.forCard(index, scheme);
        final next = StoryPalette.forCard(index + 1, scheme);

        expect(
          hueDistance(hueOf(here.top), hueOf(next.top)),
          closeTo(47, 2),
        );
      }
    },
  );

  test(
    'GivenAnyCard_WhenItsTextIsDrawn_ThenItIsReadableOnBothEndsOfTheGradient',
    () {
      // Every hue the rotation can reach, not only the first few cards: the
      // lightness is pinned so that none of them comes out unreadable. The
      // light top end is the harder one; the dark bottom, where the quieter
      // text sits, has room to spare.
      for (var index = 0; index < 360; index++) {
        final colours = StoryPalette.forCard(index, scheme);

        expect(contrast(colours.foreground, colours.top), greaterThan(3));
        expect(contrast(colours.foreground, colours.bottom), greaterThan(7));
        expect(contrast(colours.muted, colours.bottom), greaterThan(4.5));
      }
    },
  );

  test(
    'GivenACard_WhenItsGradientIsAsked_ThenItRunsFromItsTopToItsBottom',
    () {
      final colours = StoryPalette.forCard(3, scheme);

      expect(colours.gradient.colors, [colours.top, colours.bottom]);
      expect(colours.gradient.begin, Alignment.topLeft);
      expect(colours.gradient.end, Alignment.bottomRight);
    },
  );
}
