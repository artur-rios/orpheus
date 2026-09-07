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
    'GivenEveryQueuedTrackWasSkipped_WhenTheQueueIsAsked_ThenEachOneIsRecorded',
    () {
      var queue = PlaybackQueue(tracks: tracks, kind: QueueKind.album);
      for (final track in tracks) {
        queue = queue.skipping(track);
      }

      expect(queue.skipped, tracks);
    },
  );

  test('GivenAnyRepeatMode_WhenTheButtonIsPressed_ThenItStepsRoundTheThree', () {
    expect(QueueRepeat.off.next, QueueRepeat.all);
    expect(QueueRepeat.all.next, QueueRepeat.one);
    expect(QueueRepeat.one.next, QueueRepeat.off);
  });
}
