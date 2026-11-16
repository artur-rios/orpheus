import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/core/di/providers.dart';
import 'package:orpheus/features/shell/application/shell_controller.dart';
import 'package:orpheus/features/shell/domain/shell_destination.dart';

/// Which area the shell shows, and what the search field holds.
void main() {
  ProviderContainer containerFor() {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    return container;
  }

  test('GivenAFreshStart_WhenTheShellIsAsked_ThenItShowsTheMusic', () {
    expect(containerFor().read(shellControllerProvider), ShellDestination.music);
  });

  for (final destination in ShellDestination.values) {
    test(
      'GivenTheShell_WhenTheOwnerGoesTo${destination.name}_ThenItShowsIt',
      () {
        final container = containerFor();

        container.read(shellControllerProvider.notifier).go(destination);

        expect(container.read(shellControllerProvider), destination);
      },
    );
  }

  test('GivenAFreshStart_WhenTheSearchIsAsked_ThenNothingIsTyped', () {
    final container = containerFor();

    expect(container.read(searchTermProvider), '');
    expect(container.read(searchFieldProvider), SearchField.all);
  });

  test(
    'GivenATypedTerm_WhenTheFieldIsCleared_ThenTheTermIsEmptyAgain',
    () {
      final container = containerFor();
      final search = container.read(searchTermProvider.notifier);

      search.type('heaven');
      expect(container.read(searchTermProvider), 'heaven');

      search.clear();
      expect(container.read(searchTermProvider), '');
    },
  );

  test(
    'GivenATypedTerm_WhenTheOwnerMovesToAnotherArea_ThenTheTermIsKept',
    () {
      final container = containerFor();
      container.read(searchTermProvider.notifier).type('heaven');

      container
          .read(shellControllerProvider.notifier)
          .go(ShellDestination.playlists);

      expect(container.read(searchTermProvider), 'heaven');
    },
  );

  test(
    'GivenTheSearchNarrowedToAlbums_WhenTheTermIsCleared_ThenItStaysOnAlbums',
    () {
      final container = containerFor();
      container.read(searchFieldProvider.notifier).choose(SearchField.albums);
      container.read(searchTermProvider.notifier)
        ..type('heaven')
        ..clear();

      expect(container.read(searchFieldProvider), SearchField.albums);
    },
  );

  for (final (label, term) in [
    ('Nothing', ''),
    ('OneLetter', 'a'),
    ('OneLetterInSpaces', '  a  '),
    ('OnlySpaces', '     '),
  ]) {
    test('Given${label}Typed_WhenAsked_ThenItIsNotWorthSearching', () {
      expect(isSearchable(term), isFalse);
    });
  }

  for (final (label, term) in [
    ('TwoLetters', 'ab'),
    ('TwoLettersInSpaces', ' ab '),
    ('AWord', 'heaven'),
  ]) {
    test('Given${label}Typed_WhenAsked_ThenItIsWorthSearching', () {
      expect(isSearchable(term), isTrue);
    });
  }
}
