import 'dart:typed_data';

import 'package:orpheus/features/library/domain/catalog_store.dart';
import 'package:orpheus/features/library/domain/cover_store.dart';
import 'package:orpheus/features/library/domain/library_access.dart';
import 'package:orpheus/features/library/domain/library_scan.dart';
import 'package:orpheus/features/library/domain/music_catalog.dart';
import 'package:orpheus/features/playback/domain/energy_store.dart';
import 'package:orpheus/features/playback/domain/track_analysis.dart';
import 'package:orpheus/features/playback/domain/track_energy.dart';
import 'package:orpheus/features/stats/domain/play_history.dart';

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

  /// Whether reading the catalog fails, for the flows that have to carry on
  /// without a library.
  bool failOnRead = false;

  @override
  Future<MusicCatalog> read() async {
    if (failOnRead) throw StateError('the catalog could not be read');

    return _catalog;
  }

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

/// A [PlayHistoryStore] that keeps the history in memory.
///
/// Bound by the harness for the same reason every other store is: a test that
/// wrote a play history would write into the developer's own
/// application-support folder and change their statistics.
class InMemoryPlayHistoryStore implements PlayHistoryStore {
  /// Creates a store over [history].
  InMemoryPlayHistoryStore([this.history = PlayHistory.empty]);

  /// What has been recorded.
  PlayHistory history;

  /// How many times the history was written.
  int writes = 0;

  @override
  Future<PlayHistory> read() async => history;

  @override
  Future<void> write(PlayHistory history) async {
    writes++;
    this.history = history;
  }
}

/// An [EnergyStore] in memory, so that no test writes an analysis to disk.
class InMemoryEnergyStore implements EnergyStore {
  final Map<String, MeasuredEnergy> _analyses = {};

  /// The ids written, in order — which is how a test asserts that an analysis
  /// was cached rather than thrown away.
  final List<String> written = [];

  /// Seeds [energy] as already analysed under [id].
  void seed(String id, MeasuredEnergy energy) => _analyses[id] = energy;

  @override
  Future<MeasuredEnergy?> read(String id) async => _analyses[id];

  @override
  Future<void> put(String id, MeasuredEnergy energy) async {
    _analyses[id] = energy;
    written.add(id);
  }

  @override
  Future<void> clear() async {
    _analyses.clear();
    written.clear();
  }
}

/// A [TrackAnalysis] that answers whatever the test told it to.
///
/// Nothing decodes in a test: the real one starts a libmpv instance, writes a
/// scratch file and runs a transform on an isolate, none of which belongs in a
/// widget test. Answering `null` — the "could not be analysed" case — is the
/// default, because that is the path every test that is not about the bars
/// should take.
class ScriptedTrackAnalysis implements TrackAnalysis {
  /// Creates an analysis answering [answers], by track path.
  ScriptedTrackAnalysis([Map<String, MeasuredEnergy>? answers])
    : _answers = answers ?? const {};

  final Map<String, MeasuredEnergy> _answers;

  /// The paths asked about, in order.
  final List<String> asked = [];

  @override
  Future<MeasuredEnergy?> of(String path) async {
    asked.add(path);

    return _answers[path];
  }
}
