/// Whether the application may read the owner's audio files.
///
/// An interface with two implementations for one reason: on Android this is a
/// system dialog the owner answers, and on the two desktops there is nothing
/// to ask. Behind a seam, the library controller has one flow rather than a
/// platform check in the middle of it.
abstract interface class LibraryAccess {
  /// Asks for read access, and answers what the owner said.
  ///
  /// Returns the same answer on a host that needs no permission: granted,
  /// immediately and without a dialog.
  Future<LibraryAccessDecision> request();

  /// Whether the platform will let this application read a folder anywhere on
  /// the device, rather than only the storage it hands out by default.
  ///
  /// The question a memory card or a drive plugged into the phone raises, and
  /// only there: Android mounts those outside the volume an application's
  /// audio permission covers, so a folder on one is a folder that does not
  /// exist as far as an ordinary read is concerned. Answers true on the two
  /// desktops, where a folder the owner pointed at is a folder this
  /// application may read.
  Future<bool> readsEveryFolder();

  /// Asks for that, and answers whether it was given.
  ///
  /// On Android this is not a dialog but a settings screen the owner is taken
  /// to and comes back from, which is why the answer arrives as a future
  /// rather than a decision made in place.
  Future<bool> askToReadEveryFolder();

  /// Opens the system settings where a permanently refused permission can be
  /// granted, where the platform offers such a screen.
  Future<void> openSettings();
}

/// What the owner said.
enum LibraryAccessDecision {
  /// The application may read audio files.
  granted,

  /// The owner refused, and can be asked again.
  denied,

  /// The owner refused in a way the system will not put to them again. The
  /// only way forward is the settings screen, which is why that is a separate
  /// answer rather than a second kind of "denied".
  deniedPermanently;

  /// Whether reading may proceed.
  bool get isGranted => this == LibraryAccessDecision.granted;
}

/// Picks a folder with the platform's own dialog.
///
/// Behind an interface because a native dialog cannot be opened in a widget
/// test, and "the owner added a folder" is a flow worth testing.
abstract interface class FolderPicker {
  /// Asks the owner for a folder, and answers its path — or `null` where they
  /// dismissed the dialog.
  Future<String?> pickFolder();
}
