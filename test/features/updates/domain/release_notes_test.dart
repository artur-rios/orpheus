import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/updates/domain/release_notes.dart';

/// Making a release's notes readable without rendering them.
void main() {
  test(
    'GivenTheNotesThisProjectActuallyPublishes_WhenTheyAreTidied_ThenTheTableIsGoneAndTheNewsRemains',
    () {
      // The opening of the real v1.0.1 body. Shown as Markdown source it is a
      // wall of pipes before the owner reaches anything that concerns them.
      const notes = '''
## Downloads

| Platform | File | What it is |
| --- | --- | --- |
| Windows | `orpheus-setup-1.0.1.exe` | Installer. |
| Linux | `orpheus-installer-1.0.1.sh` | Installer. |

### Android: uninstall 1.0.0 first, this once

The 1.0.0 APK was signed with a **throwaway key**.
''';

      final readable = ReleaseNotes.readable(notes)!;

      expect(readable, isNot(contains('|')));
      expect(readable, isNot(contains('#')));
      expect(readable, isNot(contains('**')));
      expect(readable, isNot(contains('`')));
      expect(readable, startsWith('Downloads'));
      expect(readable, contains('Android: uninstall 1.0.0 first, this once'));
      expect(readable, contains('The 1.0.0 APK was signed with a throwaway key.'));
    },
  );

  test(
    'GivenABulletedList_WhenItIsTidied_ThenTheBulletsAreBulletsRatherThanAsterisks',
    () {
      final readable = ReleaseNotes.readable('- one\n* two\n+ three')!;

      expect(readable, '• one\n• two\n• three');
    },
  );

  test(
    'GivenNotesThatAreNothingButATable_WhenTheyAreTidied_ThenNothingComesBack',
    () {
      // Better an absent section than an empty heading over blank space.
      expect(ReleaseNotes.readable('| a | b |\n| --- | --- |'), isNull);
      expect(ReleaseNotes.readable('   \n\n  '), isNull);
      expect(ReleaseNotes.readable(null), isNull);
    },
  );

  test(
    'GivenTheGapsLeftByDroppedLines_WhenTheyAreTidied_ThenTheyDoNotBecomeBlankExpanses',
    () {
      final readable = ReleaseNotes.readable('One\n\n---\n\n\n\nTwo')!;

      expect(readable, 'One\n\nTwo');
    },
  );
}
