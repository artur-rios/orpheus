import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

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
  static final Logger _log = Logger('library');

  /// The settings key the moment of the last scan is kept under.
  ///
  /// Beside the catalog rather than only inside it, and it is the cheap half of
  /// a deliberate trade. The document is rewritten only when a scan actually
  /// changed something — several megabytes of JSON is the most expensive thing
  /// a launch does, and for an unchanged library it would encode the file that
  /// is already there — but the *time* of the scan changes every time, and a
  /// scan that declined to write it left two things wrong: the folders screen
  /// showed the date of the last scan that happened to change something, and
  /// the cheap walk's `unchangedSince` cutoff never advanced, so every folder
  /// touched since then was stat'ed in full at every launch for good.
  ///
  /// One key holding one timestamp costs nothing to write and fixes both.
  static const String lastScanSettingsKey = 'lastScanAt';

  @override
  Future<MusicCatalog> build() async {
    final stored = await ref.read(catalogStoreProvider).read();
    final scannedAt = _laterOf(stored.scannedAt, _recordedScanTime());

    return scannedAt == stored.scannedAt
        ? stored
        : MusicCatalog(entries: stored.entries, scannedAt: scannedAt);
  }

  /// Replaces the library with what a scan found.
  ///
  /// Called by the scan controller, which is also what writes [catalog] to
  /// disk — the two are one operation, and splitting the write out to here
  /// would mean a library on screen that the next launch does not have.
  void replaceWith(MusicCatalog catalog) => state = AsyncData(catalog);

  /// Empties the library, in memory and on disk.
  ///
  /// The library empties on screen whether or not the document could be
  /// deleted — the same rule every other stored thing in this application
  /// follows, and the reason it matters here is that this is what removing the
  /// last folder calls. A delete that threw used to come back out of the
  /// button that started the scan, which is the one place a failed delete has
  /// no business appearing.
  Future<void> clear() async {
    try {
      await ref.read(catalogStoreProvider).clear();
    } on Object catch (error) {
      _log.warning('the catalog could not be deleted', error);
    }

    state = AsyncData(MusicCatalog.empty);
  }

  /// The moment the last scan ran, as the settings recorded it.
  ///
  /// Broad by intent, as everywhere a stored value is read back: a timestamp
  /// that will not parse is one this application does not have, and the answer
  /// to that is the document's own — never a launch that fails.
  DateTime? _recordedScanTime() {
    final stored = ref
        .read(settingsStoreProvider)
        .getString(lastScanSettingsKey);

    return stored == null ? null : DateTime.tryParse(stored);
  }

  /// The later of two moments, either of which may be absent.
  static DateTime? _laterOf(DateTime? left, DateTime? right) {
    if (left == null) return right;
    if (right == null) return left;

    return right.isAfter(left) ? right : left;
  }
}
