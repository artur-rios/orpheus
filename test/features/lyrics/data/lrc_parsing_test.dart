import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/lyrics/data/lrc_parsing.dart';

/// Reading an LRC file.
///
/// The fixtures here are invented lines rather than any real song's words: what
/// is under test is the timing and the shape of the format, and a made-up
/// sheet exercises both exactly as well.
void main() {
  test(
    'GivenATimedSheet_WhenItIsRead_ThenEveryLineComesBackWithItsTime',
    () {
      final lyrics = parseLrc(
        '[00:12.50]The first line\n'
        '[00:18.00]The second line\n',
      );

      expect(lyrics, isNotNull);
      expect(lyrics!.isSynced, isTrue);
      expect(lyrics.lines.map((line) => line.text), [
        'The first line',
        'The second line',
      ]);
      expect(lyrics.lines.first.at, const Duration(milliseconds: 12500));
      expect(lyrics.lines.last.at, const Duration(seconds: 18));
    },
  );

  test(
    'GivenASheetWithTagsInFrontOfIt_WhenItIsRead_ThenTheTagsAreNotTakenForWords',
    () {
      // The header every writer of the format puts at the top. None of it is
      // sung, and a reader that showed it would put the artist's name where
      // the first line belongs.
      final lyrics = parseLrc(
        '[ti:A Song]\n'
        '[ar:Somebody]\n'
        '[by:Whoever typed it]\n'
        '[00:01.00]The only line\n',
      );

      expect(lyrics!.lines.map((line) => line.text), ['The only line']);
    },
  );

  test(
    'GivenALineGivenTwoTimes_WhenItIsRead_ThenItIsSungAtBoth',
    () {
      // How the format writes a refrain: one line, every time it comes round.
      final lyrics = parseLrc('[00:30.00][01:30.00]The refrain\n');

      expect(lyrics!.lines, hasLength(2));
      expect(lyrics.lines.every((line) => line.text == 'The refrain'), isTrue);
      expect(lyrics.lines.first.at, const Duration(seconds: 30));
      expect(lyrics.lines.last.at, const Duration(seconds: 90));
    },
  );

  test(
    'GivenLinesOutOfOrder_WhenTheyAreRead_ThenTheyComeBackInTheOrderTheyAreSung',
    () {
      final lyrics = parseLrc(
        '[00:20.00]Second\n'
        '[00:10.00]First\n',
      );

      expect(lyrics!.lines.map((line) => line.text), ['First', 'Second']);
    },
  );

  test(
    'GivenAnOffsetTag_WhenTheSheetIsRead_ThenTheTimesAreCorrectedByIt',
    () {
      // A positive offset is what a listener writes when the words keep
      // arriving late, so it moves them earlier.
      final lyrics = parseLrc(
        '[offset:+500]\n'
        '[00:10.00]A line\n',
      );

      expect(lyrics!.lines.single.at, const Duration(milliseconds: 9500));
    },
  );

  test(
    'GivenAnOffsetLargerThanTheFirstTime_WhenTheSheetIsRead_ThenNothingIsSungBeforeTheTrackStarts',
    () {
      final lyrics = parseLrc(
        '[offset:+5000]\n'
        '[00:01.00]A line\n',
      );

      expect(lyrics!.lines.single.at, Duration.zero);
    },
  );

  test(
    'GivenEnhancedLrcWithATimePerWord_WhenItIsRead_ThenTheLineIsPlainWords',
    () {
      // This application lights a line at a time. A file that carries more
      // detail than that is still a good file, and the extra is dropped
      // rather than printed among the words.
      final lyrics = parseLrc(
        '[00:05.00] <00:05.00>One <00:05.40>word <00:05.90>each\n',
      );

      expect(lyrics!.lines.single.text, 'One word each');
    },
  );

  test(
    'GivenASheetWithNoTimesAtAll_WhenItIsRead_ThenItIsWordsThatDoNotFollowTheMusic',
    () {
      final lyrics = parseLrc('A line\nAnother line\n');

      expect(lyrics!.isSynced, isFalse);
      expect(lyrics.lines.map((line) => line.text), ['A line', 'Another line']);
      expect(lyrics.lines.every((line) => line.at == null), isTrue);
    },
  );

  test(
    'GivenATimedGapBetweenVerses_WhenTheSheetIsRead_ThenTheGapIsKept',
    () {
      // An empty timed line is how the format says "nobody is singing now".
      // Dropped, it would leave the last line of the verse lit through the
      // solo that follows it.
      final lyrics = parseLrc(
        '[00:10.00]The last line of a verse\n'
        '[00:14.00]\n'
        '[00:30.00]The first line of the next\n',
      );

      expect(lyrics!.lines, hasLength(3));
      expect(lyrics.lines[1].text, isEmpty);
      expect(lyrics.lines[1].at, const Duration(seconds: 14));
    },
  );

  test(
    'GivenMinutesPastAnHour_WhenTheSheetIsRead_ThenTheTimeIsNotWrappedAround',
    () {
      // One long live side is one track, and its later lines are honestly
      // written as minutes past sixty.
      final lyrics = parseLrc('[73:20.00]A late line\n');

      expect(
        lyrics!.lines.single.at,
        const Duration(minutes: 73, seconds: 20),
      );
    },
  );

  test(
    'GivenTimesWrittenEveryWayTheFormatIsWritten_WhenTheyAreRead_ThenTheyMeanTheSameThing',
    () {
      final lyrics = parseLrc(
        '[00:05]No fraction\n'
        '[00:05.5]Tenths\n'
        '[00:05.50]Hundredths\n'
        '[00:05:50]A colon instead of a point\n'
        '[00:05.500]Thousandths\n',
      );

      expect(lyrics!.lines, hasLength(5));
      expect(lyrics.lines.first.at, const Duration(seconds: 5));
      expect(
        lyrics.lines.skip(1).map((line) => line.at).toSet(),
        {const Duration(milliseconds: 5500)},
      );
    },
  );

  test(
    'GivenALineThatOpensWithABracket_WhenItIsRead_ThenItKeepsIt',
    () {
      final lyrics = parseLrc('[00:01.00][Chorus] and the words\n');

      expect(lyrics!.lines.single.text, '[Chorus] and the words');
    },
  );

  test('GivenAnEmptyFile_WhenItIsRead_ThenThereAreNoLyrics', () {
    expect(parseLrc(''), isNull);
    expect(parseLrc('   \n\n'), isNull);
    expect(parseLrc('[ti:A Song]\n'), isNull);
  });

  test(
    'GivenAFileWrittenOnAnotherPlatform_WhenItIsRead_ThenItsLineEndingsAreNotWords',
    () {
      final lyrics = parseLrc('[00:01.00]First\r\n[00:02.00]Second\r\n');

      expect(lyrics!.lines.map((line) => line.text), ['First', 'Second']);
    },
  );
}
