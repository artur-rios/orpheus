import 'dart:typed_data';

/// What became of a story card the owner asked to send somewhere.
enum StoryShareOutcome {
  /// Handed to whatever the owner picked.
  shared,

  /// Written to a file the owner chose.
  saved,

  /// The owner closed the sheet or the dialog without choosing.
  cancelled,

  /// It could not be done, and the owner is owed a word about it.
  failed,
}

/// Sends a rendered story card out of the application.
///
/// An interface because what it does is platform-shaped — a share sheet on a
/// phone, a save dialog on a desktop — and because a test must be able to ask
/// for one without a share sheet appearing over the suite.
abstract interface class StoryShare {
  /// Whether this host hands the picture to other applications.
  ///
  /// True on mobile, where sharing is the point and the file is a means to it.
  /// False on the desktops, where the owner wants the file: a list of
  /// applications that might accept a PNG is not an answer to "let me post
  /// this", and a file they can attach anywhere is.
  bool get sharesToApps;

  /// Sends [png], named [fileName], alongside [text] where the host uses it.
  Future<StoryShareOutcome> send(
    Uint8List png, {
    required String fileName,
    required String text,
  });
}
