import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/core/l10n/generated/app_localizations.dart';

/// Counts in Portuguese.
///
/// Portuguese files zero under "one", so a plural that names only `=1` and
/// `other` renders a count of nothing as "1".
void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('pt'));
  });

  test(
    'GivenNoUnreadableFile_WhenTheScanIsReported_ThenPortugueseSaysNone',
    () {
      expect(l10n.scanUnreadable(0), 'Nenhum arquivo tinha tags ilegíveis.');
      expect(l10n.scanUnreadable(1), '1 arquivo tinha tags ilegíveis.');
    },
  );

  test(
    'GivenARowWithNoPlays_WhenItsPlaysAreCounted_ThenPortugueseSaysZero',
    () {
      expect(l10n.statsPlaysCount(0), '0 reproduções');
      expect(l10n.statsPlaysCount(1), '1 reprodução');
    },
  );

  test(
    'GivenNoUntaggedTrack_WhenTheNoteIsRead_ThenPortugueseSaysEveryOneIsRanked',
    () {
      expect(
        l10n.statsUntaggedNote(0),
        'Toda faixa tocada tem tag de artista, disco ou gênero, então todas '
        'aparecem em algum ranking abaixo.',
      );
      expect(
        l10n.statsUntaggedNote(1),
        '1 faixa tocada não tem tag de artista, disco ou gênero, então ela é '
        'contada nos totais acima mas não aparece em nenhum ranking abaixo.',
      );
    },
  );

  test('GivenNoPlays_WhenTheStoryOpens_ThenPortugueseSaysZero', () {
    expect(l10n.storyOpeningPlays(0), '0 reproduções');
    expect(l10n.storyOpeningPlays(1), '1 reprodução');
  });

  test('GivenNoTracks_WhenTheStoryOpens_ThenPortugueseSaysZero', () {
    expect(l10n.storyOpeningTracks(0), 'em 0 faixas');
    expect(l10n.storyOpeningTracks(1), 'em 1 faixa');
  });
}
