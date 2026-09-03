import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../library/domain/audio_file.dart';
import '../../library/domain/music_catalog.dart';
import '../../library/domain/music_entry.dart';
import '../../library/domain/music_grouping.dart';
import '../../library/domain/track_metadata.dart';
import '../domain/media_player.dart';
import '../domain/playback_position_store.dart';
import '../domain/playback_queue.dart';

/// Where audio playback is.
enum AudioStage {
  /// Nothing is queued.
  idle,

  /// The queue is being built, or a track is being opened.
  starting,

  /// A track is open, whether running or paused.
  playing,

  /// A resume position exists for a single track and the owner has not
  /// answered yet.
  offeringResume,

  /// Nothing in the selection could be played.
  allFailed,
}

/// The player's state.
class AudioPlaybackState {
  /// Creates a state.
  const AudioPlaybackState({
    this.queue = PlaybackQueue.empty,
    this.stage = AudioStage.idle,
    this.status = const PlaybackStatus(),
    this.repeat = QueueRepeat.off,
    this.resumeFrom,
    this.lastSkipped,
  });

  /// What is queued and where playback is in it.
  final PlaybackQueue queue;

  /// Where the player is.
  final AudioStage stage;

  /// What the engine last reported.
  final PlaybackStatus status;

  /// What happens when the queue runs out.
  final QueueRepeat repeat;

  /// The position the owner is being offered.
  final Duration? resumeFrom;

  /// The track most recently skipped.
  ///
  /// Named rather than counted, because "one track was skipped" tells the
  /// owner nothing about which of their files to go and look at.
  final AudioFile? lastSkipped;

  /// The track playing now, or `null`.
  AudioFile? get current => queue.current;

  /// Whether anything is queued.
  bool get isActive => stage != AudioStage.idle;

  /// Whether the engine is running.
  bool get isPlaying => status.isPlaying;

  /// A copy with the given changes.
  ///
  /// [resumeFrom] and [lastSkipped] are cleared unless they are passed, which
  /// is deliberate: both describe a moment the owner is being told about, and
  /// a moment that carried itself forward through every subsequent state
  /// change would be a notice that never goes away.
  AudioPlaybackState copyWith({
    PlaybackQueue? queue,
    AudioStage? stage,
    PlaybackStatus? status,
    QueueRepeat? repeat,
    Duration? resumeFrom,
    AudioFile? lastSkipped,
  }) => AudioPlaybackState(
    queue: queue ?? this.queue,
    stage: stage ?? this.stage,
    status: status ?? this.status,
    repeat: repeat ?? this.repeat,
    resumeFrom: resumeFrom,
    lastSkipped: lastSkipped,
  );
}

/// What [AudioPlaybackController._playGrouped] gathers a queue for.
///
/// Not [QueueKind]: that type also has `track` and `playlist`, and
/// `_playGrouped` is never called for either — `playTrack` and
/// `playEverythingShuffled` build their queues directly. A two-value type
/// rules those arms out at the call site instead of leaving switch cases that
/// could never run.
enum _GroupKind {
  /// An album.
  album,

  /// An artist.
  artist,
}

/// The player.
///
/// It outlives the screen the owner started it from — which is why the queue
/// and the engine live here and the playback bar is only a view of them.
class AudioPlaybackController extends Notifier<AudioPlaybackState> {
  /// How often, at most, a resume position is written while playing.
  static const Duration positionWriteInterval = Duration(seconds: 5);

  /// How far into a track the previous-track button restarts it rather than
  /// stepping back.
  ///
  /// The behaviour every physical player has had: pressing back three seconds
  /// into a song goes to the one before it, and pressing back two minutes in
  /// starts this one again — which is what the owner means both times.
  static const Duration restartThreshold = Duration(seconds: 5);

  StreamSubscription<PlaybackStatus>? _statuses;
  DateTime _lastWrite = DateTime.fromMillisecondsSinceEpoch(0);

