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
  String failureFolderUnreadable(String path) {
    return 'Não foi possível ler esta pasta: $path';
  }

  @override
  String get failureCatalogUnavailable =>
      'Não foi possível ler a biblioteca do disco.';

  @override
  String get failurePermissionDenied =>
      'O Orpheus precisa de permissão para ler seus arquivos de áudio.';

  @override
  String get failurePermissionDeniedPermanently =>
      'A permissão para ler arquivos de áudio foi negada. Conceda-a nas configurações do sistema.';

  @override
  String failureTrackUnplayable(String path) {
    return 'Não foi possível reproduzir este arquivo: $path';
  }

  @override
  String get failureUnexpected => 'Algo deu errado.';
}
