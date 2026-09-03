import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/playback/domain/playback_queue.dart';

import '../../../support/entries.dart';

/// What is queued, and where playback is in it.
void main() {
  final tracks = [file('1'), file('2'), file('3')];

  test('GivenAQueueInTheMiddle_WhenItIsAsked_ThenItHasBothANextAndAPrevious', () {
    const queue = PlaybackQueue(tracks: [], kind: QueueKind.album);

    expect(queue.isEmpty, isTrue);
    expect(queue.current, isNull);
    expect(queue.hasNext, isFalse);
    expect(queue.hasPrevious, isFalse);
  });

  test('GivenAQueueAtItsFirstTrack_WhenItIsAsked_ThenThereIsNothingBefore', () {
    final queue = PlaybackQueue(tracks: tracks, kind: QueueKind.album);

    expect(queue.current, tracks.first);
    expect(queue.hasPrevious, isFalse);
    expect(queue.hasNext, isTrue);
  });

  test('GivenAQueueAtItsLastTrack_WhenItIsAsked_ThenThereIsNothingAfter', () {
    final queue = PlaybackQueue(
      tracks: tracks,
      kind: QueueKind.album,
      index: 2,
    );

    expect(queue.hasNext, isFalse);
    expect(queue.hasPrevious, isTrue);
  });

  test(
    'GivenEveryQueuedTrackWasSkipped_WhenTheQueueIsAsked_ThenItSaysEverythingFailed',
    () {
      var queue = PlaybackQueue(tracks: tracks, kind: QueueKind.album);
      for (final track in tracks) {
        queue = queue.skipping(track);
      }

      expect(queue.everythingFailed, isTrue);
    },
  );

  test(
    'GivenAnAlbumOrArtistQueue_WhenItIsAsked_ThenItNamesTheRecordItself',
    () {
      // An album queue *is* a record: every track in it belongs to the same
      // one, so the sleeve does not change as it plays through.
      for (final kind in [QueueKind.album, QueueKind.artist]) {
        expect(
          PlaybackQueue(tracks: tracks, kind: kind).namesOwnRecord,
          isTrue,
        );
      }
    },
  );

  test(
    'GivenATrackOrShuffledQueue_WhenItIsAsked_ThenTheRecordIsWhicheverTrackIsPlaying',
    () {
      // Which is what makes crossing from one album to the next inside a
      // shuffle change the sleeve, while skipping within an album does not.
      for (final kind in [QueueKind.track, QueueKind.playlist]) {
        expect(
          PlaybackQueue(tracks: tracks, kind: kind).namesOwnRecord,
          isFalse,
        );
      }
    },
  );

  test('GivenAnyRepeatMode_WhenTheButtonIsPressed_ThenItStepsRoundTheThree', () {
    expect(QueueRepeat.off.next, QueueRepeat.all);
    expect(QueueRepeat.all.next, QueueRepeat.one);
    expect(QueueRepeat.one.next, QueueRepeat.off);
  });
}