  /// Which run of [_openAt] is the current one.
  ///
  /// Every call takes the next number and abandons itself the moment a later
  /// call takes one, which settles two things at once. Two opens can overlap —
  /// the end of a track landing while the owner presses next, or next pressed
  /// twice — and both runs stepping the same queue is a player that jumps a
  /// track. And when the overlap is deliberate — a new album started while a
  /// track is still opening — the newest ask is the one the owner means, so it
  /// is the older run that gives way.
  int _openGeneration = 0;

  MediaPlayer get _player => ref.read(audioPlayerProvider);
  PlaybackPositionStore get _positions => ref.read(playbackPositionsProvider);

  @override
  AudioPlaybackState build() {
    ref.onDispose(() => unawaited(_statuses?.cancel()));

    return AudioPlaybackState(repeat: _storedRepeat());
  }

  /// Plays [file] on its own.
  ///
  /// A single track with a resume position asks before it starts. An album
  /// does not — the question is about one file, and an album is a sequence.
  Future<void> playTrack(AudioFile file) async {
    final resume = _positions.positionFor(file.path);
    if (resume != null && resume.position > Duration.zero) {
      state = AudioPlaybackState(
        queue: PlaybackQueue(tracks: [file], kind: QueueKind.track),
        stage: AudioStage.offeringResume,
        repeat: state.repeat,
        resumeFrom: resume.position,
      );

      return;
    }

    await _playQueue(
      PlaybackQueue(tracks: [file], kind: QueueKind.track),
      at: Duration.zero,
    );
  }

  /// Plays the album [file] belongs to.
  ///
  /// [shuffled] plays the same tracks in an order nobody chose: the record,
  /// out of order, which is the one thing a shuffle is for.
  Future<void> playAlbum(AudioFile file, {bool shuffled = false}) =>
      _playGrouped(file, _GroupKind.album, shuffled: shuffled);

  /// Plays everything by [file]'s artist.
  Future<void> playArtist(AudioFile file, {bool shuffled = false}) =>
      _playGrouped(file, _GroupKind.artist, shuffled: shuffled);

  /// Plays [tracks] in the order given, as the queue called [name].
  ///
  /// Nothing is gathered here: the order *is* what was handed over, and the
  /// library is never consulted to build the queue.
  Future<void> playAll({
    required String name,
    required List<AudioFile> tracks,
    bool shuffled = false,
  }) async {
    // Nothing was asked to play, which is not the everything-failed case —
    // there, tracks were tried and every one failed. Whatever is playing keeps
    // playing, and an empty queue never reaches `_openAt`, which would
    // otherwise leave the player parked in `starting` with nothing to open.
    if (tracks.isEmpty) return;

    await _playQueue(
      PlaybackQueue(
        tracks: shuffled ? _shuffled(tracks) : tracks,
        kind: QueueKind.playlist,
        label: name,
      ),
      at: Duration.zero,
    );
  }

  /// Plays the whole library in an order nobody chose.
  ///
  /// [label] is what the bar calls it, passed in because this is application
  /// code with no `AppLocalizations` to name anything, and a label written
  /// here would be in one language for every owner.
  ///
  /// Every track the library holds, not the view the owner is looking at:
  /// "shuffle everything" said while standing in one artist would otherwise
  /// mean something different from the same words said in Songs, and neither
  /// reading is written anywhere an owner could check.
  Future<void> playEverythingShuffled({required String label}) async {
    state = state.copyWith(stage: AudioStage.starting);

    final library = await _library();
    if (library == null) {
      state = const AudioPlaybackState(stage: AudioStage.allFailed);

      return;
    }
    if (library.isEmpty) {
      state = const AudioPlaybackState();

      return;
    }

    await playAll(
      name: label,
      tracks: [for (final entry in library.entries) entry.file],
      shuffled: true,
    );
  }

  /// Answers the resume offer by resuming where playback stopped.
  Future<void> resume() async {
    final at = state.resumeFrom;
    if (at == null) return;

    await _playQueue(state.queue, at: at);
  }

  /// Answers the resume offer by playing from the beginning.
  Future<void> startOver() async {
    final file = state.queue.current;
    if (file == null) return;

    await _positions.forget(file.path);
    await _playQueue(state.queue, at: Duration.zero);
  }

