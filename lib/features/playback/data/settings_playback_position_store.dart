import 'dart:convert';

import 'package:logging/logging.dart';

import '../../../core/settings/settings_store.dart';
import '../domain/playback_position_store.dart';

/// The resume positions, in the local settings store.
///
/// One key holding a map from path to position, for the same reason the
/// library folders are one key: the whole set is small, is read at once, and a
/// key per file would need its own index to enumerate.
class SettingsPlaybackPositionStore implements PlaybackPositionStore {
  /// Creates a store over [_settings], reading what is already there.
  SettingsPlaybackPositionStore(this._settings) {
    _positions.addAll(_read());
  }

  static final Logger _log = Logger('playback');

  /// The settings key the positions are stored under.
  static const String settingsKey = 'playbackPositions';

  /// How many resume points are kept.
  ///
  /// Bounded, because nothing else here ever removes one: a position is
  /// forgotten when its track plays to the end, and a listener who never
  /// finishes anything would otherwise grow this without limit. The oldest go
  /// first, which is the order they stop being worth resuming in.
  static const int limit = 512;

  final SettingsStore _settings;

  /// Held in memory as well as written, because a resume point is asked for
  /// every time a file is opened and decoding the whole map for one lookup
  /// would be work done on the interface's frame.
  final Map<String, PlaybackPosition> _positions = {};

  @override
  PlaybackPosition? positionFor(String path) => _positions[path];

  @override
  Future<void> record(PlaybackPosition position) {
    _positions[position.path] = position;
    _trim();

    return _write();
  }

  @override
  Future<void> forget(String path) {
    _positions.remove(path);

    return _write();
  }

  void _trim() {
    if (_positions.length <= limit) return;

    final oldest = _positions.values.toList()
      ..sort((a, b) => a.updatedAt.compareTo(b.updatedAt));

    for (final position in oldest.take(_positions.length - limit)) {
      _positions.remove(position.path);
    }
  }

  Map<String, PlaybackPosition> _read() {
    final stored = _settings.getString(settingsKey);
    if (stored == null) return const {};

    try {
      final decoded = jsonDecode(stored) as Map<String, dynamic>;

      return {
        for (final entry in decoded.entries)
          entry.key: _positionFrom(
            entry.key,
            entry.value as Map<String, dynamic>,
          ),
      };
    } on Object catch (error) {
      // Broad by intent, as everywhere a stored document is read: a resume
      // point nobody can decode is a resume point nobody has, and it must not
      // stop the application starting.
      _log.warning('the resume positions could not be read', error);

      return const {};
    }
  }

  static PlaybackPosition _positionFrom(String path, Map<String, dynamic> row) {
    final duration = row['durationMs'] as int?;

    return PlaybackPosition(
      path: path,
      position: Duration(milliseconds: row['positionMs'] as int),
      duration: duration == null ? null : Duration(milliseconds: duration),
      updatedAt: DateTime.parse(row['updatedAt'] as String),
    );
  }

  Future<void> _write() => _settings.setString(
    settingsKey,
    jsonEncode({
      for (final entry in _positions.entries)
        entry.key: {
          'positionMs': entry.value.position.inMilliseconds,
          if (entry.value.duration case final duration?)
            'durationMs': duration.inMilliseconds,
          'updatedAt': entry.value.updatedAt.toIso8601String(),
        },
    }),
  );
}
