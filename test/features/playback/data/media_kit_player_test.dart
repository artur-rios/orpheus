import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:orpheus/features/playback/data/media_kit_player.dart';
import 'package:orpheus/features/playback/domain/media_player.dart';
import 'package:path/path.dart' as p;

/// The engine against a real libmpv, where there is one to load.
///
/// Most of what this wraps is not something a test can run, and the rest of
/// the suite tests above it through a fake. What is tested here is the one
/// thing only libmpv can say: which files beside a track it reaches for on its
/// own, and whether doing so reads to the application as a track that would
/// not play. Skipped wherever libmpv is not found.
void main() {
  final libmpv = _libmpv();

  /// A second of a quiet sine, as a plain 16-bit mono WAV.
  Uint8List wav() {
    const rate = 8000;
    final data = ByteData(rate * 2);
    for (var frame = 0; frame < rate; frame++) {
      final value = 0.1 * math.sin(2 * math.pi * 440 * frame / rate);
      data.setInt16(frame * 2, (value * 32767).round(), Endian.little);
    }

    final head = ByteData(44);
    head.setUint32(0, 0x52494646, Endian.big); // 'RIFF'
    head.setUint32(4, 36 + data.lengthInBytes, Endian.little);
    head.setUint32(8, 0x57415645, Endian.big); // 'WAVE'
    head.setUint32(12, 0x666d7420, Endian.big); // 'fmt '
    head.setUint32(16, 16, Endian.little);
    head.setUint16(20, 1, Endian.little);
    head.setUint16(22, 1, Endian.little);
    head.setUint32(24, rate, Endian.little);
    head.setUint32(28, rate * 2, Endian.little);
    head.setUint16(32, 2, Endian.little);
    head.setUint16(34, 16, Endian.little);
    head.setUint32(36, 0x64617461, Endian.big); // 'data'
    head.setUint32(40, data.lengthInBytes, Endian.little);

    return Uint8List.fromList([
      ...head.buffer.asUint8List(),
      ...data.buffer.asUint8List(),
    ]);
  }

  late Directory folder;

  setUp(() {
    folder = Directory.systemTemp.createTempSync('orpheus_engine_');
  });

  tearDown(() {
    folder.deleteSync(recursive: true);
  });

  test(
    'GivenATrackWithLyricsBesideIt_WhenOpened_ThenItIsNotReportedUndecodable',
    () async {
      final track = File(p.join(folder.path, 'the land.wav'))
        ..writeAsBytesSync(wav());
      // What the lyrics panel saves after a lookup: the words, timed, under
      // the track's own name.
      File(p.join(folder.path, 'the land.lrc'))
          .writeAsStringSync('[00:00.10] This land is mine\n[00:00.90] \n');

      mk.MediaKit.ensureInitialized(libmpv: libmpv);
      final engine = mk.Player();
      // Silent: the test listens to the engine's reports, not to the track.
      await (engine.platform! as mk.NativePlayer).setProperty('ao', 'null');

      final player = MediaKitPlayer(engine);
      addTearDown(player.dispose);

      final statuses = <PlaybackStatus>[];
      final subscription = player.status.listen(statuses.add);
      addTearDown(subscription.cancel);

      await player.open(track.path);
      await player.play();
      await Future<void>.delayed(const Duration(seconds: 2));

      expect(statuses.where((status) => status.failedToDecode), isEmpty);
      expect(statuses.any((status) => status.hasEnded), isTrue);
    },
    skip: libmpv == null ? 'libmpv is not available here' : false,
  );
}

/// Where libmpv is on this machine, or `null` where it is not.
///
/// On Windows it ships beside the built runner rather than being installed, so
/// the build output is where a developer's copy is; elsewhere the system
/// library is found by name.
String? _libmpv() {
  if (Platform.isWindows) {
    for (final mode in const ['Debug', 'Release', 'Profile']) {
      final dll = p.join(
        'build',
        'windows',
        'x64',
        'runner',
        mode,
        'libmpv-2.dll',
      );
      if (File(dll).existsSync()) return p.absolute(dll);
    }

    return null;
  }

  if (Platform.isLinux) {
    for (final directory in const [
      '/usr/lib/x86_64-linux-gnu',
      '/usr/lib/aarch64-linux-gnu',
      '/usr/lib64',
      '/usr/lib',
    ]) {
      final library = p.join(directory, 'libmpv.so.2');
      if (File(library).existsSync()) return library;
    }
  }

  return null;
}
