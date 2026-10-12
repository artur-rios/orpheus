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

  // A bilingual LRC: each line, then its translation, under the same time.
  // Long enough that `List.sort` stops being an insertion sort — which happens
  // to be stable — and starts being one that is not, which is what used to
  // swap a line with its translation partway down a long song.
  final bilingual = [
    for (var verse = 30; verse > 0; verse--) ...[
      LyricLine(text: 'Line $verse', at: Duration(seconds: verse * 5)),
      LyricLine(text: 'Linha $verse', at: Duration(seconds: verse * 5)),
    ],
  ];

  test(
    'GivenLinesThatShareATime_WhenTheyAreOrdered_ThenTheyKeepTheOrderTheFileGaveThem',
    () {
      final sheet = Lyrics.synced(bilingual);

      expect(sheet.lines.map((line) => line.text).take(6), [
        'Line 1',
        'Linha 1',
        'Line 2',
        'Linha 2',
        'Line 3',
        'Linha 3',
      ]);
      for (var index = 0; index < sheet.lines.length; index += 2) {
        expect(sheet.lines[index].text, startsWith('Line '));
        expect(sheet.lines[index + 1].text, startsWith('Linha '));
      }
    },
  );

  test(
    'GivenLinesThatShareATime_WhenThatTimeIsPlaying_ThenTheFirstOfThemIsTheOneSung',
    () {
      // The line rather than its translation: the highlight and the scroll
      // land on the top of the pair, with the translation following beneath.
      final sheet = Lyrics.synced(bilingual);

      expect(sheet.lineIndexAt(const Duration(seconds: 12)), 2);
      expect(sheet.lineIndexAt(const Duration(seconds: 10)), 2);
      expect(sheet.lineIndexAt(const Duration(minutes: 5)), 58);
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
