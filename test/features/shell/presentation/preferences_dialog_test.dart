import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/core/di/providers.dart';
import 'package:orpheus/core/settings/in_memory_settings_store.dart';
import 'package:orpheus/features/shell/presentation/preferences_dialog.dart';

import '../../../support/fakes.dart';
import '../../../support/pump.dart';
import '../../../support/test_container.dart';

/// The Preferences dialog's *Show auto playlists* switch.
void main() {
  Future<Harness> open(WidgetTester tester, {required bool shown}) async {
    final harness = Harness(
      settings: InMemorySettingsStore(showsAutoPlaylists: shown),
    );
    await tester.pumpHarness(harness, const _OpenPreferences());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    return harness;
  }

  Finder autoSwitch() => find.ancestor(
    of: find.text('Show auto playlists'),
    matching: find.byType(SwitchListTile),
  );

  testWidgets(
    'GivenAPreferenceCannotBeSaved_WhenItIsChanged_ThenTheNoteSitsAboveTheYourDataSection',
    (tester) async {
      final harness = Harness(settings: UnwritableSettingsStore());
      await tester.pumpHarness(harness, const _OpenPreferences());
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(autoSwitch());
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: autoSwitch(), matching: find.byType(Switch)),
      );
      await tester.pumpAndSettle();

      final note = find.text(
        'This applies now, but could not be saved for next time.',
      );
      expect(note, findsOneWidget);
      expect(
        tester.getTopLeft(note).dy,
        lessThan(tester.getTopLeft(find.text('Your data')).dy),
      );
    },
  );

  testWidgets(
    'GivenTheAutoPlaylistsShown_WhenThePreferencesOpen_ThenTheSwitchIsOn',
    (tester) async {
      await open(tester, shown: true);

      expect(tester.widget<SwitchListTile>(autoSwitch()).value, isTrue);
    },
  );

  testWidgets(
    'GivenTheAutoPlaylistsShown_WhenTheSwitchIsTurnedOff_ThenThatIsStored',
    (tester) async {
      final harness = await open(tester, shown: true);

      await tester.ensureVisible(autoSwitch());
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: autoSwitch(), matching: find.byType(Switch)),
      );
      await tester.pumpAndSettle();

      expect(harness.settings.showsAutoPlaylists, isFalse);
      expect(
        harness.read(preferencesControllerProvider).showsAutoPlaylists,
        isFalse,
      );
      expect(tester.widget<SwitchListTile>(autoSwitch()).value, isFalse);
    },
  );

  testWidgets(
    'GivenTheAutoPlaylistsHidden_WhenTheSwitchIsTurnedOn_ThenThatIsStored',
    (tester) async {
      final harness = await open(tester, shown: false);

      await tester.ensureVisible(autoSwitch());
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: autoSwitch(), matching: find.byType(Switch)),
      );
      await tester.pumpAndSettle();

      expect(harness.settings.showsAutoPlaylists, isTrue);
    },
  );
}

/// A button that opens the preferences, so the dialog has a navigator.
class _OpenPreferences extends StatelessWidget {
  const _OpenPreferences();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Builder(
      builder: (context) => TextButton(
        onPressed: () => PreferencesDialog.show(context),
        child: const Text('open'),
      ),
    ),
  );
}
