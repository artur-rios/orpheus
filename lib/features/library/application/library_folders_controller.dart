import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

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
  ///
  /// "Already registered" by what the folder *is*, not how it was spelled —
  /// see [addAll], which this is the one-folder case of.
  Future<bool> add(String folder) => addAll([folder]);

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
  ///
  /// Each folder is stored normalised — `C:\Music\` as `C:\Music` — and
  /// skipped where it is a folder already registered, or one earlier in
  /// [folders], under another spelling. Compared as strings, `C:\Music` and
  /// `C:\Music\` were two folders, as were `c:\music` and `C:\Music` on a
  /// file system that does not care about case, and Android's `/sdcard/Music`
  /// and the `/storage/emulated/0/Music` it links to. Every one of those pairs
  /// was a library scanned twice over, listing every track on it twice.
  Future<bool> addAll(Iterable<String> folders) async {
    final paths = _pathsOnThisHost();
    final known = {
      for (final folder in state) await _identityOf(folder, paths),
    };

    final added = <String>[];
    for (final folder in folders) {
      final normalised = paths.normalize(folder);
      if (known.add(await _identityOf(normalised, paths))) {
        added.add(normalised);
      }
    }
    if (added.isEmpty) return false;

    await _write([...state, ...added]);

    return true;
  }

  /// The path rules of the machine the folders are on.
  ///
  /// Taken from [hostPlatformProvider] rather than from whatever `path` guesses
  /// for the process, so that which separators and which case count is a
  /// question a test can answer for Windows on any machine.
  p.Context _pathsOnThisHost() => p.Context(
    style: ref.read(hostPlatformProvider).isWindows
        ? p.Style.windows
        : p.Style.posix,
  );

  /// What [folder] is, as opposed to how it was written.
  ///
  /// The folder a link leads to where it can be followed — which is what
  /// makes `/sdcard/Music` and `/storage/emulated/0/Music` one folder — and
  /// the folder as written where it cannot: one that is not there, or not
  /// there yet, is still a folder the owner may register, and the spelling is
  /// all there is to compare it by. Folded to one case on Windows, whose file
  /// systems do not tell `Music` from `music`.
  Future<String> _identityOf(String folder, p.Context paths) async {
    var resolved = folder;
    try {
      resolved = await Directory(folder).resolveSymbolicLinks();
    } on Object {
      // Not there, or not readable: the spelling will have to do.
    }

    final normalised = paths.normalize(resolved);

    return paths.style == p.Style.windows
        ? normalised.toLowerCase()
        : normalised;
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

  /// Asks to be allowed to change the owner's audio files.
  ///
  /// Not recorded in [state], which is about reading: a refusal to let tags be
  /// written says nothing about whether the library can be scanned.
  Future<LibraryAccessDecision> ensureWritable() =>
      ref.read(libraryAccessProvider).requestWrite();

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
