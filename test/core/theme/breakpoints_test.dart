import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/core/theme/breakpoints.dart';

/// The width thresholds the shell changes its layout at.
///
/// Each threshold belongs to the tier above it: a window exactly 600 wide is
/// compact, not a phone. Getting one of those edges wrong by a pixel puts the
/// destinations in two places at once on some owner's window.
void main() {
  for (final (width, tier) in [
    (0.0, Breakpoint.phone),
    (Breakpoint.minimumWindowSize.width, Breakpoint.phone),
    (Breakpoint.compactMinWidth - 0.5, Breakpoint.phone),
    (Breakpoint.compactMinWidth, Breakpoint.compact),
    (Breakpoint.mediumMinWidth - 0.5, Breakpoint.compact),
    (Breakpoint.mediumMinWidth, Breakpoint.medium),
    (Breakpoint.defaultWindowSize.width, Breakpoint.medium),
    (Breakpoint.expandedMinWidth - 0.5, Breakpoint.medium),
    (Breakpoint.expandedMinWidth, Breakpoint.expanded),
    (3840.0, Breakpoint.expanded),
  ]) {
    test('GivenAWindow${width}Wide_WhenItsTierIsAsked_ThenItIs${tier.name}', () {
      expect(Breakpoint.of(width), tier);
    });
  }

  test(
    'GivenEachTier_WhenItsNavigationIsAsked_ThenOnlyThePhoneUsesTheBottomBar',
    () {
      expect(
        {for (final tier in Breakpoint.values) tier: tier.usesBottomNavigation},
        {
          Breakpoint.phone: true,
          Breakpoint.compact: false,
          Breakpoint.medium: false,
          Breakpoint.expanded: false,
        },
      );
    },
  );

  test(
    'GivenEachTier_WhenItsRailIsAsked_ThenMediumAndExpandedCarryLabels',
    () {
      expect(
        {
          for (final tier in Breakpoint.values)
            tier: tier.showsNavigationLabels,
        },
        {
          Breakpoint.phone: false,
          Breakpoint.compact: false,
          Breakpoint.medium: true,
          Breakpoint.expanded: true,
        },
      );
    },
  );

  test(
    'GivenEachTier_WhenItsRailIsAsked_ThenOnlyExpandedIsExtended',
    () {
      expect(
        {
          for (final tier in Breakpoint.values)
            tier: tier.usesExtendedNavigation,
        },
        {
          Breakpoint.phone: false,
          Breakpoint.compact: false,
          Breakpoint.medium: false,
          Breakpoint.expanded: true,
        },
      );
    },
  );

  test(
    'GivenTheWindowSizes_WhenCompared_ThenTheDefaultIsLargerThanTheMinimum',
    () {
      expect(
        Breakpoint.defaultWindowSize.width,
        greaterThan(Breakpoint.minimumWindowSize.width),
      );
      expect(
        Breakpoint.defaultWindowSize.height,
        greaterThan(Breakpoint.minimumWindowSize.height),
      );
    },
  );

  testWidgets(
    'GivenAMediaQuery_WhenTheTierIsReadFromContext_ThenItFollowsItsWidth',
    (tester) async {
      late Breakpoint read;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(800, 600)),
          child: Builder(
            builder: (context) {
              read = Breakpoint.from(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(read, Breakpoint.compact);
    },
  );
}
