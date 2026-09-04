import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:logging/logging.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:path/path.dart' as p;

import '../domain/track_analysis.dart';
import '../domain/track_energy.dart';
import 'wav_samples.dart';

/// [TrackAnalysis] that decodes the track with libmpv and transforms it here.
///
/// The engine this application already plays with can also be told to write
/// what it decodes to a file instead of to a sound card, as fast as it can
/// decode it. That is the whole trick, and it is what makes the bars show the
/// music on all three platforms without a second codec library, a native
/// build, or a format this cannot read: whatever plays can be analysed,
/// because it is the same decoder doing both.
///
/// So: a player of its own, pointed at a scratch file, asked for one channel
/// at a low rate — a spectrum for a row of sixteen bars needs nothing near CD
/// quality, and the rate chosen is what keeps a four-minute track under ten
/// megabytes of scratch and a second or so of work. The transform then runs on
/// an isolate, and the scratch file is deleted whichever way it ends.
class MpvTrackAnalysis implements TrackAnalysis {
  /// Creates an analysis writing its scratch files under [scratchDirectory].
  MpvTrackAnalysis({
    required this.scratchDirectory,
    this.timeout = const Duration(minutes: 5),
  });

  /// What the decoder is asked for.
  ///
  /// Sixteen thousand samples a second, mono, sixteen bits. It bounds the
  /// spectrum at 8 kHz, which is above the top band the bars draw, and it is
  /// an eighth of the bytes a stereo CD-rate dump of the same track would be.
  static const int sampleRate = 16000;

  static final Logger _log = Logger('playback');

  /// Where the decoded scratch files are written.
  final String scratchDirectory;

  /// How long a single track's decode is allowed to take before it is
  /// abandoned.
  ///
  /// Generous, because it covers a whole album on one file over a slow disk,
  /// and bounded at all because a decode that never finishes would otherwise
  /// hold its player and its scratch file for the life of the process.
  final Duration timeout;

  /// What the analyses are queued behind each other on.
  Future<void> _queue = Future<void>.value();

  /// Whether the scratch directory has been swept this run.
  bool _swept = false;

  @override
  Future<MeasuredEnergy?> of(String path) {
    // One at a time. An owner skipping through a queue asks for an analysis a
    // second, and each one is a decoder instance, a core and a scratch file
    // the size of the track — run at once they would fight each other for all
    // three while the music they are analysing plays.
    final work = _queue.then((_) => _analyse(path));
    _queue = work.then((_) {}, onError: (_) {});

    return work;
  }

  /// Decodes and transforms the track at [path].
  Future<MeasuredEnergy?> _analyse(String path) async {
    final scratch = p.join(
      scratchDirectory,
      'analysis-$pid-${DateTime.now().microsecondsSinceEpoch}.wav',
    );

    try {
      await Directory(scratchDirectory).create(recursive: true);
      await _sweep();
      if (!await _decode(source: path, destination: scratch)) return null;

      // On an isolate: the transform is a few seconds of arithmetic over
      // millions of samples, and run here it would hold the frame for all of
      // it while the music it is analysing plays.
      return await Isolate.run(() => analyseWavFile(scratch));
    } on Object catch (error) {
      // Nothing an owner can act on: the bars fall back to the stand-in, and
      // the reason belongs in the log rather than on the screen.
      _log.warning('could not analyse $path', error);

      return null;
    } finally {
      await _discard(scratch);
    }
  }

  /// Decodes [source] to a mono WAV at [destination], answering whether it
  /// worked.
  Future<bool> _decode({
    required String source,
    required String destination,
  }) async {
    mk.MediaKit.ensureInitialized();

    final player = mk.Player(
      configuration: const mk.PlayerConfiguration(
        // Named apart from the playing engine, which is what a volume mixer
        // showing two entries for this application would otherwise be.
        title: 'orpheus (analysis)',
      ),
    );

    final finished = Completer<bool>();
    final subscriptions = <StreamSubscription<Object?>>[];

    try {
      final engine = player.platform;
      if (engine is! mk.NativePlayer) return false;

      // Set before anything is opened. mpv builds its audio output when it
      // loads a file, so a file loaded first would be played out loud through
      // the machine's speakers on top of whatever is already playing.
      await engine.setProperty('ao', 'pcm');
      await engine.setProperty('ao-pcm-file', destination);
      await engine.setProperty('ao-pcm-waveheader', 'yes');
      await engine.setProperty('audio-samplerate', '$sampleRate');
      await engine.setProperty('audio-channels', 'mono');
      await engine.setProperty('audio-format', 's16');
      // What makes this a decode rather than a playback: with the output
      // untimed, mpv writes each block as soon as it has it instead of at the
      // rate a listener would hear it, and a four-minute track takes about a
      // second instead of four minutes.
      await engine.setProperty('untimed', 'yes');
      await engine.setProperty('video', 'no');

      subscriptions.addAll([
        player.stream.completed.listen((completed) {
          if (completed && !finished.isCompleted) finished.complete(true);
        }),
        player.stream.error.listen((error) {
          _log.fine('analysis decode of $source failed: $error');
          if (!finished.isCompleted) finished.complete(false);
        }),
      ]);

      await player.open(mk.Media(source));

      if (!await finished.future.timeout(timeout, onTimeout: () => false)) {
        return false;
      }
    } on Object catch (error) {
      _log.warning('could not decode $source for analysis', error);

      return false;
    } finally {
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
      // Disposed before the file is read, and awaited: the samples are still
      // in mpv's output buffer until it shuts down, and the header is only
      // patched with the real length when the file is closed.
      await player.dispose();
    }

    return File(destination).existsSync();
  }

  /// Removes the scratch files an earlier run left behind, once per run.
  ///
  /// Every analysis deletes its own, so the only ones here are from a process
  /// that was killed mid-decode — and one of those is the size of the track it
  /// was reading, which is not something to leave in an owner's data directory
  /// until they find it.
  Future<void> _sweep() async {
    if (_swept) return;
    _swept = true;

    try {
      await for (final entry in Directory(scratchDirectory).list()) {
        final name = p.basename(entry.path);
        if (entry is File &&
            name.startsWith('analysis-') &&
            name.endsWith('.wav')) {
          await entry.delete();
        }
      }
    } on Object catch (error) {
      _log.fine('could not sweep $scratchDirectory', error);
    }
  }

  /// Removes [scratch], and says nothing if it was not there.
  Future<void> _discard(String scratch) async {
    try {
      final file = File(scratch);
      if (file.existsSync()) await file.delete();
    } on Object catch (error) {
      _log.fine('could not remove the scratch file $scratch', error);
    }
  }
}
