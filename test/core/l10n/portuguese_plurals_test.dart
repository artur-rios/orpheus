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

  test('GivenNothingToWrite_WhenTheButtonIsRead_ThenPortugueseSaysZero', () {
    expect(l10n.autofillWrite(0, 0), 'Gravar 0 alterações em 0 arquivos');
    expect(l10n.autofillWrite(1, 1), 'Gravar 1 alteração em 1 arquivo');
    expect(l10n.autofillWrite(3, 2), 'Gravar 3 alterações em 2 arquivos');
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
        'aparecem em algum ranking de artista, disco ou gênero abaixo.',
      );
      expect(
        l10n.statsUntaggedNote(1),
        '1 faixa tocada não tem tag de artista, disco ou gênero, então ela é '
        'contada nos totais acima mas não aparece em nenhum ranking de '
        'artista, disco ou gênero abaixo.',
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

  test(
    'GivenNothingCounted_WhenTheBatchAutofillIsRead_ThenPortugueseSaysZero',
    () {
      expect(l10n.autofillBatchUpdated(0), '0 atualizados');
      expect(l10n.autofillBatchUpdated(1), '1 atualizado');
      expect(l10n.autofillBatchNeedYou(0), '0 precisam de você');
      expect(l10n.autofillBatchNeedYou(1), '1 precisa de você');
      expect(l10n.autofillBatchNotFound(0), '0 não encontrados');
      expect(l10n.autofillBatchSkipped(1), '1 ignorado');
      expect(
        l10n.autofillBatchSummary(0, 3),
        '0 discos atualizados, 3 precisam de você',
      );
      expect(l10n.autofillBatchProgress(0, 0), 'Buscando 0 de 0 discos');
      expect(l10n.autofillBatchProgress(1, 1), 'Buscando 1 de 1 disco');
      expect(
        l10n.autofillDoubtUnmatchedSongs(1),
        '1 faixa sem correspondência',
      );
      expect(l10n.autofillDoubtDifferentSongs(2), '2 faixas diferentes');
      expect(
        l10n.autofillBatchConfirmBody(1, 1),
        startsWith('1 disco, cerca de 1 minuto.'),
      );
    },
  );
}