  /// Pauses or resumes.
  Future<void> togglePlaying() async {
    if (state.stage != AudioStage.playing) return;

    if (state.isPlaying) {
      await _player.pause();
      await _recordPosition(force: true);
    } else {
      await _player.play();
    }
  }

  /// Moves playback to [position] within the track playing.
  ///
  /// Bounded here rather than trusted from the caller: the slider on the
  /// player hands over a fraction of a duration the engine reported, and a
  /// duration that has since changed — a track that ended, a queue that moved
  /// on — would otherwise be a seek past the end of whatever is playing now.
  ///
  /// The resume position is written straight away. A seek is the owner saying
  /// where they are in the track, and a session that ended before the next
  /// periodic write would otherwise come back to where they were before it.
  Future<void> seekTo(Duration position) async {
    if (state.stage != AudioStage.playing) return;

    final duration = state.status.duration;
    final bounded = switch (position) {
      final at when at < Duration.zero => Duration.zero,
      final at when duration != null && at > duration => duration,
      final at => at,
    };

    await _player.seek(bounded);
    await _recordPosition(force: true);
  }

  /// Moves to the next track in the queue.
  ///
  /// At the end of a queue set to repeat, the next track is the first one.
  Future<void> next() async {
    if (state.queue.hasNext) {
      await _openAt(state.queue.index + 1);

      return;
    }

    if (state.repeat == QueueRepeat.off || state.queue.isEmpty) return;

    await _openAt(0);
  }

  /// Moves to the previous track, or restarts this one.
  ///
  /// Which of the two depends on how far in playback is — see
  /// [restartThreshold].
  Future<void> previous() async {
    if (state.stage != AudioStage.playing) return;

    if (state.status.position > restartThreshold || !state.queue.hasPrevious) {
      await seekTo(Duration.zero);

      return;
    }

    await _openAt(state.queue.index - 1);
  }

  /// Opens the track at [index] in the queue.
  ///
  /// What tapping a row in the queue area does. Out-of-range is ignored rather
  /// than clamped: the queue on screen and the queue in hand can differ by a
  /// frame, and jumping to "whichever track is nearest" is not what the owner
  /// pressed.
  Future<void> jumpTo(int index) async {
    if (index < 0 || index >= state.queue.tracks.length) return;

    await _openAt(index);
  }

  /// Steps the repeat mode on, and remembers it.
  Future<void> cycleRepeat() async {
    final mode = state.repeat.next;
    state = state.copyWith(
      repeat: mode,
      resumeFrom: state.resumeFrom,
      lastSkipped: state.lastSkipped,
    );

    await ref.read(settingsStoreProvider).setString(repeatSettingsKey, mode.name);
  }

  /// Sets the output level, 0 to 1, and remembers it.
  Future<void> setVolume(double volume) async {
    final level = volume.clamp(0.0, 1.0).toDouble();
    await _player.setVolume(level);
    await ref.read(settingsStoreProvider).setVolume(level);
  }

  /// Stops and clears the queue.
  Future<void> stop() async {
    // Any open still in flight gives way, as it does to a newer one. Without
    // this it would come back from its await after the queue was cleared and
    // set the player playing again — a stop the owner asked for, undone a
    // moment later by work that was already running.
    _openGeneration++;

    await _recordPosition(force: true);
    unawaited(_statuses?.cancel());
    _statuses = null;
    await _player.stop();
    state = AudioPlaybackState(repeat: state.repeat);
  }

  /// Clears the report of a skipped track once the owner has seen it.
  void acknowledgeSkip() => state = state.copyWith(
    resumeFrom: state.resumeFrom,
  );

  /// Clears the report that nothing in the selection could be played.
  ///
  /// The queue was already cleared when the report was raised; this is the
  /// owner saying they have read it. Without it the bar carries the message
  /// for the rest of the session.
  void acknowledgeAllFailed() =>
      state = AudioPlaybackState(repeat: state.repeat);

  /// The settings key the repeat mode is stored under.
  static const String repeatSettingsKey = 'repeatMode';

