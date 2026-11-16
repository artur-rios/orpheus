import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/core/di/providers.dart';

/// Whether the player shows the words instead of the sleeve.
void main() {
  ProviderContainer containerFor() {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    return container;
  }

  test('GivenAFreshStart_WhenThePlayerOpens_ThenItShowsTheSleeve', () {
    expect(containerFor().read(lyricsVisibilityProvider), isFalse);
  });

  test(
    'GivenTheSleeveShown_WhenToggledTwice_ThenTheWordsAndThenTheSleeveAreShown',
    () {
      final container = containerFor();
      final visibility = container.read(lyricsVisibilityProvider.notifier);

      visibility.toggle();
      expect(container.read(lyricsVisibilityProvider), isTrue);

      visibility.toggle();
      expect(container.read(lyricsVisibilityProvider), isFalse);
    },
  );
}
