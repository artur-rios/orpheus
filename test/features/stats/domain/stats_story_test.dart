import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/stats/domain/music_stats.dart';
import 'package:orpheus/features/stats/domain/stats_story.dart';

/// Which cards a set of statistics produces, and which it does not.
void main() {
  MusicStats stats({
    int totalPlays = 30,
    int distinctTracks = 9,
    List<RankedPlays> artists = const [],
    List<RankedPlays> albums = const [],
    List<RankedPlays> tracks = const [],
    List<RankedPlays> genres = const [],
  }) => MusicStats(
    totalPlays: totalPlays,
    distinctTracks: distinctTracks,
    tracks: tracks,
    artists: artists,
    albums: albums,
    genres: genres,
    untaggedTracks: 0,
  );

  List<RankedPlays> ranked(Map<String, int> lines) => [
    for (final line in lines.entries)
      RankedPlays(name: line.key, plays: line.value),
  ];

  test(
    'GivenNothingPlayed_WhenTheStoryIsBuilt_ThenThereIsNoStory',
    () {
      // The button that opens it is hidden in this case, and this is why it
      // can be: an empty story is not a story with an apology in it.
      expect(storyFrom(MusicStats.empty), isEmpty);
    },
  );

  test(
    'GivenARankingWithNothingInIt_WhenTheStoryIsBuilt_ThenItContributesNoCards',
    () {
      // Most libraries carry no genre tag. A card headed "your top genre" over
      // a blank space is worse than one card fewer.
      final story = storyFrom(
        stats(artists: ranked({'Radiohead': 12, 'Miles Davis': 6})),
      );

      expect(story.whereType<StoryHeadline>().map((card) => card.topic), [
        StoryTopic.artists,
      ]);
      expect(story.whereType<StoryRanking>().map((card) => card.topic), [
        StoryTopic.artists,
      ]);
    },
  );

  test(
    'GivenARankingOfExactlyOne_WhenTheStoryIsBuilt_ThenThereIsAHeadlineAndNoList',
    () {
      // A list of one is the headline again with a number beside it.
      final story = storyFrom(stats(albums: ranked({'OK Computer': 12})));

      expect(story.whereType<StoryHeadline>(), hasLength(1));
      expect(story.whereType<StoryRanking>(), isEmpty);
    },
  );

  test(
    'GivenALongRanking_WhenTheStoryIsBuilt_ThenTheCardCarriesOnlyTheTopFew',
    () {
      final story = storyFrom(
        stats(
          tracks: ranked({
            for (var index = 0; index < 10; index++) 'Track $index': 10 - index,
          }),
        ),
      );

      final ranking = story.whereType<StoryRanking>().single;
      expect(ranking.entries, hasLength(storyRankingLength));
      expect(ranking.entries.first.name, 'Track 0');
    },
  );

  test(
    'GivenALeader_WhenItsShareIsWorkedOut_ThenItIsOfTheRankingRatherThanOfEverything',
    () {
      // The rankings exclude untagged files, which the total counts. A
      // percentage of the total would be a figure that does not add up on a
      // card the owner may put in front of other people.
      final story = storyFrom(
        stats(
          totalPlays: 100,
          artists: ranked({'Radiohead': 30, 'Miles Davis': 10}),
        ),
      );

      final headline = story.whereType<StoryHeadline>().single;
      expect(headline.share, closeTo(0.75, 0.001));
    },
  );

  test(
    'GivenAFullSetOfStatistics_WhenTheStoryIsBuilt_ThenItOpensOnTheTotalsAndClosesOnTheSummary',
    () {
      final story = storyFrom(
        stats(
          artists: ranked({'Radiohead': 12, 'Miles Davis': 6}),
          albums: ranked({'OK Computer': 8, 'Kind of Blue': 6}),
          tracks: ranked({'Airbag': 5, 'So What': 4}),
          genres: ranked({'Rock': 12, 'Jazz': 6}),
        ),
      );

      expect(story.first, isA<StoryOpening>());
      expect(story.last, isA<StorySummary>());

      final summary = story.last as StorySummary;
      expect(summary.topArtist, 'Radiohead');
      expect(summary.topAlbum, 'OK Computer');
      expect(summary.topTrack, 'Airbag');
    },
  );
}
