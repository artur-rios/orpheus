import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/library/domain/music_entry.dart';
import 'package:orpheus/features/playback/domain/queue_continuation.dart';

import '../../../support/entries.dart';

/// What may follow a queue that ran out: the rule, before any randomness.
void main() {
  final airbag = entry(id: 'ok1', artist: 'Radiohead', album: 'OK');
  final karma = entry(id: 'ok2', artist: 'Radiohead', album: 'OK');
  final idioteque = entry(id: 'ka1', artist: 'Radiohead', album: 'Kid A');
  final soWhat = entry(id: 'x1', artist: 'Miles Davis', album: 'Blue');
  final library = [airbag, karma, idioteque, soWhat];

  Set<String> pathsOf(List<MusicEntry> entries) => {
    for (final entry in entries) entry.file.path,
  };

  List<MusicEntry> poolOf(
    QueueContinuation mode,
    MusicEntry seed, {
    List<MusicEntry>? within,
    List<MusicEntry>? queued,
    List<MusicEntry> skipped = const [],
  }) => continuationPool(
    mode: mode,
    seedPath: seed.file.path,
    library: within ?? library,
    queuedPaths: pathsOf(queued ?? [seed]),
    skippedPaths: pathsOf(skipped),
  );

  test('GivenStop_WhenThePoolIsAsked_ThenItIsEmpty', () {
    expect(poolOf(QueueContinuation.stop, airbag), isEmpty);
  });

  test(
    'GivenSameArtist_WhenTheSeedHasAnArtist_ThenOnlyTracksByThemAreOffered',
    () {
      expect(poolOf(QueueContinuation.sameArtist, airbag), [karma, idioteque]);
    },
  );

  test(
    'GivenSameArtist_WhenACompilationTrackIsTheSeed_ThenThePerformerIsFollowed',
    () {
      final onCompilation = entry(
        id: 'c1',
        artist: 'Björk',
        albumArtist: 'Various Artists',
        album: 'Hits',
      );
      final someoneElse = entry(
        id: 'c2',
        artist: 'Moby',
        albumArtist: 'Various Artists',
        album: 'Hits',
      );
      final ownRecord = entry(id: 'b1', artist: 'Björk', album: 'Debut');

      expect(
        poolOf(
          QueueContinuation.sameArtist,
          onCompilation,
          within: [onCompilation, someoneElse, ownRecord],
        ),
        [ownRecord],
      );
    },
  );

  test(
    'GivenSameArtist_WhenTheSeedNamesNoArtist_ThenTheWholeLibraryIsOffered',
    () {
      final untagged = entry(id: 'u1');

      expect(
        poolOf(
          QueueContinuation.sameArtist,
          untagged,
          within: [...library, untagged],
        ),
        library,
      );
    },
  );

  test(
    'GivenSameGenre_WhenTheSeedHasTwoGenres_ThenTracksSharingEitherAreOffered',
    () {
      final seed = entry(id: 'g0', genres: ['Rock', 'Pop']);
      final rock = entry(id: 'g1', genres: ['rock']);
      final pop = entry(id: 'g2', genres: ['Pop', 'Dance']);
      final jazz = entry(id: 'g3', genres: ['Jazz']);

      expect(
        poolOf(
          QueueContinuation.sameGenre,
          seed,
          within: [seed, rock, pop, jazz],
        ),
        [rock, pop],
      );
    },
  );

  test('GivenSameGenre_WhenTheSeedHasNoGenre_ThenTheWholeLibraryIsOffered', () {
    expect(poolOf(QueueContinuation.sameGenre, airbag), [
      karma,
      idioteque,
      soWhat,
    ]);
  });

  test('GivenTheSeedIsNotInTheLibrary_WhenThePoolIsAsked_ThenTheWholeLibraryIsOffered', () {
    final removed = entry(id: 'gone', artist: 'Radiohead');

    expect(poolOf(QueueContinuation.sameArtist, removed), library);
  });

  test(
    'GivenTracksAlreadyQueued_WhenOthersMatch_ThenTheQueuedOnesAreLeftOut',
    () {
      expect(
        poolOf(QueueContinuation.sameArtist, karma, queued: [airbag, karma]),
        [idioteque],
      );
    },
  );

  test('GivenEveryMatchIsQueued_WhenThePoolIsAsked_ThenTheyAreOfferedAgainExceptTheSeed', () {
    expect(
      poolOf(
        QueueContinuation.sameArtist,
        idioteque,
        queued: [airbag, karma, idioteque],
      ),
      [airbag, karma],
    );
  });

  test('GivenAnArtistOfOneTrack_WhenItEnds_ThenThePoolIsEmpty', () {
    expect(poolOf(QueueContinuation.sameArtist, soWhat), isEmpty);
  });

  test(
    'GivenASkippedTrack_WhenEverythingElseIsQueued_ThenItIsNeverOffered',
    () {
      expect(
        poolOf(
          QueueContinuation.sameArtist,
          idioteque,
          queued: [airbag, karma, idioteque],
          skipped: [karma],
        ),
        [airbag],
      );
    },
  );

  test('GivenAStoredName_WhenItIsRead_ThenTheModeIsRestored', () {
    for (final mode in QueueContinuation.values) {
      expect(QueueContinuation.fromName(mode.name), mode);
    }
  });

  test('GivenAnUnknownName_WhenItIsRead_ThenItIsStop', () {
    expect(
      QueueContinuation.fromName('shuffleForever'),
      QueueContinuation.stop,
    );
    expect(QueueContinuation.fromName(null), QueueContinuation.stop);
  });
}
