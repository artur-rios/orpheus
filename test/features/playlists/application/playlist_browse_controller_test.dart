import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/core/di/providers.dart';

import '../../../support/test_container.dart';

/// Which playlist is open.
void main() {
  test('GivenNothingOpen_WhenAPlaylistIsOpened_ThenItIsTheOpenOne', () {
    final harness = Harness();

    expect(harness.read(playlistBrowseProvider), isNull);

    harness.read(playlistBrowseProvider.notifier).open('p');

    expect(harness.read(playlistBrowseProvider), 'p');
  });

  test('GivenAnOpenPlaylist_WhenItIsClosed_ThenNoneIsOpen', () {
    final harness = Harness();
    harness.read(playlistBrowseProvider.notifier).open('p');

    harness.read(playlistBrowseProvider.notifier).close();

    expect(harness.read(playlistBrowseProvider), isNull);
  });
}
