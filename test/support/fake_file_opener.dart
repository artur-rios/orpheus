import 'dart:typed_data';

import 'package:orpheus/features/data_export/domain/file_opener.dart';

/// A [FileOpener] that hands over whatever the test set, without a dialog.
class FakeFileOpener implements FileOpener {
  /// The bytes of the file the owner will pick; `null` is a cancelled dialog.
  Uint8List? next;

  /// When set, [open] throws it instead of answering: a file that could not
  /// be read.
  Exception? failure;

  /// The extensions each dialog was opened for, in order.
  final List<List<String>> requests = [];

  @override
  Future<Uint8List?> open({required List<String> extensions}) async {
    requests.add(extensions);

    final error = failure;
    if (error != null) throw error;

    return next;
  }
}
