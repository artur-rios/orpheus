import 'music_catalog.dart';

/// Where the catalog is kept between runs.
///
/// A scan of a large library takes a while — it opens and parses every file —
/// and doing it before the first screen could be drawn would make every launch
/// as slow as the first. So the catalog is written once and read back at
/// startup, and the scan that keeps it current runs behind the interface.
abstract interface class CatalogStore {
  /// The catalog last written, or [MusicCatalog.empty] where there is none.
  ///
  /// Never throws for a document that will not parse: a catalog nobody can
  /// read is a library to rebuild, not a launch that fails.
  ///
  /// A document written by another version, or one that cannot be read at all,
  /// comes back empty and [MusicCatalog.isStale], which is what makes startup
  /// scan it and what an export or a backup reports as the library being
  /// rebuilt. Only a missing document is [MusicCatalog.empty] and not stale.
  Future<MusicCatalog> read();

  /// Writes [catalog] as the whole document.
  Future<void> write(MusicCatalog catalog);

  /// Removes the stored catalog.
  Future<void> clear();
}
