import 'dart:async';

import 'package:orpheus/features/playback/domain/media_player.dart';

/// A [MediaPlayer] that records what it was asked to do and reports whatever
/// the test tells it to.
///
/// The engine is a native library that cannot run in a widget test, which is
/// the whole reason `MediaPlayer` is an interface: every flow above that line
/// is testable because this class can stand in for libmpv.
class FakeMediaPlayer implements MediaPlayer {
  final _statuses = StreamController<PlaybackStatus>.broadcast();

  /// The paths opened, in order.
  final List<String> opened = [];

  /// The offsets each `open` was asked to start at.
  final List<Duration> startedAt = [];

  /// Where `seek` was asked to move to.
  final List<Duration> seeks = [];

  /// The levels `setVolume` was asked for.
  final List<double> volumes = [];

  /// How many times playback was stopped.
  int stops = 0;

  /// How many times it was paused, and resumed.
  int pauses = 0;

  /// See [pauses].
  int plays = 0;

  PlaybackStatus _status = const PlaybackStatus();

  @override
  Stream<PlaybackStatus> get status => _statuses.stream;

  @override
  PlaybackStatus get currentStatus => _status;

  /// Reports [status] as though the engine had.
  void report(PlaybackStatus status) {
    _status = status;
    _statuses.add(status);
  }

  @override
  Future<void> open(String path, {Duration startAt = Duration.zero}) async {
    opened.add(path);
    startedAt.add(startAt);
    _status = PlaybackStatus(isPlaying: true, position: startAt);
  }

  // Announced, not just recorded. media_kit reports playing and paused on its
  // own stream, and the player above it learns that a pause took effect from
  // there rather than from the call returning — so a fake that only recorded
  // it would leave every flow that reads back "is it playing" testing against
  // a state the real engine would have moved on from.
  @override
  Future<void> play() async {
    plays++;
    report(_status.copyWith(isPlaying: true));
  }

  @override
  Future<void> pause() async {
    pauses++;
    report(_status.copyWith(isPlaying: false));
  }

  @override
  Future<void> seek(Duration position) async {
    seeks.add(position);
    _status = _status.copyWith(position: position);
  }

  @override
  Future<void> stop() async {
    stops++;
    _status = const PlaybackStatus();
  }

  @override
  Future<void> setVolume(double volume) async => volumes.add(volume);

  @override
  Future<void> dispose() async => _statuses.close();
}
