import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/lyrics/domain/lyrics.dart';

/// Which line belongs to a moment in a track.
void main() {
  final sheet = Lyrics.synced(const [
    LyricLine(text: 'First', at: Duration(seconds: 10)),
    LyricLine(text: 'Second', at: Duration(seconds: 20)),
    LyricLine(text: 'Third', at: Duration(seconds: 30)),
  ]);

  test(
    'GivenAPositionInsideALine_WhenTheLineIsAskedFor_ThenItIsTheOneBeingSung',
    () {
      expect(sheet.lineIndexAt(const Duration(seconds: 25)), 1);
    },
  );

  test(
    'GivenAPositionExactlyOnALine_WhenTheLineIsAskedFor_ThenThatLineHasStarted',
    () {
      expect(sheet.lineIndexAt(const Duration(seconds: 20)), 1);
    },
  );

  test(
    'GivenAPositionBeforeTheFirstLine_WhenTheLineIsAskedFor_ThenNoneIsSinging',
    () {
      // The count-in, the intro. Nothing is lit, which is the truth about a
      // track nobody has started singing over yet.
      expect(sheet.lineIndexAt(const Duration(seconds: 3)), isNull);
    },
  );

  test(
    'GivenAPositionAfterTheLastLine_WhenTheLineIsAskedFor_ThenItIsStillTheLast',
    () {
      expect(sheet.lineIndexAt(const Duration(minutes: 5)), 2);
    },
  );

  test(
    'GivenWordsWithNoTimes_WhenALineIsAskedFor_ThenThereIsNoneToLight',
    () {
      final plain = Lyrics.plain(const ['A line', 'Another line']);

      expect(plain.isSynced, isFalse);
      expect(plain.lineIndexAt(const Duration(seconds: 30)), isNull);
    },
  );

  test(
    'GivenLinesHandedOverOutOfOrder_WhenTheyAreMade_ThenTheyAreOrderedByTheirTimes',
    () {
      // Everything downstream — the lookup above, the scrolling, the
      // highlight — reads the list in order, so the order is made here rather
      // than trusted from whoever wrote the file.
      final unordered = Lyrics.synced(const [
        LyricLine(text: 'Later', at: Duration(seconds: 40)),
        LyricLine(text: 'Earlier', at: Duration(seconds: 10)),
      ]);

      expect(unordered.lines.map((line) => line.text), ['Earlier', 'Later']);
      expect(unordered.lineIndexAt(const Duration(seconds: 15)), 0);
    },
  );

  test('GivenNoLinesAtAll_WhenTheyAreAsked_ThenTheyAreEmpty', () {
    expect(Lyrics.synced(const []).isEmpty, isTrue);
    expect(
      Lyrics.synced(const []).lineIndexAt(const Duration(seconds: 1)),
      isNull,
    );
  });
}
