import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/library/data/isolate_library_scanner.dart';
import 'package:orpheus/features/library/domain/library_scan.dart';
import 'package:orpheus/features/library/domain/music_catalog.dart';
import 'package:path/path.dart' as p;

/// The scanner as the application actually uses it — over a real isolate.
///
/// The only test in this suite that spawns one, and it is here for the one
/// thing the pure walk in `scan_worker_test.dart` cannot show: what the stream
/// does at its ends. A scan that produced the right catalog and then would not
/// let go of its subscription is a scan that works exactly once a session, and
/// nothing about the entries it found says so.
void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('orpheus-scan-');
    await File(p.join(root.path, 'zzz-1.flac')).writeAsBytes([0, 1, 2, 3]);
  });

  tearDown(() async {
    if (root.existsSync()) await root.delete(recursive: true);
  });

  /// One scan of the temporary library.
  Stream<ScanEvent> scanned() => const IsolateLibraryScanner().scan(
    folders: [root.path],
    previous: MusicCatalog.empty,
    coverDirectory: p.join(root.path, 'covers'),
  );

  test(
    'GivenAScanHasFinished_WhenItsSubscriptionIsCancelled_ThenTheCancelAnswers',
    () async {
      // What the scan controller does on its way into the *next* scan, and
      // what used to wedge it there for the rest of the session: the stream's
      // cancel handler closed the very controller whose done event cancelling
      // prevents, so `cancel` never completed and every scan after the first
      // sat at "scanning" having found nothing.
      final events = scanned();
      final finished = Completer<void>();
      final subscription = events.listen((event) {
        if (event is ScanCompleted && !finished.isCompleted) {
          finished.complete();
        }
      });

      await finished.future.timeout(const Duration(seconds: 30));

      await expectLater(
        subscription.cancel().timeout(const Duration(seconds: 5)),
        completes,
      );
    },
  );

  test(
    'GivenOneScanHasRun_WhenAnotherIsStarted_ThenItFindsTheLibraryToo',
    () async {
      Future<ScanReport> run() async {
        final reports = <ScanReport>[];
        final subscription = scanned().listen((event) {
          if (event is ScanCompleted) reports.add(event.report);
        });
        while (reports.isEmpty) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
        await subscription.cancel().timeout(const Duration(seconds: 5));

        return reports.single;
      }

      expect((await run()).tracks, 1);
      expect((await run()).tracks, 1);
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );
}