  QueueRepeat _storedRepeat() {
    final stored = ref.read(settingsStoreProvider).getString(repeatSettingsKey);
    for (final mode in QueueRepeat.values) {
      if (mode.name == stored) return mode;
    }

    return QueueRepeat.off;
  }

  /// The library, or `null` where it could not be read.
  Future<MusicCatalog?> _library() async {
    try {
      return await ref.read(musicLibraryControllerProvider.future);
    } on Object {
      return null;
    }
  }

  /// Builds and plays an album or artist queue.
  Future<void> _playGrouped(
    AudioFile file,
    _GroupKind kind, {
    bool shuffled = false,
  }) async {
    state = state.copyWith(stage: AudioStage.starting);

    final library = await _library();
    if (library == null) {
      // The library itself could not be read, so no album or artist grouping
      // is knowable — there is nothing this can queue. Reported through the
      // stage the bar already renders as "nothing in the selection could be
      // played" rather than left parked in `starting` forever: a queue built
      // by falling back to the single track the owner asked for would silently
      // turn "play the album" into "play the track" without ever saying so.
      //
      // `lastSkipped` stays null on purpose: nothing was attempted, so naming
      // [file] as skipped would claim a specific track failed to play, which
      // did not happen.
      state = const AudioPlaybackState(stage: AudioStage.allFailed);

      return;
    }

    final entries = library.entries;
    final entry =
        library.entryAt(file.path) ??
        MusicEntry(file: file, metadata: TrackMetadata.empty);

    final gathered = switch (kind) {
      _GroupKind.album => albumOf(entry, entries),
      _GroupKind.artist => artistOf(entry, entries),
    };
    final tracks = shuffled ? _shuffled(gathered) : gathered;

    // Never the file name: an absent tag is carried as `null` rather than
    // defaulting to the name on disk here, because this is application code
    // with no `AppLocalizations` to turn that absence into the right word.
    final label = switch (kind) {
      _GroupKind.album => entry.album,
      // The album artist, because `artistOf` gathered the queue by it: a label
      // naming the guest performer would title a queue of the host's whole
      // catalogue after one track's guest.
      _GroupKind.artist => entry.albumArtist,
    };

    // Starting where the owner started, not at the top: they picked this
    // track, and an album started from track seven begins at seven.
    //
    // Except when shuffled, which begins at the top of the order the shuffle
    // made: starting a shuffle at the track the owner happened to click would
    // make the first track the one predictable thing about it.
    final startIndex = shuffled
        ? 0
        : tracks.indexWhere((candidate) => candidate.path == file.path);

    await _playQueue(
      PlaybackQueue(
        tracks: tracks,
        kind: switch (kind) {
          _GroupKind.album => QueueKind.album,
          _GroupKind.artist => QueueKind.artist,
        },
        label: label,
        year: entry.metadata.year,
        index: startIndex < 0 ? 0 : startIndex,
      ),
      at: Duration.zero,
    );
  }

  /// The same tracks in an order nobody chose.
  ///
  /// A copy, never the list it was given: the caller's list is the library's
  /// own order, and shuffling it in place would reorder what every other
  /// reader of it sees.
  ///
  /// The source of randomness comes from a provider so a test can pin it. A
  /// shuffle nobody can reproduce is a shuffle nobody can test: with a seeded
  /// source, "these are the same tracks in a different order" is an assertion
  /// rather than a hope.
  List<AudioFile> _shuffled(List<AudioFile> tracks) =>
      [...tracks]..shuffle(ref.read(shuffleRandomProvider));

  /// Opens [queue] at its current index, [at] into the track.
  Future<void> _playQueue(PlaybackQueue queue, {required Duration at}) async {
    state = state.copyWith(queue: queue, stage: AudioStage.starting);
    _listenToEngine();
    await _player.setVolume(ref.read(settingsStoreProvider).volume);
    await _openAt(queue.index, at: at);
  }

