import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../domain/music_catalog.dart';

/// The library, as every screen reads it.
///
/// Loaded from the catalog document rather than scanned: a scan opens and
/// parses every file the owner has, and doing that before the first screen
/// could be drawn would make every launch as slow as the first one. The scan
/// runs behind the interface and hands its result to [replaceWith].
///
/// Asynchronous because the read is: the whole point is that the application
/// draws a loading state and then a library, instead of a blank window.
class MusicLibraryController extends AsyncNotifier<MusicCatalog> {
  @override
  Future<MusicCatalog> build() => ref.read(catalogStoreProvider).read();

  /// Replaces the library with what a scan found.
  ///
  /// Called by the scan controller, which is also what writes [catalog] to
  /// disk — the two are one operation, and splitting the write out to here
  /// would mean a library on screen that the next launch does not have.
  void replaceWith(MusicCatalog catalog) => state = AsyncData(catalog);

  /// Empties the library, in memory and on disk.
  Future<void> clear() async {
    await ref.read(catalogStoreProvider).clear();
    state = AsyncData(MusicCatalog.empty);
  }
}
