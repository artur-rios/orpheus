import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/core/di/providers.dart';
import 'package:orpheus/features/playlists/domain/playlist.dart';

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

  group('the open playlist', () {
    final made = DateTime.utc(2026);
    final roadTrip = Playlist(
      id: 'p1',
      name: 'Road trip',
      createdAt: made,
      modifiedAt: made,
    );

    test('GivenNothingOpen_WhenTheOpenPlaylistIsRead_ThenItIsNull', () async {
      final harness = Harness(playlists: [roadTrip]);
      await harness.read(playlistsControllerProvider.future);

      expect(harness.read(openPlaylistProvider), isNull);
    });

    test(
      'GivenAKnownIdOpen_WhenTheOpenPlaylistIsRead_ThenItIsThatPlaylist',
      () async {
        final harness = Harness(playlists: [roadTrip]);
        await harness.read(playlistsControllerProvider.future);

        harness.read(playlistBrowseProvider.notifier).open('p1');

        expect(harness.read(openPlaylistProvider), roadTrip);
      },
    );

    test(
      'GivenAnUnknownIdOpen_WhenTheOpenPlaylistIsRead_ThenItIsNull',
      () async {
        final harness = Harness(playlists: [roadTrip]);
        await harness.read(playlistsControllerProvider.future);

        harness.read(playlistBrowseProvider.notifier).open('gone');

        expect(harness.read(openPlaylistProvider), isNull);
      },
    );

    test(
      'GivenAnOpenPlaylist_WhenItIsRenamed_ThenTheOpenPlaylistFollows',
      () async {
        final harness = Harness(playlists: [roadTrip]);
        await harness.read(playlistsControllerProvider.future);
        harness.read(playlistBrowseProvider.notifier).open('p1');

        await harness
            .read(playlistsControllerProvider.notifier)
            .rename('p1', 'Night drive');

        expect(harness.read(openPlaylistProvider)?.name, 'Night drive');
      },
    );
  });
}
