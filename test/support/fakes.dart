import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:orpheus/core/platform/host_platform.dart';
import 'package:orpheus/core/settings/in_memory_settings_store.dart';
import 'package:orpheus/features/library/domain/catalog_store.dart';
import 'package:orpheus/features/library/domain/cover_store.dart';
import 'package:orpheus/features/library/domain/library_access.dart';
import 'package:orpheus/features/library/domain/library_scan.dart';
import 'package:orpheus/features/library/domain/music_catalog.dart';
import 'package:orpheus/features/lyrics/domain/lyrics.dart';
import 'package:orpheus/features/lyrics/domain/lyrics_sidecar.dart';
import 'package:orpheus/features/lyrics/domain/lyrics_source.dart';
import 'package:orpheus/features/lyrics/domain/remote_lyrics_source.dart';
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

  /// Whether writing the catalog fails, for the flow that has to tell the
  /// owner their scan will have to run again.
  bool failOnWrite = false;

  /// Whether deleting the catalog fails, for the flow that has to empty the
  /// library on screen anyway.
  bool failOnClear = false;

  /// Replaces what a read will answer with, without recording a write.
  ///
  /// What a test uses to say "this is the document already on disk", which is
  /// a different thing from "this is what a scan wrote".
  void seed(MusicCatalog catalog) => _catalog = catalog;

  @override
  Future<MusicCatalog> read() async {
    if (failOnRead) throw StateError('the catalog could not be read');

    return _catalog;
  }

  @override
  Future<void> write(MusicCatalog catalog) async {
    if (failOnWrite) throw StateError('the catalog could not be written');

    _catalog = catalog;
    written.add(catalog);
  }

  @override
  Future<void> clear() async {
    if (failOnClear) throw StateError('the catalog could not be deleted');

    _catalog = MusicCatalog.empty;
  }
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

  /// The `unchangedSince` each scan was asked for, in order — which is how a
  /// test asserts that the startup scan asked for the cheap walk and the one
  /// the owner pressed did not.
  final List<DateTime?> unchangedSinces = [];

  @override
  Stream<ScanEvent> scan({
    required List<String> folders,
    required MusicCatalog previous,
    required String coverDirectory,
    DateTime? unchangedSince,
  }) {
    requests.add(folders);
    unchangedSinces.add(unchangedSince);

    return Stream.fromIterable(events);
  }
}

/// A [HostPlatform] that is whatever the test says it is.
///
/// Linux by default, which is the desktop the suite runs on and keeps every
/// test that is not about a platform reading exactly as it did. A test about
/// Android — a storage permission, a card mounted out of reach — asks for it.
class FakeHostPlatform implements HostPlatform {
  /// Creates a host reporting the platform the test names.
  const FakeHostPlatform({
    this.isAndroid = false,
    this.isWindows = false,
    this.isLinux = true,
    this.homeDirectory = '/home/test',
  });

  @override
  final bool isAndroid;

  @override
  final bool isWindows;

  @override
  final bool isLinux;

  @override
  final String? homeDirectory;

  @override
  bool get isDesktop => isWindows || isLinux;

  @override
  bool get needsStoragePermission => isAndroid;
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

  /// Whether the platform already lets every folder be read.
  ///
  /// True by default, which is what the two desktops answer and what keeps
  /// every test that is not about a memory card free of the question.
  bool readsEverything = true;

  /// What the owner will say to the all-files settings screen.
  bool grantsEverything = false;

  /// How many times that screen was asked for.
  int everyFolderRequests = 0;

  @override
  Future<LibraryAccessDecision> request() async {
    requests++;

    return decision;
  }

  @override
  Future<bool> readsEveryFolder() async => readsEverything;

