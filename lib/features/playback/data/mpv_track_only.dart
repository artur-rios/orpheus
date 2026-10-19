import 'package:media_kit/media_kit.dart' as mk;

/// Stops [player] reaching for files beside the one it is given.
///
/// mpv loads a subtitle named after the track on its own (`sub-auto`), and a
/// `.lrc` — which is exactly what the lyrics panel saves beside a track — is
/// one. The libmpv this application ships cannot open it and says so as an
/// error line, which media_kit forwards on its error stream: the same stream a
/// file that will not decode arrives on. Left alone, a track that played
/// yesterday is skipped as unplayable the first time it is opened after its
/// words were saved.
///
/// An audio player has no use for subtitles, so it is told not to look. Set
/// before anything is opened, because mpv decides what to load beside a file
/// as it loads it.
Future<void> keepToTheTrack(mk.Player player) async {
  final engine = player.platform;
  if (engine is! mk.NativePlayer) return;

  await engine.setProperty('sub-auto', 'no');
}
