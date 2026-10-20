// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appTitle => 'Orpheus';

  @override
  String get loading => 'Carregando';

  @override
  String get retry => 'Tentar novamente';

  @override
  String get close => 'Fechar';

  @override
  String get cancel => 'Cancelar';

  @override
  String get dismiss => 'Dispensar';

  @override
  String get remove => 'Remover';

  @override
  String get done => 'Concluído';

  @override
  String get openSettings => 'Abrir configurações';

  @override
  String get destinationMusic => 'Músicas';

  @override
  String get destinationGenres => 'Gêneros';

  @override
  String get destinationQueue => 'Fila';

  @override
  String get destinationFolders => 'Pastas';

  @override
  String get searchHint => 'Pesquisar na biblioteca';

  @override
  String get searchClear => 'Limpar a pesquisa';

  @override
  String searchResults(String term) {
    return 'Resultados para “$term”';
  }

  @override
  String searchEmpty(String term) {
    return 'Nada na biblioteca corresponde a “$term”.';
  }

  @override
  String get searchFieldAll => 'Tudo';

  @override
  String get searchFieldSongs => 'Faixas';

  @override
  String get searchFieldArtists => 'Artistas';

  @override
  String get searchFieldAlbums => 'Álbuns';

  @override
  String get searchFieldGenres => 'Gêneros';

  @override
  String get settingsTitle => 'Preferências';

  @override
  String get settingsAppearance => 'Aparência';

  @override
  String get settingsTheme => 'Tema';

  @override
  String get themeSystem => 'Seguir o sistema';

  @override
  String get themeLight => 'Claro';

  @override
  String get themeDark => 'Escuro';

  @override
  String get settingsLanguage => 'Idioma';

  @override
  String get languageSystem => 'Seguir o sistema';

  @override
  String get languageEnglish => 'Inglês';

  @override
  String get languagePortuguese => 'Português (Brasil)';

  @override
  String get settingsPlayback => 'Reprodução';

  @override
  String get settingsOpensPlayerOnPlay => 'Abrir o player ao iniciar uma faixa';

  @override
  String get settingsRescansAtStartup =>
      'Reexaminar a biblioteca a cada inicialização';

  @override
  String get settingsLyrics => 'Letras';

  @override
  String get settingsFetchesLyricsOnline =>
      'Buscar letras ausentes na internet';

  @override
  String get settingsFetchesLyricsOnlineDetail =>
      'Para uma faixa sem letra nesta máquina, o Orpheus envia o artista e o título dela ao lrclib.net e salva o que voltar como um arquivo .lrc ao lado da faixa. É a única coisa que o Orpheus envia a algum lugar.';

  @override
  String get settingsVolume => 'Volume';

  @override
  String get settingsUnsaved =>
      'Isto vale agora, mas não pôde ser salvo para a próxima vez.';

  @override
  String get musicViewArtists => 'Artistas';

  @override
  String get musicViewAlbums => 'Álbuns';

  @override
  String get musicViewSongs => 'Faixas';

  @override
  String get musicBreadcrumbRoot => 'Biblioteca';

  @override
  String musicJumpToLetter(String letter) {
    return 'Ir para a letra $letter';
  }

  @override
  String get musicUnknownArtist => 'Artista desconhecido';

  @override
  String get musicUnknownAlbum => 'Álbum desconhecido';

  @override
  String get musicUnknownTitle => 'Sem título';

  @override
  String get musicEmpty => 'Sua biblioteca está vazia.';

  @override
  String get musicEmptyHint =>
      'Adicione a pasta onde está sua música e o Orpheus vai lê-la.';

  @override
  String get musicRowActions => 'Ações para esta faixa';

  @override
  String get layoutList => 'Lista';

  @override
  String get layoutGrid => 'Grade';

  @override
  String musicTrackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count faixas',
      one: '1 faixa',
      zero: 'Nenhuma faixa',
    );
    return '$_temp0';
  }

  @override
  String get genreUnknown => 'Sem gênero';

  @override
  String get genrePlay => 'Reproduzir o gênero';

  @override
  String get genreShuffle => 'Embaralhar o gênero';

  @override
  String genreRowSummary(String tracks, String length) {
    return '$tracks · $length';
  }

  @override
  String get playbackNothingPlaying => 'Nada em reprodução';

  @override
  String get playbackBarLabel => 'Reprodução';

  @override
  String get audioPlay => 'Reproduzir';

  @override
  String get audioPause => 'Pausar';

  @override
  String get audioStop => 'Parar';

  @override
  String get audioNext => 'Próxima faixa';

  @override
  String get audioPrevious => 'Faixa anterior';

  @override
  String get audioPlayAlbum => 'Reproduzir o álbum';

  @override
  String get audioPlayArtist => 'Reproduzir o artista';

  @override
  String get audioShuffleAlbum => 'Embaralhar o álbum';

  @override
  String get audioShuffleArtist => 'Embaralhar o artista';

  @override
  String get audioShuffleAll => 'Embaralhar tudo';

  @override
  String get audioShuffleAllLabel => 'Tudo, embaralhado';

  @override
  String get audioOpenPlayer => 'Abrir o player';

  @override
  String get audioClosePlayer => 'Fechar o player';

  @override
  String audioSkipped(String title) {
    return '“$title” foi pulada — não foi possível reproduzi-la.';
  }

  @override
  String get audioNothingPlayable =>
      'Não foi possível reproduzir nada dessa seleção.';

  @override
  String audioResumePrompt(String position) {
    return 'Continuar de $position?';
  }

  @override
  String get audioResume => 'Continuar';

  @override
  String get audioStartOver => 'Começar do início';

  @override
  String get audioSoundBarsLabel => 'Barras de som';

  @override
  String get lyricsShow => 'Mostrar a letra';

  @override
  String get lyricsHide => 'Ocultar a letra';

  @override
  String get lyricsLabel => 'Letra';

  @override
  String get lyricsNone => 'Sem letra para esta faixa';

  @override
  String get lyricsWhereTheyComeFrom =>
      'O Orpheus lê a letra de um arquivo .lrc ao lado da faixa, ou das tags da própria faixa. Quando não há nenhuma e a busca online está ativada, ele a pede a um serviço de letras.';

  @override
  String get lyricsNotSynced =>
      'Esta letra não tem marcações de tempo, então não acompanha a música.';

  @override
  String get albumCoverLabel => 'Capa do álbum';

  @override
  String get audioRepeatOff => 'Repetição desligada';

  @override
  String get audioRepeatAll => 'Repetir a fila';

  @override
  String get audioRepeatOne => 'Repetir esta faixa';

  @override
  String get audioVolume => 'Volume';

  @override
  String get queueEmpty => 'Nada na fila.';

  @override
  String get queueNowPlaying => 'Reproduzindo agora';

  @override
  String queuePosition(int index, int total) {
    return '$index de $total';
  }

  @override
  String get foldersTitle => 'Pastas da biblioteca';

  @override
  String get foldersDescription =>
      'O Orpheus lê os arquivos de áudio dentro destas pastas. Ele nunca os move, altera ou apaga.';

  @override
  String get foldersEmpty => 'Nenhuma pasta ainda.';

  @override
  String get foldersAdd => 'Adicionar uma pasta';

  @override
  String get foldersAddDefault => 'Adicionar minha pasta de músicas';

  @override
  String get foldersRemove => 'Remover esta pasta';

  @override
  String get foldersRemoveTitle => 'Remover esta pasta?';

  @override
  String get foldersRemoveBody =>
      'As faixas dela saem da biblioteca na próxima varredura. Nada no disco é alterado.';

  @override
  String get scanNow => 'Examinar agora';

  @override
  String scanWalking(int count) {
    return 'Procurando músicas… $count arquivos encontrados';
  }

  @override
  String scanReading(int read, int total) {
    return 'Lendo $read de $total';
  }

  @override
  String get scanNever => 'Esta biblioteca nunca foi examinada.';

  @override
  String scanLastAt(String when) {
    return 'Última varredura em $when.';
  }

  @override
  String scanReport(int tracks, int added, int updated, int removed) {
    return '$tracks faixas — $added novas, $updated atualizadas, $removed removidas.';
  }

  @override
  String scanUnreadable(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count arquivos tinham tags ilegíveis.',
      one: '1 arquivo tinha tags ilegíveis.',
      zero: 'Nenhum arquivo tinha tags ilegíveis.',
    );
    return '$_temp0';
  }

  @override
  String scanUnreachable(String path) {
    return 'Esta pasta não estava lá: $path';
  }

  @override
  String get foldersEveryFolderTitle => 'O Android não entrega esta pasta';

  @override
  String get foldersEveryFolderBody =>
      'Um cartão de memória, ou um pen drive ligado ao celular, é montado fora do armazenamento que o Android dá a um aplicativo por padrão — então uma pasta em um deles aparece como uma pasta que não existe. Para lê-la é preciso o acesso a todos os arquivos, concedido nas configurações do sistema e revogável lá a qualquer momento. O Orpheus continua lendo apenas as pastas que você registrou, e continua nunca escrevendo nelas.';

  @override
  String get foldersEveryFolderGrant => 'Permitir todos os arquivos';

  @override
  String get foldersEveryFolderGrantedTitle =>
      'O Orpheus já lê todas as pastas';

  @override
  String get foldersEveryFolderGrantedBody =>
      'O acesso a todos os arquivos já está concedido, então uma pasta que ainda aparece como uma pasta que não existe é uma pasta que esta execução do Orpheus não enxerga. O Android decide qual armazenamento um aplicativo alcança no momento em que ele inicia: um cartão ou um pen drive montado depois disso — ou esta permissão concedida depois disso — fica fora do que esta execução recebeu. Com o cartão ou o pen drive conectado, feche o Orpheus, abra de novo e escaneie.';

  @override
  String scanTracksFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count faixas',
      one: '1 faixa',
      zero: 'Nenhuma faixa',
    );
    return '$_temp0 na biblioteca.';
  }

  @override
  String get failureCatalogUnavailable =>
      'Não foi possível salvar a biblioteca. Esta varredura precisará ser refeita na próxima vez que o Orpheus abrir.';

  @override
  String get failurePermissionDenied =>
      'O Orpheus precisa de permissão para ler seus arquivos de áudio.';

  @override
  String get failurePermissionDeniedPermanently =>
      'A permissão para ler arquivos de áudio foi negada. Conceda-a nas configurações do sistema.';

  @override
  String get failureUnexpected => 'Algo deu errado.';

  @override
  String get statsTitle => 'O que você ouve';

  @override
  String get statsOpen => 'Estatísticas';

  @override
  String get statsReadAgain => 'Ler novamente';

  @override
  String get statsTotalPlays => 'Reproduções';

  @override
  String get statsDistinctTracks => 'Faixas';

  @override
  String get statsTopTracks => 'Faixas mais tocadas';

  @override
  String get statsTopArtists => 'Artistas mais tocados';

  @override
  String get statsTopAlbums => 'Discos mais tocados';

  @override
  String get statsTopGenres => 'Gêneros mais tocados';

  @override
  String get statsRankingEmpty => 'Nada aqui ainda';

  @override
  String get statsEmptyTitle => 'Nada contabilizado ainda';

  @override
  String get statsEmptyBody =>
      'Uma faixa conta quando você ouve metade dela, ou quatro minutos dela — o que vier primeiro.';

  @override
  String statsPlaysCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reproduções',
      one: '1 reprodução',
      zero: '0 reproduções',
    );
    return '$_temp0';
  }

  @override
  String statsUntaggedNote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count faixas tocadas não têm tag de artista, disco ou gênero, então elas são contadas nos totais acima mas não aparecem em nenhum ranking de artista, disco ou gênero abaixo.',
      one: '1 faixa tocada não tem tag de artista, disco ou gênero, então ela é contada nos totais acima mas não aparece em nenhum ranking de artista, disco ou gênero abaixo.',
      zero: 'Toda faixa tocada tem tag de artista, disco ou gênero, então todas aparecem em algum ranking de artista, disco ou gênero abaixo.',
    );
    return '$_temp0';
  }

  @override
  String get settingsUpdates => 'Atualizações';

  @override
  String get settingsChecksForUpdatesOnStartup =>
      'Procurar atualizações ao iniciar o Orpheus';

  @override
  String get settingsChecksForUpdatesOnStartupDetail =>
      'Pergunta ao GitHub uma vez por inicialização se existe uma versão mais nova. Nada mais é enviado, e uma atualização só é baixada depois que você aceitar.';

  @override
  String updateAvailableTitle(String version) {
    return 'O Orpheus $version está disponível';
  }

  @override
  String updateCurrentVersion(String version) {
    return 'Você tem a versão $version.';
  }

  @override
  String get updateNow => 'Atualizar agora';

  @override
  String get updateLater => 'Agora não';

  @override
  String get updateSkip => 'Ignorar esta versão';

  @override
  String get updateDownloading => 'Baixando…';

  @override
  String get updateVerifying => 'Verificando o que foi baixado…';

  @override
  String get updateHandedOff =>
      'O Orpheus está fechando para que o instalador possa substituí-lo.';

  @override
  String get updateNeedsCommandTitle => 'Quase lá';

  @override
  String get updateNeedsCommandBody =>
      'O Orpheus está instalado para todos neste computador, e substituí-lo exige permissões de administrador. A atualização foi baixada e verificada; execute isto em um terminal para concluir:';

  @override
  String get updateCopyCommand => 'Copiar';

  @override
  String get updateCommandCopied => 'Copiado.';

  @override
  String get updateFailedNoPackage =>
      'Esta versão não tem um pacote para o seu sistema.';

  @override
  String get updateFailedDownload =>
      'Não foi possível baixar a atualização. Sua conexão pode ter caído.';

  @override
  String get updateFailedChecksum =>
      'O que foi baixado não corresponde ao que a versão publicou, então não foi executado. Tente novamente ou baixe da página da versão você mesmo.';

  @override
  String get updateFailedLaunch => 'O instalador foi baixado, mas não iniciou.';

  @override
  String get updateRetry => 'Tentar novamente';

  @override
  String get updateClose => 'Fechar';

  @override
  String get updateReleaseNotes => 'O que mudou';

  @override
  String get statsStory => 'Ver como história';

  @override
  String get storyOpeningTitle => 'Suas escutas, até aqui';

  @override
  String storyOpeningPlays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reproduções',
      one: '1 reprodução',
      zero: '0 reproduções',
    );
    return '$_temp0';
  }

  @override
  String storyOpeningTracks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count faixas',
      one: '1 faixa',
      zero: '0 faixas',
    );
    return 'em $_temp0';
  }

  @override
  String get storyTopArtist => 'Seu artista favorito';

  @override
  String get storyTopAlbum => 'Seu disco favorito';

  @override
  String get storyTopTrack => 'Sua faixa favorita';

  @override
  String get storyTopGenre => 'Seu gênero favorito';

  @override
  String get storyRankingArtists => 'Seus artistas';

  @override
  String get storyRankingAlbums => 'Seus discos';

  @override
  String get storyRankingTracks => 'Suas faixas';

  @override
  String get storyRankingGenres => 'Seus gêneros';

  @override
  String storyShareOfPlays(String percent) {
    return '$percent% do que você ouviu';
  }

  @override
  String get storySummaryTitle => 'Esse é o seu Orpheus';

  @override
  String get storyShare => 'Compartilhar';

  @override
  String get storySave => 'Salvar a imagem';

  @override
  String get storyShared => 'Compartilhado.';

  @override
  String get storySaved => 'Salvo.';

  @override
  String get storyShareFailed => 'Não foi possível criar a imagem.';

  @override
  String get storyClose => 'Fechar a história';

  @override
  String get storyNext => 'Próximo';

  @override
  String get storyPrevious => 'Anterior';

  @override
  String get storyMadeWith => 'Feito com o Orpheus';

  @override
  String get autofillAction => 'Preencher tags…';

  @override
  String get autofillFieldsTitle => 'Preencher quais tags?';

  @override
  String get autofillFind => 'Buscar';

  @override
  String get autofillNothingWritable =>
      'O Orpheus só altera tags de arquivos MP3 e FLAC.';

  @override
  String get autofillCoverNote =>
      'Baixa a capa do Cover Art Archive e a guarda em cada arquivo.';

  @override
  String get autofillFieldTitle => 'Título';

  @override
  String get autofillFieldArtist => 'Artista';

  @override
  String get autofillFieldAlbumArtist => 'Artista do álbum';

  @override
  String get autofillFieldAlbum => 'Álbum';

  @override
  String get autofillFieldTrackNumber => 'Número da faixa';

  @override
  String get autofillFieldTrackTotal => 'Total de faixas';

  @override
  String get autofillFieldDiscNumber => 'Número do disco';

  @override
  String get autofillFieldDiscTotal => 'Total de discos';

  @override
  String get autofillFieldYear => 'Ano';

  @override
  String get autofillFieldGenre => 'Gênero';

  @override
  String get autofillFieldCover => 'Capa';

  @override
  String get autofillSearching => 'Buscando no MusicBrainz…';

  @override
  String get autofillUnreachable => 'Não foi possível acessar o MusicBrainz.';

  @override
  String get autofillRateLimited =>
      'O MusicBrainz está ocupado. Tente de novo em instantes.';

  @override
  String get autofillTryAgain => 'Tentar de novo';

  @override
  String get autofillNothingFound => 'Nada encontrado no MusicBrainz.';

  @override
  String get autofillSearchLabel => 'Buscar no MusicBrainz';

  @override
  String get autofillSearchAgain => 'Buscar de novo';

  @override
  String get autofillDifferentRelease => 'Outro lançamento';

  @override
  String autofillWrite(int changes, int files) {
    String _temp0 = intl.Intl.pluralLogic(
      changes,
      locale: localeName,
      other: '$changes alterações',
      one: '1 alteração',
      zero: '0 alterações',
    );
    String _temp1 = intl.Intl.pluralLogic(
      files,
      locale: localeName,
      other: '$files arquivos',
      one: '1 arquivo',
      zero: '0 arquivos',
    );
    return 'Gravar $_temp0 em $_temp1';
  }

  @override
  String get autofillTickAll => 'Marcar tudo';

  @override
  String get autofillUntickAll => 'Desmarcar tudo';

  @override
  String get autofillNoChanges => 'Já está igual';

  @override
  String get autofillNoMatch => 'Sem correspondência neste lançamento';

  @override
  String get autofillUnwritable => 'O Orpheus não altera este tipo de arquivo';

  @override
  String get autofillUnsafeTags =>
      'O Orpheus não consegue alterar as tags deste arquivo com segurança';

  @override
  String autofillNotWritableFields(String fields) {
    return 'Este tipo de arquivo não comporta: $fields';
  }

  @override
  String get autofillCoverMissing =>
      'Este lançamento não tem capa no Cover Art Archive.';

  @override
  String get autofillCoverUnavailable =>
      'Não foi possível baixar a capa do Cover Art Archive.';

  @override
  String autofillWriting(int done, int total) {
    return 'Gravando $done de $total…';
  }

  @override
  String get autofillCancel => 'Cancelar';

  @override
  String get autofillClose => 'Fechar';

  @override
  String autofillWritten(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count arquivos atualizados.',
      one: '1 arquivo atualizado.',
      zero: 'Nenhum arquivo atualizado.',
    );
    return '$_temp0';
  }

  @override
  String get autofillOutcomeChanged => 'Alterado desde a leitura — não gravado';

  @override
  String get autofillOutcomeInUse =>
      'Em uso pela reprodução — tente de novo depois';

  @override
  String get autofillOutcomeNotWritten => 'Não gravado — cancelado antes';

  @override
  String get autofillOutcomeDenied =>
      'O Orpheus não tem permissão para alterá-lo';

  @override
  String get autofillOutcomeFailed => 'Não foi possível gravar';

  @override
  String get autofillOutcomeUnsupported =>
      'O Orpheus não altera este tipo de arquivo';

  @override
  String get autofillAccessRefused =>
      'O Orpheus precisa de permissão para alterar seus arquivos de música. Nada foi gravado.';

  @override
  String get autofillOpenSettings => 'Abrir configurações';

  @override
  String autofillBatchConfirmTitle(int songs) {
    final intl.NumberFormat songsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String songsString = songsNumberFormat.format(songs);

    String _temp0 = intl.Intl.pluralLogic(
      songs,
      locale: localeName,
      other: '$songsString faixas',
      one: '1 faixa',
      zero: '0 faixas',
    );
    return 'Preencher $_temp0?';
  }

  @override
  String autofillBatchConfirmBody(int records, int minutes) {
    final intl.NumberFormat recordsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String recordsString = recordsNumberFormat.format(records);
    final intl.NumberFormat minutesNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String minutesString = minutesNumberFormat.format(minutes);

    String _temp0 = intl.Intl.pluralLogic(
      records,
      locale: localeName,
      other: '$recordsString discos',
      one: '1 disco',
      zero: '0 discos',
    );
    String _temp1 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutesString minutos',
      one: '1 minuto',
      zero: '0 minutos',
    );
    return '$_temp0, cerca de $_temp1. Os discos que correspondem claramente ao MusicBrainz são gravados sem perguntar, substituindo as tags atuais; os outros ficam guardados para você conferir.';
  }

  @override
  String autofillBatchConfirmSkipped(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString faixas não podem ser alteradas e serão ignoradas.',
      one: '1 faixa não pode ser alterada e será ignorada.',
      zero: '0 faixas não podem ser alteradas e serão ignoradas.',
    );
    return '$_temp0';
  }

  @override
  String get autofillBatchStart => 'Iniciar';

  @override
  String get autofillBatchReplaceTitle => 'Iniciar um novo preenchimento?';

  @override
  String autofillBatchReplaceBody(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Os $countString discos que esperam por você serão esquecidos.',
      one: 'O disco que espera por você será esquecido.',
      zero: 'Os 0 discos que esperam por você serão esquecidos.',
    );
    return '$_temp0';
  }

  @override
  String get autofillBatchReplaceConfirm => 'Iniciar novo';

  @override
  String get autofillBatchTitle => 'Preenchimento automático';

  @override
  String autofillBatchProgress(int done, int total) {
    final intl.NumberFormat doneNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String doneString = doneNumberFormat.format(done);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: 'Buscando $doneString de $totalString discos',
      one: 'Buscando $doneString de 1 disco',
      zero: 'Buscando $doneString de 0 discos',
    );
    return '$_temp0';
  }

  @override
  String autofillBatchUpdated(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString atualizados',
      one: '1 atualizado',
      zero: '0 atualizados',
    );
    return '$_temp0';
  }

  @override
  String autofillBatchNeedYou(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString precisam de você',
      one: '1 precisa de você',
      zero: '0 precisam de você',
    );
    return '$_temp0';
  }

  @override
  String autofillBatchAlreadyRight(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString já estão certos',
      one: '1 já está certo',
      zero: '0 já estão certos',
    );
    return '$_temp0';
  }

  @override
  String autofillBatchNotFound(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString não encontrados',
      one: '1 não encontrado',
      zero: '0 não encontrados',
    );
    return '$_temp0';
  }

  @override
  String autofillBatchSkipped(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString ignorados',
      one: '1 ignorado',
      zero: '0 ignorados',
    );
    return '$_temp0';
  }

  @override
  String get autofillBatchStop => 'Parar';

  @override
  String get autofillBatchStopping => 'Parando…';

  @override
  String get autofillBatchClearList => 'Limpar lista';

  @override
  String get autofillBatchClearTitle => 'Limpar a lista?';

  @override
  String get autofillBatchClearBody =>
      'Os discos que esperam por você serão esquecidos. Nada será gravado.';

  @override
  String get autofillBatchClearConfirm => 'Limpar';

  @override
  String get autofillBatchPaused =>
      'Não foi possível acessar o MusicBrainz. O preenchimento está em pausa.';

  @override
  String autofillBatchSummary(int updated, int needYou) {
    final intl.NumberFormat updatedNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String updatedString = updatedNumberFormat.format(updated);
    final intl.NumberFormat needYouNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String needYouString = needYouNumberFormat.format(needYou);

    String _temp0 = intl.Intl.pluralLogic(
      updated,
      locale: localeName,
      other: '$updatedString discos atualizados',
      one: '1 disco atualizado',
      zero: '0 discos atualizados',
    );
    String _temp1 = intl.Intl.pluralLogic(
      needYou,
      locale: localeName,
      other: '$needYouString precisam de você',
      one: '1 precisa de você',
      zero: '0 precisam de você',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String get autofillBatchSectionNeedYou => 'Precisam de você';

  @override
  String get autofillBatchSectionNotFound => 'Não encontrados';

  @override
  String get autofillBatchSectionNotWritable => 'Não podem ser alteradas';

  @override
  String get autofillBatchSectionFailed => 'Não foi possível gravar ou buscar';

  @override
  String get autofillBatchSectionNotLookedUp => 'Não buscados';

  @override
  String get autofillDoubtNoMatch => 'Sem correspondência';

  @override
  String get autofillDoubtNotOfficial => 'Não é um lançamento oficial';

  @override
  String get autofillDoubtDifferentAlbum => 'Nome de álbum diferente';

  @override
  String get autofillDoubtDifferentArtist => 'Artista diferente';

  @override
  String autofillDoubtUnmatchedSongs(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString faixas sem correspondência',
      one: '1 faixa sem correspondência',
      zero: '0 faixas sem correspondência',
    );
    return '$_temp0';
  }

  @override
  String autofillDoubtDifferentSongs(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString faixas diferentes',
      one: '1 faixa diferente',
      zero: '0 faixas diferentes',
    );
    return '$_temp0';
  }

  @override
  String get autofillDoubtWouldSplitAlbum => 'Dividiria o álbum';

  @override
  String get autofillDoubtUncertainTrack => 'Correspondência incerta';

  @override
  String autofillBatchIndicatorRunning(int done, int total) {
    final intl.NumberFormat doneNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String doneString = doneNumberFormat.format(done);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'Preenchendo $doneString/$totalString';
  }

  @override
  String get autofillBatchIndicatorPaused => 'Preenchimento em pausa';

  @override
  String autofillBatchIndicatorNeedYou(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString precisam de você',
      one: '1 precisa de você',
      zero: '0 precisam de você',
    );
    return '$_temp0';
  }

  @override
  String get autofillBatchIndicatorDone => 'Preenchimento concluído';

  @override
  String get tagEditAction => 'Editar tags…';

  @override
  String get tagEditTitle => 'Editar tags';

  @override
  String get tagEditSave => 'Salvar';

  @override
  String get tagEditChooseCover => 'Escolher imagem…';

  @override
  String get tagEditRemoveCover => 'Remover';

  @override
  String get tagEditNoCover => 'Sem capa';

  @override
  String get tagEditCoverNotImage => 'Escolha uma imagem JPEG ou PNG';

  @override
  String get tagEditWholeNumber => 'Digite um número inteiro';

  @override
  String get tagEditYearRange => 'Digite um ano de 1 a 9999';

  @override
  String get tagEditNumberForTotal => 'Digite um número ou apague o total';

  @override
  String get tagEditReload => 'Recarregar';

  @override
  String get tagEditSaved => 'Tags salvas';

  @override
  String tagEditManySubtitle(String label, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count faixas',
      one: '1 faixa',
    );
    return '$label · $_temp0';
  }

  @override
  String tagEditManyReading(int done, int total) {
    return 'Lendo $done de $total…';
  }

  @override
  String tagEditManySaving(int done, int total) {
    return 'Salvando $done de $total…';
  }

  @override
  String get tagEditManyMixed =>
      'Variado — deixe em branco para manter o de cada faixa';

  @override
  String get tagEditManyMixedCovers => 'Capas diferentes';

  @override
  String get tagEditManyOneAtATime =>
      'Título e número da faixa são editados uma faixa por vez.';

  @override
  String tagEditManySkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count faixas não podem ser alteradas e ficarão como estão',
      one: '1 faixa não pode ser alterada e ficará como está',
    );
    return '$_temp0';
  }

  @override
  String get tagEditManySkippedFormat => 'Não é um arquivo MP3 ou FLAC';

  @override
  String get tagEditManySkippedUnsafe =>
      'As tags dela não podem ser alteradas com segurança';

  @override
  String tagEditManyPartly(int written, int failed) {
    String _temp0 = intl.Intl.pluralLogic(
      written,
      locale: localeName,
      other: '$written faixas',
      one: '1 faixa',
      zero: 'nenhuma faixa',
    );
    String _temp1 = intl.Intl.pluralLogic(
      failed,
      locale: localeName,
      other: '$failed não puderam ser alteradas:',
      one: '1 não pôde ser alterada:',
    );
    return 'Salvo em $_temp0. $_temp1';
  }

  @override
  String tagEditManySaved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tags salvas em $count faixas',
      one: 'Tags salvas em 1 faixa',
    );
    return '$_temp0';
  }

  @override
  String get tagEditManyTrackTotalLeft =>
      'O total de faixas dela ficou como estava: ela não tem número de faixa';

  @override
  String get tagEditManyDiscTotalLeft =>
      'O total de discos dela ficou como estava: ela não tem número de disco';

  @override
  String get musicGroupActions => 'Mais ações';

  @override
  String musicSelectionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selecionadas',
      one: '1 selecionada',
    );
    return '$_temp0';
  }

  @override
  String get musicSelectionAll => 'Selecionar tudo';

  @override
  String get musicSelectionStop => 'Parar de selecionar';

  @override
  String musicSelectionSelect(String title) {
    return 'Selecionar $title';
  }

  @override
  String musicSelectionEditTags(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Editar tags de $count faixas…',
      one: 'Editar tags de 1 faixa…',
    );
    return '$_temp0';
  }

  @override
  String get musicSelectionLabel => 'Faixas selecionadas';

  @override
  String get playlistTab => 'Playlists';

  @override
  String get playlistNew => 'Nova playlist';

  @override
  String get playlistNameLabel => 'Nome';

  @override
  String get playlistNameRequired => 'Dê um nome à playlist';

  @override
  String get playlistCreate => 'Criar';

  @override
  String playlistSongCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count faixas',
      one: '1 faixa',
      zero: 'Nenhuma faixa',
    );
    return '$_temp0';
  }

  @override
  String get playlistEmpty => 'Nenhuma playlist ainda';

  @override
  String get playlistActions => 'Ações da playlist';

  @override
  String get playlistBackToList => 'Todas as playlists';

  @override
  String get playlistCoverLabel => 'Capa da playlist';

  @override
  String get playlistRename => 'Renomear…';

  @override
  String get playlistRenameTitle => 'Renomear playlist';

  @override
  String get playlistRenameConfirm => 'Renomear';

  @override
  String get playlistChooseCover => 'Escolher capa…';

  @override
  String get playlistRemoveCover => 'Remover capa';

  @override
  String get playlistCoverNotImage =>
      'Escolha uma imagem JPEG ou PNG para a capa';

  @override
  String get playlistCoverTooLarge =>
      'Essa imagem tem mais de 20 MB, grande demais para um backup';

  @override
  String get playlistExport => 'Exportar para .m3u…';

  @override
  String playlistExportSaved(String path) {
    return 'Salvo em $path';
  }

  @override
  String get playlistExported => 'Playlist exportada';

  @override
  String playlistExportFailed(String name) {
    return 'Não foi possível exportar $name';
  }

  @override
  String get playlistDelete => 'Excluir…';

  @override
  String playlistDeleteTitle(String name) {
    return 'Excluir $name?';
  }

  @override
  String get playlistDeleteBody => 'As faixas continuam na sua biblioteca.';

  @override
  String get playlistDeleteConfirm => 'Excluir';

  @override
  String get playlistSaveFailed => 'Não foi possível salvar as playlists';

  @override
  String get playlistShuffle => 'Embaralhar';

  @override
  String playlistSummary(String songs, String length) {
    return '$songs · $length';
  }

  @override
  String get playlistNoSongs => 'Nenhuma faixa nesta playlist ainda';

  @override
  String get playlistMissing => 'Não encontrada';

  @override
  String playlistMissingBy(String artist) {
    return 'Não encontrada · $artist';
  }

  @override
  String get playlistRemoveFrom => 'Remover da playlist';

  @override
  String get playlistReorder => 'Arraste para reordenar';

  @override
  String get playlistAddTo => 'Adicionar à playlist…';

  @override
  String get playlistAddToTitle => 'Adicionar à playlist';

  @override
  String get playlistAddToNew => 'Nova playlist…';

  @override
  String playlistAdded(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count faixas adicionadas a $name',
      one: '1 faixa adicionada a $name',
    );
    return '$_temp0';
  }

  @override
  String get playlistNothingAdded => 'Nada foi adicionado';

  @override
  String playlistDuplicateTitle(String name) {
    return 'Já está em $name — adicionar de novo?';
  }

  @override
  String get playlistAddAnyway => 'Adicionar mesmo assim';

  @override
  String get playlistSkipThose => 'Pular essas';

  @override
  String get autoPlaylistSection => 'Playlists automáticas';

  @override
  String get autoPlaylistYours => 'Suas playlists';

  @override
  String get autoPlaylistLately => 'Favoritas do momento';

  @override
  String get autoPlaylistAllTime => 'Favoritas de todos os tempos';

  @override
  String get autoPlaylistFallbackNote => 'Conhecendo o que você tem ouvido';

  @override
  String get autoPlaylistLatelyEmpty =>
      'Ouça algumas músicas e suas favoritas do momento vão aparecer aqui';

  @override
  String get autoPlaylistAllTimeEmpty =>
      'Ouça algumas músicas e suas favoritas vão aparecer aqui';

  @override
  String get autoPlaylistShow => 'Mostrar playlists automáticas';

  @override
  String get autoPlaylistShowDetail =>
      'Favoritas do momento e Favoritas de todos os tempos, no topo de Playlists. O que você ouve continua sendo contado enquanto elas estão ocultas.';

  @override
  String get dataExportHeading => 'Seus dados';

  @override
  String get dataExportAction => 'Exportar meus dados (JSON)…';

  @override
  String dataExportSaved(String path) {
    return 'Exportado para $path';
  }

  @override
  String get dataExported => 'Exportado';

  @override
  String get dataExportPartial =>
      'Exportado, mas alguns dados não puderam ser lidos';

  @override
  String get dataExportFailed => 'Não foi possível exportar seus dados';

  @override
  String get dataExportLibraryFailed =>
      'Sua biblioteca não pôde ser lida, então não há nada para exportar';

  @override
  String get dataExportExplanation =>
      'Para ver seus dados em outras ferramentas ou importá-los em outro lugar.';

  @override
  String get backupAction => 'Fazer backup do Orpheus (ZIP)…';

  @override
  String get backupExplanation =>
      'Para restaurar o Orpheus neste ou em outro dispositivo: seus dados, capas de playlists e preferências.';

  @override
  String backupSaved(String path) {
    return 'Backup salvo em $path';
  }

  @override
  String get backedUp => 'Backup feito';

  @override
  String get backupPartial =>
      'Backup feito, mas alguns dados não puderam ser lidos';

  @override
  String get backupFailed => 'Não foi possível fazer o backup do Orpheus';

  @override
  String get backupLibraryFailed =>
      'Sua biblioteca não pôde ser lida, então não há nada para incluir no backup';

  @override
  String get backupAboutAction => 'Sobre estas exportações';

  @override
  String get backupAboutTitle => 'Sobre estas exportações';

  @override
  String get backupAboutColumnJson => 'Exportar meus dados (JSON)';

  @override
  String get backupAboutColumnZip => 'Fazer backup do Orpheus (ZIP)';

  @override
  String get backupAboutFor => 'Para';

  @override
  String get backupAboutForJson =>
      'Ver seus dados em outras ferramentas, importar em outro lugar';

  @override
  String get backupAboutForZip =>
      'Restaurar o Orpheus neste ou em outro dispositivo';

  @override
  String get backupAboutSongs => 'Músicas, artistas, álbuns (como lista)';

  @override
  String get backupAboutPlaylists => 'Playlists';

  @override
  String get backupAboutAutoPlaylists =>
      'Playlists automáticas (como estão agora)';

  @override
  String get backupAboutHistory => 'Histórico de reproduções e estatísticas';

  @override
  String get backupAboutCovers => 'Imagens de capa das playlists';

  @override
  String get backupAboutPreferences => 'Preferências (incl. pastas de música)';

  @override
  String get backupAboutMusicFiles => 'Seus arquivos de música';

  @override
  String get backupAboutIncluded => 'Incluído';

  @override
  String get backupAboutNotIncluded => 'Não incluído';

  @override
  String get restoreAction => 'Restaurar de um backup…';

  @override
  String get restoreExplanation =>
      'Traga de volta playlists, histórico de reproduções e preferências de um backup ZIP ou de um JSON exportado.';

  @override
  String get restoreTitle => 'Restaurar de um backup';

  @override
  String get restoreFailedNotABackup =>
      'Este arquivo não é um backup do Orpheus';

  @override
  String get restoreFailedNewer =>
      'Este backup é de uma versão mais nova do Orpheus — atualize primeiro';

  @override
  String get restoreFailedUnexpected =>
      'Algo deu errado ao preparar a restauração. Nada foi restaurado.';

  @override
  String get restoreFoldersTitle => 'Sua música';

  @override
  String get restoreFoldersIntro =>
      'As músicas de um backup são comparadas com a sua biblioteca, então sua música precisa estar onde o Orpheus a procura.';

  @override
  String get restoreBackupFolders => 'Pastas no backup';

  @override
  String get restoreBackupFoldersNone => 'O backup não cita nenhuma pasta.';

  @override
  String get restoreFolderFound => 'Encontrada neste dispositivo';

  @override
  String get restoreFolderNotFound => 'Não encontrada';

  @override
  String get restoreDeviceFolders => 'Pastas de música neste dispositivo';

  @override
  String get restoreDeviceFoldersNone => 'Nenhuma ainda';

  @override
  String get restoreFoldersStaged => 'Muda quando você continuar';

  @override
  String restoreRemoveFolder(String folder) {
    return 'Remover $folder';
  }

  @override
  String get restoreChooseFolders => 'Escolher pastas…';

  @override
  String get restoreFoldersNote =>
      'Continuar muda suas pastas de música agora e examina sua biblioteca. Se você cancelar depois, as pastas ficam como você as definiu.';

  @override
  String get restoreContinue => 'Continuar';

  @override
  String get restoreScanning => 'Examinando sua música…';

  @override
  String get restoreChoicesTitle => 'O que restaurar';

  @override
  String restoreBackupFrom(String date) {
    return 'Backup de $date';
  }

  @override
  String get restoreBackupUndated => 'Backup';

  @override
  String restoreHoldsPlaylists(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count playlists',
      one: '1 playlist',
    );
    return '$_temp0';
  }

  @override
  String restoreHoldsSongs(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count faixas com reproduções',
      one: '1 faixa com reproduções',
    );
    return '$_temp0';
  }

  @override
  String restoreHoldsCovers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count capas de playlist',
      one: '1 capa de playlist',
      zero: 'Nenhuma capa de playlist',
    );
    return '$_temp0';
  }

  @override
  String get restoreHoldsPreferences => 'Preferências incluídas';

  @override
  String get restoreHoldsNoPreferences => 'Sem preferências';

  @override
  String get restorePartPlaylists => 'Playlists';

  @override
  String get restorePartHistory => 'Histórico de reproduções';

  @override
  String get restorePartPreferences => 'Preferências';

  @override
  String get restoreMerge => 'Mesclar';

  @override
  String get restoreSkip => 'Ignorar';

  @override
  String get restoreReplace => 'Substituir';

  @override
  String get restorePlaylistsMerge =>
      'Adiciona as playlists do backup que não existem aqui e as faixas que as suas de mesmo nome não têm.';

  @override
  String get restorePlaylistsSkip =>
      'Adiciona só as playlists do backup cujo nome não existe aqui.';

  @override
  String get restorePlaylistsReplace =>
      'Remove suas playlists e usa as do backup, com as capas.';

  @override
  String get restoreHistoryMerge =>
      'Mantém a maior contagem e a data mais recente de cada faixa, e adiciona o restante.';

  @override
  String get restoreHistorySkip =>
      'Adiciona só as faixas sem histórico de reproduções aqui.';

  @override
  String get restoreHistoryReplace =>
      'Troca o seu histórico de reproduções pelo do backup.';

  @override
  String get restorePreferencesMerge =>
      'Aplica as configurações do backup só onde as suas ainda são as padrão.';

  @override
  String get restorePreferencesSkip =>
      'Não muda nenhuma das suas configurações.';

  @override
  String get restorePreferencesReplace =>
      'Aplica todas as configurações do backup, inclusive volume e idioma.';

  @override
  String get restoreNotInBackup => 'Não está neste backup';

  @override
  String get restoreNotInFile => 'Não está neste arquivo';

  @override
  String restoreReplacePlaylists(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Substitui as suas $count playlists',
      one: 'Substitui a sua 1 playlist',
      zero: 'Você não tem playlists para substituir',
    );
    return '$_temp0';
  }

  @override
  String restoreReplaceHistory(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Substitui as contagens de $count faixas',
      one: 'Substitui as contagens de 1 faixa',
      zero: 'Você não tem contagens para substituir',
    );
    return '$_temp0';
  }

  @override
  String get restoreReplacePreferences =>
      'Substitui todas as suas configurações pelas do backup';

  @override
  String get restoreUnreadablePlaylists =>
      'Não foi possível ler as suas playlists aqui, então esta parte não será restaurada.';

  @override
  String get restoreUnreadableHistory =>
      'Não foi possível ler o seu histórico de reproduções aqui, então esta parte não será restaurada.';

  @override
  String get restoreScanFailed =>
      'Não foi possível examinar sua música, então algumas faixas do backup podem não ser encontradas na sua biblioteca.';

  @override
  String get restoreFoldersKept =>
      'Suas pastas de música foram mudadas na etapa anterior. Cancelar mantém as pastas como estão agora.';

  @override
  String get restoreFoldersKeptFailed =>
      'Suas pastas de música foram mudadas na etapa anterior e continuam como estão agora.';

  @override
  String get restoreRestore => 'Restaurar';

  @override
  String get restoreRestoring => 'Restaurando…';

  @override
  String get restoreDoneTitle => 'Restauração concluída';

  @override
  String get restoreDoneRestored => 'Restaurado';

  @override
  String get restoreDoneRefused => 'Não foi possível restaurar';

  @override
  String restoreDonePlaylists(int added, int merged) {
    return 'Playlists: $added adicionadas, $merged mescladas';
  }

  @override
  String restoreDonePlaylistsReplaced(int replaced, int added) {
    String _temp0 = intl.Intl.pluralLogic(
      replaced,
      locale: localeName,
      other: 'as suas $replaced playlists foram trocadas',
      one: 'a sua playlist foi trocada',
    );
    return 'Playlists: $_temp0 por $added do backup';
  }

  @override
  String get restoreDonePlaylistsNothing => 'Playlists: nada a adicionar';

  @override
  String restoreDoneHistory(int songs) {
    String _temp0 = intl.Intl.pluralLogic(
      songs,
      locale: localeName,
      other: '$songs faixas',
      one: '1 faixa',
    );
    return 'Histórico de reproduções de $_temp0';
  }

  @override
  String restoreDoneHistoryMissing(int songs, int missing) {
    String _temp0 = intl.Intl.pluralLogic(
      songs,
      locale: localeName,
      other: '$songs faixas',
      one: '1 faixa',
    );
    return 'Histórico de reproduções de $_temp0 ($missing fora da sua biblioteca)';
  }

  @override
  String get restoreDoneHistoryNothing =>
      'Histórico de reproduções: nenhuma faixa a adicionar';

  @override
  String get restoreDonePreferences => 'Preferências aplicadas';

  @override
  String get restoreDonePreferencesNone => 'Preferências: nada a mudar';

  @override
  String get restoreDonePreferencesUnsaved =>
      'Algumas preferências não puderam ser salvas e valem só até o Orpheus fechar';

  @override
  String restoreDoneCoverFailures(String names) {
    return 'Estas playlists voltaram, mas as capas não puderam ser salvas: $names';
  }

  @override
  String restoreRefusedLine(String part, String reason) {
    return '$part: $reason';
  }

  @override
  String get restoreReasonNotInBackup =>
      'o backup não conseguiu ler esta parte quando foi feito';

  @override
  String get restoreReasonNotInFile => 'este arquivo não tem esta parte';

  @override
  String get restoreReasonUnreadableHere =>
      'esta parte não pôde ser lida aqui, então foi deixada como estava';

  @override
  String get restoreReasonNotWritten =>
      'esta parte não pôde ser salva, então nada dela mudou';

  @override
  String get restoreFoldersAllRemoved =>
      'Todas as suas pastas de música serão removidas, então nenhuma faixa poderá ser reconhecida.';

  @override
  String restoreDoneSkipped(String part) {
    return '$part: você escolheu ignorar';
  }

  @override
  String restoreDonePlaylistsEmptied(int replaced) {
    String _temp0 = intl.Intl.pluralLogic(
      replaced,
      locale: localeName,
      other: 'as suas $replaced playlists foram removidas',
      one: 'a sua playlist foi removida',
    );
    return 'Playlists: $_temp0; o backup não tinha nenhuma';
  }

  @override
  String get restoreDoneHistoryEmptied =>
      'Histórico de reproduções substituído; o backup não tinha reproduções';
}
