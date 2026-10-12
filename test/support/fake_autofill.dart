import 'dart:typed_data';

import 'package:orpheus/features/autofill/domain/autofill_field.dart';
import 'package:orpheus/features/autofill/domain/metadata_source.dart';
import 'package:orpheus/features/autofill/domain/release.dart';
import 'package:orpheus/features/autofill/domain/tag_writer.dart';
import 'package:orpheus/features/library/domain/audio_file.dart';

/// A [MetadataSource] answering what the test scripted, and recording what it
/// was asked.
class ScriptedMetadataSource implements MetadataSource {
  /// Releases each search answers.
  List<ReleaseCandidate> candidates = const [];

  /// Each release by id.
  Map<String, ReleaseDetail> releases = const {};

  /// Release-group genres by id.
  Map<String, List<Genre>> groupGenres = const {};

  /// Recordings each recording search answers.
  List<RecordingMatch> recordings = const [];

  /// Covers by release id.
  Map<String, Uint8List> covers = const {};

  /// What every call throws instead, where a test wants a failure.
  MetadataSourceFailure? failure;

  /// Held until completed, where a test wants a lookup in flight.
  Future<void>? hold;

  /// The release queries asked, in order.
  final List<ReleaseQuery> releaseQueries = [];

  /// The release ids looked up, in order.
  final List<String> lookedUp = [];

  /// The covers fetched, by release id.
  final List<String> coversFetched = [];

  Future<void> _gate() async {
    await hold;
    final thrown = failure;
    if (thrown != null) throw MetadataSourceException(thrown);
  }

  @override
  Future<List<ReleaseCandidate>> searchReleases(ReleaseQuery query) async {
    releaseQueries.add(query);
    await _gate();
    return candidates;
  }

  @override
  Future<ReleaseDetail> release(String id) async {
    lookedUp.add(id);
    await _gate();
    return releases[id]!;
  }

  @override
  Future<List<Genre>> releaseGroupGenres(String id) async {
    await _gate();
    return groupGenres[id] ?? const [];
  }

  @override
  Future<List<RecordingMatch>> searchRecordings(RecordingQuery query) async {
    await _gate();
    return recordings;
  }

  @override
  Future<Uint8List?> frontCover(String releaseId) async {
    coversFetched.add(releaseId);
    await _gate();
    return covers[releaseId];
  }
}

/// A [TagWriter] over a map of files, recording every write.
class FakeTagWriter implements TagWriter {
  /// What each path holds, and can hold.
  final Map<String, FileTags> files = {};

  /// What a write to a path answers instead of writing, where a test wants a
  /// refusal.
  final Map<String, WriteOutcome> refusals = {};

  /// Every write, in order: the path and what was written.
  final List<(String, Map<AutofillField, Object?>)> writes = [];

  @override
  Future<FileTags> inspect(String path) async =>
      files[path] ?? FileTags.unwritable;

  @override
  Future<WriteOutcome> write(
    String path,
    Map<AutofillField, Object?> values, {
    required AudioFile expected,
  }) async {
    final refused = refusals[path];
    if (refused != null) return refused;

    writes.add((path, values));
    final current = files[path];
    if (current != null) {
      files[path] = FileTags(
        writable: current.writable,
        values: {...current.values, ...values}..remove(AutofillField.cover),
        cover: values[AutofillField.cover] as Uint8List? ?? current.cover,
      );
    }

    return WriteOutcome.written;
  }
}
