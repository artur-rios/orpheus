import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../../../core/platform/host_platform.dart';
import '../domain/story_share.dart';

/// [StoryShare] over the platform's own share sheet or save dialog.
///
/// Two behaviours behind one interface, chosen by host and not by a flag the
/// caller passes: the screen asks to send the picture, and what that means is
/// this file's business.
class PlatformStoryShare implements StoryShare {
  /// Creates the sender.
  const PlatformStoryShare({
    this._platform = const HostPlatform(),
    this._scratchDirectory,
  });

  static final Logger _log = Logger('stats');

  final HostPlatform _platform;
  final String? _scratchDirectory;

  @override
  bool get sharesToApps => !_platform.isDesktop;

  @override
  Future<StoryShareOutcome> send(
    Uint8List png, {
    required String fileName,
    required String text,
  }) async => sharesToApps
      ? _shareFile(png, fileName: fileName, text: text)
      : _saveFile(png, fileName: fileName);

  /// Hands the picture to the platform's share sheet.
  ///
  /// The sheet takes a file rather than bytes, so one is written first — to a
  /// temporary directory, because what the owner keeps is whatever the
  /// application they choose keeps. Nothing here writes into their pictures
  /// without being asked.
  Future<StoryShareOutcome> _shareFile(
    Uint8List png, {
    required String fileName,
    required String text,
  }) async {
    try {
      final directory = _scratchDirectory ?? Directory.systemTemp.path;
      final file = File(p.join(directory, fileName));
      await file.writeAsBytes(png, flush: true);

      final result = await SharePlus.instance.share(
        ShareParams(
          text: text,
          files: [XFile(file.path, mimeType: 'image/png')],
        ),
      );

      return result.status == ShareResultStatus.dismissed
          ? StoryShareOutcome.cancelled
          : StoryShareOutcome.shared;
    } on Object catch (error) {
      _log.warning('the story could not be shared', error);

      return StoryShareOutcome.failed;
    }
  }

  /// Asks the owner where to put the picture, and puts it there.
  Future<StoryShareOutcome> _saveFile(
    Uint8List png, {
    required String fileName,
  }) async {
    try {
      final saved = await FilePicker.saveFile(
        fileName: fileName,
        bytes: png,
        mimeType: 'image/png',
        type: FileType.image,
      );

      return saved == null
          ? StoryShareOutcome.cancelled
          : StoryShareOutcome.saved;
    } on Object catch (error) {
      _log.warning('the story could not be saved', error);

      return StoryShareOutcome.failed;
    }
  }
}
