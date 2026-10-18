import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/core/di/providers.dart';
import 'package:orpheus/features/playback/domain/song_selection.dart';

import '../../../support/test_container.dart';

/// The one selection the song lists share.
void main() {
  const scope = 'songs';
  const order = ['a', 'b', 'c', 'd'];

  late Harness harness;

  setUp(() => harness = Harness());

  SongSelection stateOf() => harness.read(songSelectionProvider);

  test('GivenNothing_WhenTheControllerIsRead_ThenNothingIsSelected', () {
    expect(stateOf(), SongSelection.none);
  });

  test('GivenASelection_WhenCleared_ThenNothingIsSelected', () {
    harness.read(songSelectionProvider.notifier)
      ..toggle(scope, 'a')
      ..clear();

    expect(stateOf(), SongSelection.none);
  });

  test('GivenNothing_WhenToggled_ThenItDelegatesToTheSelection', () {
    harness.read(songSelectionProvider.notifier).toggle(scope, 'b');

    expect(stateOf().paths, {'b'});
    expect(stateOf().scope, scope);
  });

  test('GivenAnAnchor_WhenRangeTo_ThenItDelegatesToTheSelection', () {
    harness.read(songSelectionProvider.notifier)
      ..toggle(scope, 'a')
      ..rangeTo(scope, 'c', order);

    expect(stateOf().paths, {'a', 'b', 'c'});
  });

  test('GivenNothing_WhenSelectAll_ThenItDelegatesToTheSelection', () {
    harness.read(songSelectionProvider.notifier).selectAll(scope, order);

    expect(stateOf().paths, order.toSet());
  });

  test('GivenASelection_WhenRetained_ThenItDelegatesToTheSelection', () {
    harness.read(songSelectionProvider.notifier)
      ..selectAll(scope, order)
      ..retainIn(scope, ['b', 'z']);

    expect(stateOf().paths, {'b'});
  });

  test('GivenASelectionWhoseListLeft_WhenEndIfUnshown_ThenItEnds', () async {
    await harness.library();
    harness.read(songSelectionProvider.notifier)
      ..attach(scope)
      ..toggle(scope, 'a')
      ..detach(scope)
      ..endIfUnshown(scope);

    expect(stateOf(), SongSelection.none);
  });

  test(
    'GivenTwoListsOfTheScope_WhenOneLeaves_ThenTheSelectionIsKept',
    () async {
      await harness.library();
      harness.read(songSelectionProvider.notifier)
        ..attach(scope)
        ..attach(scope)
        ..toggle(scope, 'a')
        ..detach(scope)
        ..endIfUnshown(scope);

      expect(stateOf().paths, {'a'});
    },
  );

  test('GivenTheLibraryLoading_WhenTheListLeaves_ThenTheSelectionIsKept', () {
    // Not awaited: the library is still being read.
    harness.read(songSelectionProvider.notifier)
      ..attach(scope)
      ..toggle(scope, 'a')
      ..detach(scope)
      ..endIfUnshown(scope);

    expect(stateOf().paths, {'a'});
  });
}
