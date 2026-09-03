import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/playback/domain/media_session.dart';

/// What a media session shows, and the two questions asked about it.
void main() {
  const airbag = NowPlaying(
    id: '/library/zzz-ok1.flac',
    title: 'Airbag',
    artist: 'Radiohead',
    album: 'OK Computer',
    duration: Duration(minutes: 4, seconds: 44),
    artPath: '/covers/sleeve-ok',
    position: Duration(seconds: 30),
    isPlaying: true,
    hasNext: true,
    hasPrevious: true,
  );

  group('the same track, playing on', () {
    test(
      'GivenTheSameTrackAtALaterPosition_WhenTheTwoAreCompared_ThenItIsStillTheSameTrack',
      () async {
        const later = NowPlaying(
          id: '/library/zzz-ok1.flac',
          title: 'Airbag',
          artist: 'Radiohead',
          album: 'OK Computer',
          duration: Duration(minutes: 4, seconds: 44),
          artPath: '/covers/sleeve-ok',
          position: Duration(minutes: 2),
          isPlaying: true,
          hasNext: true,
          hasPrevious: true,
        );

        // The point of the narrower question: the sleeve does not have to be
        // loaded and scaled again several times a second while a track runs.
        expect(airbag.sameTrackAs(later), isTrue);
        expect(airbag, isNot(later));
      },
    );

    test(
      'GivenTheSameTrackPaused_WhenTheTwoAreCompared_ThenItIsStillTheSameTrack',
      () async {
        // Pausing changes which way the button faces and nothing about what is
        // playing, so the track is not re-announced for it.
        expect(
          airbag.sameTrackAs(
            const NowPlaying(
              id: '/library/zzz-ok1.flac',
              title: 'Airbag',
              artist: 'Radiohead',
              album: 'OK Computer',
              duration: Duration(minutes: 4, seconds: 44),
              artPath: '/covers/sleeve-ok',
              position: Duration(seconds: 30),
            ),
          ),
          isTrue,
        );
      },
    );

    test(
      'GivenTheNextTrackOnTheSameRecord_WhenTheTwoAreCompared_ThenItIsADifferentTrack',
      () async {
        const karma = NowPlaying(
          id: '/library/zzz-ok2.flac',
          title: 'Karma Police',
          artist: 'Radiohead',
          album: 'OK Computer',
          artPath: '/covers/sleeve-ok',
        );

        expect(airbag.sameTrackAs(karma), isFalse);
      },
    );

    test(
      'GivenTheSleeveHasBeenLocated_WhenTheTwoAreCompared_ThenItIsADifferentTrack',
      () async {
        // The picture arrives after the track does — it is read from disk —
        // and the announcement that carries it has to get through.
        const beforeTheArtWasFound = NowPlaying(
          id: '/library/zzz-ok1.flac',
          title: 'Airbag',
          artist: 'Radiohead',
          album: 'OK Computer',
          duration: Duration(minutes: 4, seconds: 44),
          position: Duration(seconds: 30),
          isPlaying: true,
          hasNext: true,
          hasPrevious: true,
        );

        expect(airbag.sameTrackAs(beforeTheArtWasFound), isFalse);
      },
    );
  });

  group('anything at all changed', () {
    test(
      'GivenTwoIdenticalDescriptions_WhenTheyAreCompared_ThenTheyAreEqual',
      () async {
        const same = NowPlaying(
          id: '/library/zzz-ok1.flac',
          title: 'Airbag',
          artist: 'Radiohead',
          album: 'OK Computer',
          duration: Duration(minutes: 4, seconds: 44),
          artPath: '/covers/sleeve-ok',
          position: Duration(seconds: 30),
          isPlaying: true,
          hasNext: true,
          hasPrevious: true,
        );

        expect(airbag, same);
        expect(airbag.hashCode, same.hashCode);
      },
    );

    test(
      'GivenOnlyTheNextButtonChanged_WhenTheyAreCompared_ThenTheyDiffer',
      () async {
        // The last track of a queue: the same track, drawn with a dead button.
        const atTheEnd = NowPlaying(
          id: '/library/zzz-ok1.flac',
          title: 'Airbag',
          artist: 'Radiohead',
          album: 'OK Computer',
          duration: Duration(minutes: 4, seconds: 44),
          artPath: '/covers/sleeve-ok',
          position: Duration(seconds: 30),
          isPlaying: true,
          hasPrevious: true,
        );

        expect(airbag, isNot(atTheEnd));
        expect(airbag.sameTrackAs(atTheEnd), isTrue);
      },
    );
  });
}
