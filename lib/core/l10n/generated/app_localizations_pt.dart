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
  String scanReport(int tracks, int added, int removed) {
    return '$tracks faixas — $added novas, $removed removidas.';
  }

  @override
  String scanUnreadable(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count arquivos tinham tags ilegíveis.',
      one: '1 arquivo tinha tags ilegíveis.',
    );
    return '$_temp0';
  }

  @override
  String scanUnreachable(String path) {
    return 'Esta pasta não estava lá: $path';
  }

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
    );
    return '$_temp0';
  }

  @override
  String statsUntaggedNote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count faixas tocadas não têm tag de artista, disco ou gênero, então elas são contadas nos totais acima mas não aparecem em nenhum ranking abaixo.',
      one: '1 faixa tocada não tem tag de artista, disco ou gênero, então ela é contada nos totais acima mas não aparece em nenhum ranking abaixo.',
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
}
