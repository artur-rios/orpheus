import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/playback/domain/music_layout.dart';

/// Reading a stored layout choice back.
void main() {
  for (final layout in MusicLayout.values) {
    test(
      'GivenTheStoredName${layout.name}_WhenRead_ThenItIsThatLayout',
      () {
        expect(MusicLayout.byName(layout.name), layout);
      },
    );
  }

  for (final (label, name) in <(String, String?)>[
    ('NoName', null),
    ('AnEmptyName', ''),
    ('ANameInTheWrongCase', 'Grid'),
    ('ALayoutThisVersionDoesNotHave', 'carousel'),
  ]) {
    test('Given${label}_WhenRead_ThenNoLayoutIsChosen', () {
      expect(MusicLayout.byName(name), isNull);
    });
  }
}
