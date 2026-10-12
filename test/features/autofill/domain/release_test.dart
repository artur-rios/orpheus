import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/autofill/domain/release.dart';

/// What a release says about itself.
void main() {
  test('GivenACreditOfTwoArtists_WhenItIsNamed_ThenTheJoinPhrasesAreKept', () {
    const credits = [
      ArtistCredit(name: 'Queen', joinPhrase: ' & '),
      ArtistCredit(name: 'David Bowie'),
    ];

    expect(creditedName(credits), 'Queen & David Bowie');
  });

  test('GivenADateWithOnlyAYear_WhenTheYearIsAsked_ThenItIsThatYear', () {
    expect(_candidate(date: '1997').year, 1997);
    expect(_candidate(date: '1997-05-21').year, 1997);
    expect(_candidate(date: null).year, isNull);
    expect(_candidate(date: 'soon').year, isNull);
  });

  test(
    'GivenATwoDiscRelease_WhenItsShapeIsAsked_ThenEachDiscCountsItsOwnTracks',
    () {
      final detail = ReleaseDetail(
        release: _candidate(),
        tracks: [
          _track(disc: 1, position: 1),
          _track(disc: 1, position: 2),
          _track(disc: 2, position: 1),
        ],
      );

      expect(detail.discCount, 2);
      expect(detail.tracksOnDisc(1), 2);
      expect(detail.tracksOnDisc(2), 1);
    },
  );
}

ReleaseCandidate _candidate({String? date = '1997'}) => ReleaseCandidate(
  id: 'r1',
  title: 'OK Computer',
  artistCredit: const [ArtistCredit(name: 'Radiohead')],
  date: date,
  trackCount: 12,
);

ReleaseTrack _track({required int disc, required int position}) => ReleaseTrack(
  disc: disc,
  position: position,
  title: 'Track $position',
  artistCredit: const [ArtistCredit(name: 'Radiohead')],
);
