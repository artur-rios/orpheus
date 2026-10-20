import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/autofill/application/release_fetch.dart';
import 'package:orpheus/features/autofill/domain/autofill_field.dart';
import 'package:orpheus/features/autofill/domain/metadata_source.dart';
import 'package:orpheus/features/autofill/domain/proposals.dart';
import 'package:orpheus/features/autofill/domain/release.dart';

import '../../../support/entries.dart';
import '../../../support/fake_autofill.dart';

/// The release and what the chosen tags fetch besides it.
void main() {
  const candidate = ReleaseCandidate(
    id: 'rel-1',
    title: 'OK Computer',
    artistCredit: [ArtistCredit(name: 'Radiohead')],
    trackCount: 1,
  );

  ScriptedMetadataSource sourceOf({
    List<Genre> genres = const [],
    String? groupId = 'group-1',
  }) => ScriptedMetadataSource()
    ..releases = {
      'rel-1': ReleaseDetail(
        release: candidate,
        tracks: const [],
        genres: genres,
        releaseGroupId: groupId,
      ),
    }
    ..groupGenres = {
      'group-1': const [Genre(name: 'rock', votes: 3)],
    };

  test('GivenGenreChosenAndReleaseWithout_WhenFetched_ThenGroupGenresAreTheFallback', () async {
    final fetched = await fetchRelease(sourceOf(), 'rel-1', {
      AutofillField.genre,
    });

    expect(fetched.detail.release.id, 'rel-1');
    expect(fetched.fallbackGenres.map((g) => g.name), ['rock']);
  });

  test('GivenGroupGenresFail_WhenFetched_ThenNoFallbackAndNoThrow', () async {
    final source = sourceOf()
      ..groupGenresFailure = MetadataSourceFailure.unreachable;

    final fetched = await fetchRelease(source, 'rel-1', {AutofillField.genre});

    expect(fetched.fallbackGenres, isEmpty);
    expect(fetched.detail.release.id, 'rel-1');
  });

  test(
    'GivenCoverChosenAndDownloadFails_WhenFetched_ThenCoverUnavailable',
    () async {
      final source = sourceOf()
        ..coverFailure = MetadataSourceFailure.unreachable;

      final fetched = await fetchRelease(source, 'rel-1', {
        AutofillField.cover,
      });

      expect(fetched.coverUnavailable, isTrue);
      expect(fetched.cover, isNull);
    },
  );

  test('GivenCoverChosen_WhenFetched_ThenTheCoverIsReturned', () async {
    final source = sourceOf()
      ..covers = {
        'rel-1': Uint8List.fromList([1, 2, 3]),
      };

    final fetched = await fetchRelease(source, 'rel-1', {AutofillField.cover});

    expect(fetched.cover, [1, 2, 3]);
    expect(fetched.coverUnavailable, isFalse);
  });

  test('GivenCoverNotChosen_WhenFetched_ThenNoCoverFetched', () async {
    final source = sourceOf();

    await fetchRelease(source, 'rel-1', {AutofillField.artist});

    expect(source.coversFetched, isEmpty);
  });

  test('GivenThePlayingFileFirst_WhenPlayingLast_ThenItIsLast', () {
    final proposals = [
      for (final id in ['a', 'b', 'c']) FileProposal(entry: entry(id: id)),
    ];

    final ordered = playingLast(proposals, proposals.first.entry.file.path);

    expect(ordered.map((p) => p.entry.file.path), [
      proposals[1].entry.file.path,
      proposals[2].entry.file.path,
      proposals[0].entry.file.path,
    ]);
  });
}
