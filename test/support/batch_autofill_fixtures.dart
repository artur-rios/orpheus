import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/core/settings/in_memory_settings_store.dart';
import 'package:orpheus/features/autofill/domain/autofill_field.dart';
import 'package:orpheus/features/autofill/domain/release.dart';
import 'package:orpheus/features/autofill/domain/tag_writer.dart';
import 'package:orpheus/features/library/domain/audio_file.dart';
import 'package:orpheus/features/library/domain/library_scan.dart';
import 'package:orpheus/features/library/domain/music_catalog.dart';
import 'package:orpheus/features/library/domain/music_entry.dart';
import 'package:orpheus/features/library/domain/music_grouping.dart';
import 'package:orpheus/features/library/domain/track_metadata.dart';

import 'entries.dart';
import 'fakes.dart';
import 'test_container.dart';

/// What the batch autofill's screens are tested over: albums MusicBrainz knows
/// under an artist one letter off, ready to be corrected.
const List<ArtistCredit> radiohead = [ArtistCredit(name: 'Radiohead')];

/// [count] songs of the album [name], each titled as MusicBrainz titles it and
/// numbered, in a folder of their own.
List<MusicEntry> albumOf(String name, {int count = 2}) => [
  for (var n = 1; n <= count; n++)
    entry(
      id: '$name-$n',
      title: '$name $n',
      artist: 'Radiohead',
      albumArtist: 'Radiohead',
      album: name,
      track: n,
      directory: '/library/$name',
    ),
];

/// A song of a kind Orpheus cannot write.
MusicEntry oggSong(String name) => MusicEntry(
  file: AudioFile(
    path: '/library/$name.ogg',
    sizeInBytes: 1024,
    modifiedAt: DateTime.utc(2026),
  ),
  metadata: TrackMetadata(title: name, artist: 'Radiohead'),
);

/// The release of [name] with [count] tracks, as a search answers it.
ReleaseCandidate releaseOf(
  String name, {
  int count = 2,
  String status = 'Official',
}) => ReleaseCandidate(
  id: 'rel-$name',
  title: name,
  artistCredit: radiohead,
  trackCount: count,
  status: status,
);

/// [release] with the tracks [albumOf] has.
ReleaseDetail detailOf(ReleaseCandidate release) => ReleaseDetail(
  release: release,
  tracks: [
    for (var n = 1; n <= release.trackCount; n++)
      ReleaseTrack(
        disc: 1,
        position: n,
        title: '${release.title} $n',
        artistCredit: radiohead,
      ),
  ],
);

/// What one of [albumOf]'s songs says before the batch: an artist one letter
/// off, which the release corrects.
FileTags misspelt(MusicEntry song) => FileTags(
  writable: AutofillField.values.toSet(),
  values: {
    AutofillField.title: song.title,
    AutofillField.artist: 'Radiohed',
    AutofillField.album: song.album,
  },
);

/// A harness over [library] where MusicBrainz knows each album as the release
/// [releases] says (an official one where it is omitted) and every song of
/// [albumOf] is misspelt.
Harness batchHarness(
  List<MusicEntry> library, {
  Map<String, ReleaseCandidate>? releases,
  FakeLibraryAccess? access,
}) {
  final harness = Harness(
    library: library,
    access: access,
    // Never the real scanner: a write rescans, and the rescan must not walk
    // the disk.
    scanner: ScriptedScanner([
      ScanCompleted(
        catalog: MusicCatalog(entries: albumArtistsAcross(library)),
        report: ScanReport(
          tracks: library.length,
          added: 0,
          updated: library.length,
          removed: 0,
          reused: 0,
        ),
      ),
    ]),
    settings: InMemorySettingsStore(libraryFolders: const ['/music']),
  );

  final byAlbum =
      releases ??
      {
        for (final album in {for (final song in library) ?song.album})
          album: releaseOf(
            album,
            count: library.where((s) => s.album == album).length,
          ),
      };
  harness.metadata
    ..candidatesFor = ((query) => [?byAlbum[query.album]])
    ..releases = {
      for (final release in byAlbum.values) release.id: detailOf(release),
    };
  for (final song in library) {
    if (canWriteTagsTo(song.file.path)) {
      harness.tagWriter.files[song.file.path] = misspelt(song);
    }
  }

  // A write starts a rescan and does not wait for it. Let it finish before
  // the container goes (teardowns run last-registered first).
  addTearDown(pumpEventQueue);

  return harness;
}