  /// Opens the track at [index], skipping past anything that will not play.
  ///
  /// A file that is missing and a file the engine cannot decode are the same
  /// movement from the player's side — named, and stepped over — and the queue
  /// running out of tracks to try is what ends it.
  Future<void> _openAt(int index, {Duration at = Duration.zero}) async {
    final generation = ++_openGeneration;

    var queue = state.queue.copyWith(index: index);
    final probe = ref.read(trackProbeProvider);

    // Carried across the loop rather than read back out of the state: every
    // step of it replaces the state, and the owner is owed the name of the
    // file that was skipped even once the queue has moved past it.
    var skipped = state.lastSkipped;

    while (queue.current != null) {
      if (generation != _openGeneration) return;

      final file = queue.current!;
      state = state.copyWith(
        queue: queue,
        stage: AudioStage.starting,
        lastSkipped: skipped,
      );

      if (probe.exists(file.path)) {
        // [at] belongs to the track that was asked for, not to whichever one
        // the queue reached after stepping over the ones that would not open:
        // a resume offer is about one file, and carrying its offset onto a
        // different track would start that one part-way through for no reason
        // the owner could see.
        await _player.open(
          file.path,
          startAt: queue.index == index ? at : Duration.zero,
        );

        if (generation != _openGeneration) return;

        state = state.copyWith(
          queue: queue,
          stage: AudioStage.playing,
          status: _player.currentStatus,
          lastSkipped: skipped,
        );

        return;
      }

      // Named, stepped over, and the queue carries on.
      //
      // Why a track would not open is the same answer for every skip the queue
      // makes, so the bar names the file and says no more.
      queue = queue.skipping(file);
      skipped = file;
      state = state.copyWith(queue: queue, lastSkipped: skipped);

      if (!queue.hasNext) {
        // Nothing in the selection could be played. The queue is cleared,
        // because there is nothing left in it to come back to.
        state = AudioPlaybackState(
          stage: AudioStage.allFailed,
          repeat: state.repeat,
          lastSkipped: skipped,
        );

        return;
      }

      queue = queue.copyWith(index: queue.index + 1);
    }
  }

  /// Follows the engine, which is where a decode failure and the end of a
  /// track arrive from.
  void _listenToEngine() {
    unawaited(_statuses?.cancel());

    _statuses = _player.status.listen((status) async {
      if (status.failedToDecode) {
        final file = state.queue.current;
        if (file == null) return;

        final queue = state.queue.skipping(file);
        state = state.copyWith(queue: queue, lastSkipped: file);

        if (queue.hasNext) {
          await _openAt(queue.index + 1);
        } else {
          state = AudioPlaybackState(
            stage: AudioStage.allFailed,
            repeat: state.repeat,
            lastSkipped: file,
          );
        }

        return;
      }

      state = state.copyWith(status: status, lastSkipped: state.lastSkipped);

      if (status.hasEnded) {
        // A track played through leaves no position, and the queue moves on —
        // or repeats, or ends.
        unawaited(_forgetPosition());

        if (state.repeat == QueueRepeat.one) {
          await _openAt(state.queue.index);
        } else if (state.queue.hasNext) {
          await _openAt(state.queue.index + 1);
        } else if (state.repeat == QueueRepeat.all && !state.queue.isEmpty) {
          await _openAt(0);
        } else {
          state = AudioPlaybackState(repeat: state.repeat);
        }

        return;
      }

      unawaited(_recordPosition());
    });
  }

  Future<void> _forgetPosition() async {
    final file = state.queue.current;
    if (file == null) return;

    await _positions.forget(file.path);
  }

  /// Writes where playback is.
  Future<void> _recordPosition({bool force = false}) async {
    final file = state.queue.current;
    if (file == null || state.stage != AudioStage.playing) return;

    final position = state.status.position;
    if (position <= Duration.zero) return;

    final now = ref.read(clockProvider)();
    if (!force && now.difference(_lastWrite) < positionWriteInterval) return;
    _lastWrite = now;

    await _positions.record(
      PlaybackPosition(
        path: file.path,
        position: position,
        duration: state.status.duration,
        updatedAt: now,
      ),
    );
  }
}