  @override
  Future<bool> askToReadEveryFolder() async {
    everyFolderRequests++;
    readsEverything = grantsEverything;

    return grantsEverything;
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

  /// Whether storing an analysis fails, for the flow about a full disk or a
  /// cache directory that cannot be written.
  bool failOnPut = false;

  /// Seeds [energy] as already analysed under [id].
  void seed(String id, MeasuredEnergy energy) => _analyses[id] = energy;

  @override
  Future<MeasuredEnergy?> read(String id) async => _analyses[id];

  @override
  Future<void> put(String id, MeasuredEnergy energy) async {
    if (failOnPut) {
      throw const FileSystemException('the analysis could not be cached');
    }

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

/// A [LyricsSource] that answers whatever the test seeded, by track path.
///
/// Nothing on this path touches a disk in a widget test: the real source
/// probes for a sidecar and, failing that, parses the track's own header, and
/// a test about the player has no files for either. Answering `null` — the
/// "this machine holds no words for that track" case — is the default,
/// because it is the case most tracks in most libraries are in.
class ScriptedLyricsSource implements LyricsSource {
  /// Creates a source answering [lyrics], by track path.
  ScriptedLyricsSource([Map<String, Lyrics> lyrics = const {}])
    : _lyrics = {...lyrics};

  final Map<String, Lyrics> _lyrics;

  /// The tracks it was asked about, in order.
  final List<String> asked = [];

  /// Seeds [lyrics] as the words of the track at [path].
  void seed(String path, Lyrics lyrics) => _lyrics[path] = lyrics;

  @override
  Future<Lyrics?> of(String path) async {
    asked.add(path);

    return _lyrics[path];
  }
}

/// A [SettingsStore] that refuses to write.
///
/// The other half of the rule every preference in this application follows: a
/// choice applies for the session whether or not it could be saved, and the
/// owner is told when it could not. Without a store that can refuse, only the
/// happy half of that rule is ever exercised.
class UnwritableSettingsStore extends InMemorySettingsStore {
  /// Creates a store that throws from every write.
  UnwritableSettingsStore({super.libraryFolders});

  Never _refuse() => throw StateError('the preferences could not be written');

  @override
  Future<void> setThemeMode(ThemeMode mode) async => _refuse();

  @override
  Future<void> setLocale(Locale? locale) async => _refuse();

  @override
  Future<void> setLibraryFolders(List<String> folders) async => _refuse();

  @override
  Future<void> setOpensPlayerOnPlay(bool value) async => _refuse();

  @override
  Future<void> setRescansAtStartup(bool value) async => _refuse();

  @override
  Future<void> setFetchesLyricsOnline(bool value) async => _refuse();

  @override
  Future<void> setVolume(double value) async => _refuse();

  @override
  Future<void> setString(String key, String value) async => _refuse();
}

/// A [RemoteLyricsSource] that answers what a test told it to.
///
/// It records every query it was given, which is how the suite asserts the
/// half of this feature that is not about words at all: that nothing is asked
/// of a network for a track this machine already has words for, that nothing
/// is asked when the owner has turned the lookup off, and that what does get
/// asked is the artist and the title and not the path of a file.
class ScriptedRemoteLyricsSource implements RemoteLyricsSource {
  /// Creates a source answering [sheets], by track title.
  ScriptedRemoteLyricsSource([Map<String, RemoteLyrics> sheets = const {}])
    : _sheets = {...sheets};

  final Map<String, RemoteLyrics> _sheets;

  /// Every lookup made, in order.
  final List<LyricsQuery> asked = [];

  /// Whether the lookup fails outright rather than answering nothing.
  ///
  /// The difference matters: a service that is unreachable is not a service
  /// that said no, and the panel has to end up in the same place either way.
  bool fails = false;

  /// Seeds [sheet] as the answer for a track titled [title].
  void seed(String title, RemoteLyrics sheet) => _sheets[title] = sheet;

  @override
  Future<RemoteLyrics?> find(LyricsQuery query) async {
    asked.add(query);

    if (fails) throw StateError('the lyrics service could not be reached');

    return _sheets[query.title];
  }
}

/// A [LyricsSidecar] that records rather than writes.
///
/// No test in this suite puts a file in anybody's music folder — the same rule
/// every other store here follows. `FileLyricsSidecar` is exercised against a
/// temporary directory of its own, in its own test.
class RecordingLyricsSidecar implements LyricsSidecar {
  /// What was written, by track path.
  final Map<String, String> written = {};

  /// Whether the write is refused, as a read-only folder or Android's sandbox
  /// refuses it.
  bool refuses = false;

  @override
  Future<bool> write(String path, String text) async {
    if (refuses) return false;

    written[path] = text;

    return true;
  }
}
