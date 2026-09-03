import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/core/di/providers.dart';
import 'package:orpheus/features/playback/presentation/media_session_names_scope.dart';

import '../../../support/entries.dart';
import '../../../support/pump.dart';
import '../../../support/test_container.dart';

/// The one thing the media session needs that only the widget tree has.
///
/// The whole feature is gated on these words arriving: nothing is published to
/// a notification before them, so a shell that stopped supplying them would be
/// a lock screen that silently went blank rather than a test that failed
/// somewhere obvious. That is what these two are here to catch.
void main() {
  final library = [entry(id: 'nothing')];

  testWidgets(
    'GivenTheShellIsOnScreen_WhenATrackWithNoTagsIsPlayed_ThenTheSessionShowsTheEnglishWords',
    (tester) async {
      final harness = Harness(library: library);
      await tester.pumpHarness(
        harness,
        const MediaSessionNamesScope(child: SizedBox.shrink()),
      );
      await harness.library();

      await harness
          .read(audioPlaybackControllerProvider.notifier)
          .playTrack(library.single.file);
      await tester.pumpAndSettle();

      expect(harness.session.onScreen!.title, 'Untitled');
    },
  );

  testWidgets(
    'GivenTheOwnerReadsPortuguese_WhenATrackWithNoTagsIsPlayed_ThenTheSessionShowsThePortugueseWords',
    (tester) async {
      // The words are the interface's own, not the application layer's, which
      // is the entire reason they are handed over from here.
      final harness = Harness(library: library);
      await tester.pumpHarness(
        harness,
        const MediaSessionNamesScope(child: SizedBox.shrink()),
        locale: const Locale('pt', 'BR'),
      );
      await harness.library();

      await harness
          .read(audioPlaybackControllerProvider.notifier)
          .playTrack(library.single.file);
      await tester.pumpAndSettle();

      expect(harness.session.onScreen!.title, 'Sem título');
    },
  );
}
