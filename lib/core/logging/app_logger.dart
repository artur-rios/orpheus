import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

/// Where log records go.
///
/// One initialisation, called once from `main`, so that a record written by a
/// controller reaches the same place as one written by the scanner.
abstract final class AppLogger {
  /// Routes every record to the platform's developer log.
  ///
  /// [level] is the floor: in release the fine-grained records the scanner
  /// writes per file are noise, and in debug they are exactly what a scan that
  /// found nothing needs to be diagnosed with.
  static void initialize({Level? level}) {
    Logger.root.level = level ?? (kDebugMode ? Level.ALL : Level.INFO);
    Logger.root.onRecord.listen((record) {
      developer.log(
        record.message,
        time: record.time,
        level: record.level.value,
        name: record.loggerName,
        error: record.error,
        stackTrace: record.stackTrace,
      );
    });
  }
}
