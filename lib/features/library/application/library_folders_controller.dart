import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../../core/di/providers.dart';
import '../domain/library_access.dart';

/// The folders the library is built from.
///
/// The whole of what the owner configures about their library: which folders
/// hold their music. There is no per-folder state beyond membership — no
/// enabled flag, no per-folder scan — because a library is one thing, and a
/// folder that is in it or out of it is the only distinction that changes what
/// the owner sees.
class LibraryFoldersController extends Notifier<List<String>> {
  static final Logger _log = Logger('library');

  @override
  List<String> build() => ref.read(settingsStoreProvider).libraryFolders;

  /// Asks the owner for a folder and adds it.
  ///
  /// Answers whether anything was added, so the caller can decide whether a
  /// scan is owed: a dismissed dialog and a folder already registered are both
  /// "nothing changed", and re-scanning the whole library for either would be
  /// work nobody asked for.
  Future<bool> addByPicking() async {
    final picked = await ref.read(folderPickerProvider).pickFolder();
    if (picked == null) return false;

    return add(picked);
  }

  /// Adds [folder], unless it is already registered.
  Future<bool> add(String folder) async {
    if (state.contains(folder)) return false;

    await _write([...state, folder]);

    return true;
  }

  /// Removes [folder].
  ///
  /// The files under it stay on disk, untouched. This application never
  /// deletes anything the owner owns; removing a folder removes it from the
  /// library, and the next scan is what takes its tracks out of the catalog.
  Future<void> remove(String folder) async {
    if (!state.contains(folder)) return;

    await _write([
      for (final registered in state)
        if (registered != folder) registered,
    ]);
  }

  /// Adds every folder in [folders] that is not registered already.
  ///
  /// What the empty state's "add my music folder" button calls with the
  /// platform's conventional locations.
  Future<bool> addAll(Iterable<String> folders) async {
    final added = [
      for (final folder in folders)
        if (!state.contains(folder)) folder,
    ];
    if (added.isEmpty) return false;

    await _write([...state, ...added]);

    return true;
  }

  Future<void> _write(List<String> folders) async {
    state = folders;

    try {
      await ref.read(settingsStoreProvider).setLibraryFolders(folders);
    } on Object catch (error) {
      // The change applies for this session either way, which is the rule
      // every stored choice in this application follows. A folder list that
      // could not be written is a folder list the owner re-adds next launch —
      // worth logging, and not worth throwing out of a button's callback.
      _log.warning('the library folders could not be saved', error);
    }
  }
}

/// Whether the platform will let the application read the owner's files, as
/// last asked.
///
/// Held rather than asked at each call site because the answer is a dialog:
/// asking twice for the same scan would put two of them in front of the owner.
class LibraryAccessController extends Notifier<LibraryAccessDecision?> {
  @override
  LibraryAccessDecision? build() => null;

  /// Asks, and remembers the answer.
  Future<LibraryAccessDecision> ensure() async {
    final decision = await ref.read(libraryAccessProvider).request();
    state = decision;

    return decision;
  }

  /// Opens the system settings, where a permanent refusal can be undone.
  Future<void> openSettings() => ref.read(libraryAccessProvider).openSettings();
}

/// Whether the application may read a folder anywhere on the device.
///
/// A second question from [LibraryAccessController]'s and deliberately apart
/// from it, because it is asked at a different moment and for a different
/// reason. The audio permission is what every scan needs and is asked for on
/// the way into one. This is what a memory card or a drive plugged into the
/// phone needs, it is a settings screen rather than a dialog, and an owner who
/// keeps their music where Android expects it should never meet it — so it is
/// asked for only once a folder has actually turned out to be unreadable.
///
/// Asynchronous because the answer is: the platform is asked, and until it
/// replies there is nothing to say about a folder that has not failed yet.
class EveryFolderAccessController extends AsyncNotifier<bool> {
  @override
  Future<bool> build() => ref.read(libraryAccessProvider).readsEveryFolder();

  /// Asks for it, and remembers what came back.
  Future<bool> ask() async {
    final granted = await ref
        .read(libraryAccessProvider)
        .askToReadEveryFolder();
    state = AsyncData(granted);

    return granted;
  }
}
