import 'music_stats.dart';

/// Which ranking a card is about.
enum StoryTopic {
  /// The people played most.
  artists,

  /// The records played most.
  albums,

  /// The tracks played most.
  tracks,

  /// The genres played most.
  genres,
}

/// One screen of the story.
sealed class StoryCard {
  const StoryCard();
}

/// The one that opens it: how much has been listened to at all.
class StoryOpening extends StoryCard {
  /// Creates the card.
  const StoryOpening({required this.totalPlays, required this.distinctTracks});

  /// Every play ever counted.
  final int totalPlays;

  /// How many distinct files account for them.
  final int distinctTracks;
}

/// The single thing at the top of a ranking, given a screen of its own.
class StoryHeadline extends StoryCard {
  /// Creates the card.
  const StoryHeadline({
    required this.topic,
    required this.name,
    required this.plays,
    required this.share,
  });

  /// What kind of thing it is.
  final StoryTopic topic;

  /// What it is called.
  final String name;

  /// How many plays it accounts for.
  final int plays;

  /// What fraction of the ranking's plays it accounts for, 0 to 1.
  ///
  /// Of the ranking rather than of everything played, because that is the
  /// number the card can honestly stand behind: the rankings exclude untagged
  /// files, and a percentage of a total those files are counted in would be a
  /// figure that does not add up on a screen the owner might share.
  final double share;
}

/// A short ranking, counted down.
class StoryRanking extends StoryCard {
  /// Creates the card.
  const StoryRanking({required this.topic, required this.entries});

  /// What kind of thing it ranks.
  final StoryTopic topic;

  /// The lines, most played first.
  final List<RankedPlays> entries;
}

/// The one that closes it, and the one built to be shared.
class StorySummary extends StoryCard {
  /// Creates the card.
  const StorySummary({
    required this.totalPlays,
    required this.topArtist,
    required this.topAlbum,
    required this.topTrack,
  });

  /// Every play ever counted.
  final int totalPlays;

  /// The artist at the top, where there is one.
  final String? topArtist;

  /// The record at the top, where there is one.
  final String? topAlbum;

  /// The track at the top, where there is one.
  final String? topTrack;
}

/// How many lines a story's ranking card carries.
///
/// Five rather than the ten the statistics screen shows. A story card is read
/// in a few seconds and, on a phone, at arm's length; ten lines of small text
/// is the screen it was supposed to be an alternative to.
const int storyRankingLength = 5;

/// The story [stats] tell, or an empty list where they tell none.
///
/// Cards with nothing to say are not built rather than built empty: an owner
/// whose files carry no genre tag should not be shown a genre card apologising
/// for itself, and a ranking of one is a headline that has already been made.
///
/// The order is deliberate. It opens on the totals, which every library has;
/// then artists, records and tracks, each headline followed by the ranking it
/// came from; then genres, which are the tag most often missing and so the
/// card most often skipped; and it closes on the summary, which is the one
/// built to leave the application.
List<StoryCard> storyFrom(MusicStats stats) {
  if (stats.isEmpty) return const [];

  return [
    StoryOpening(
      totalPlays: stats.totalPlays,
      distinctTracks: stats.distinctTracks,
    ),
    for (final topic in StoryTopic.values) ..._cardsFor(topic, stats),
    StorySummary(
      totalPlays: stats.totalPlays,
      topArtist: _leaderOf(stats.artists)?.name,
      topAlbum: _leaderOf(stats.albums)?.name,
      topTrack: _leaderOf(stats.tracks)?.name,
    ),
  ];
}

List<StoryCard> _cardsFor(StoryTopic topic, MusicStats stats) {
  final ranking = switch (topic) {
    StoryTopic.artists => stats.artists,
    StoryTopic.albums => stats.albums,
    StoryTopic.tracks => stats.tracks,
    StoryTopic.genres => stats.genres,
  };

  final leader = _leaderOf(ranking);
  if (leader == null) return const [];

  final counted = ranking.fold<int>(0, (sum, line) => sum + line.plays);

  return [
    StoryHeadline(
      topic: topic,
      name: leader.name,
      plays: leader.plays,
      share: counted == 0 ? 0 : leader.plays / counted,
    ),
    // A ranking card only where there is a ranking. Two lines is a list; one
    // is the headline again, with a number beside it.
    if (ranking.length > 1)
      StoryRanking(
        topic: topic,
        entries: ranking.take(storyRankingLength).toList(),
      ),
  ];
}

/// The first line of [ranking] that names something, or `null` for none.
RankedPlays? _leaderOf(List<RankedPlays> ranking) =>
    ranking.isEmpty ? null : ranking.first;
