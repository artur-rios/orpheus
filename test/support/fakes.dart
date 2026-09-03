import 'dart:typed_data';

import 'package:orpheus/features/library/domain/catalog_store.dart';
import 'package:orpheus/features/library/domain/cover_store.dart';
import 'package:orpheus/features/library/domain/library_access.dart';
import 'package:orpheus/features/library/domain/library_scan.dart';
import 'package:orpheus/features/library/domain/music_catalog.dart';

/// A [CatalogStore] in memory, seeded with whatever the test wants the last
/// scan to have left behind.
class InMemoryCatalogStore implements CatalogStore {
  /// Creates a store holding [catalog].
  InMemoryCatalogStore([MusicCatalog? catalog])
    : _catalog = catalog ?? MusicCatalog.empty;

  MusicCatalog _catalog;

  /// The catalogs written, in order — which is how a test asserts that a scan
  /// persisted what it found.
  final List<MusicCatalog> written = [];

  @override
  Future<MusicCatalog> read() async => _catalog;

  @override
  Future<void> write(MusicCatalog catalog) async {
    _catalog = catalog;
    written.add(catalog);
  }

  @override
  Future<void> clear() async => _catalog = MusicCatalog.empty;
}

/// A [CoverStore] in memory.
class InMemoryCoverStore implements CoverStore {
  final Map<String, Uint8List> _pictures = {};

  /// Where each picture is to be told it is, by cover id.
  ///
  /// Empty by default, which is the truth about a store that holds its
  /// pictures in memory. A test that is about the sleeve on a lock screen
  /// writes into it, because that flow is entirely about a *path* being handed
  /// to the platform and there is otherwise none to hand.
  final Map<String, String> locations = {};

  @override
  Future<String> put(Uint8List bytes) async {
    final id = coverIdOf(bytes);
    _pictures[id] = bytes;

    return id;
  }

  @override
  Future<Uint8List?> read(String id) async => _pictures[id];

  @override
  Future<bool> contains(String id) async => _pictures.containsKey(id);

  @override
  Future<String?> locationOf(String id) async => locations[id];

  @override
  Future<void> clear() async => _pictures.clear();
}

/// A [LibraryScanner] that reports whatever the test scripted.
class ScriptedScanner implements LibraryScanner {
  /// Creates a scanner that emits [events] for every scan.
  ScriptedScanner(this.events);

  /// What each scan reports, in order.
  final List<ScanEvent> events;

  /// The folder lists each scan was asked for.
  final List<List<String>> requests = [];

  @override
  Stream<ScanEvent> scan({
    required List<String> folders,
    required MusicCatalog previous,
    required String coverDirectory,
  }) {
    requests.add(folders);

    return Stream.fromIterable(events);
  }
}

/// A [LibraryAccess] that answers what the test set.
class FakeLibraryAccess implements LibraryAccess {
  /// Creates a gate answering [decision].
  FakeLibraryAccess([this.decision = LibraryAccessDecision.granted]);

  /// What the owner will say.
  LibraryAccessDecision decision;

  /// How many times it was asked.
  int requests = 0;

  /// Whether the settings screen was opened.
  bool openedSettings = false;

  @override
  Future<LibraryAccessDecision> request() async {
    requests++;

    return decision;
  }

  @override
  Future<void> openSettings() async => openedSettings = true;
}

/// A [FolderPicker] that answers what the test set, without a dialog.
class FakeFolderPicker implements FolderPicker {
  /// Creates a picker answering [folder], or `null` for a dismissed dialog.
  FakeFolderPicker([this.folder]);

  /// What the owner will pick.
  String? folder;

  @override
  Future<String?> pickFolder() async => folder;
}
