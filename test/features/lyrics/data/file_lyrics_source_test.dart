import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/lyrics/data/file_lyrics_source.dart';
import 'package:path/path.dart' as p;

import '../../../support/flac_fixture.dart';
import '../../../support/id3_fixture.dart';

/// Where a track's words are found on this machine.
///
/// Against real files, because that is the whole of what this class does: it
/// probes a path, reads a header, and answers what it found. The words in the
/// fixtures are invented lines, which exercise the reading exactly as well as
/// anybody's real ones would.
void main() {
  const source = FileLyricsSource();

  late Directory music;
  late String track;

  setUp(() {
    music = Directory.systemTemp.createTempSync('orpheus-lyrics');
    track = p.join(music.path, 'the-track.flac');
    File(track).writeAsBytesSync(taggedFlac(tags: {'TITLE': 'The Track'}));
  });

  tearDown(() => music.deleteSync(recursive: true));

  void writeSidecar(String contents, {String extension = '.lrc'}) =>
      File(p.join(music.path, 'the-track$extension'))
          .writeAsStringSync(contents);

  test(
    'GivenALrcFileBesideTheTrack_WhenTheWordsAreAskedFor_ThenTheyComeFromIt',
    () async {
      writeSidecar('[00:10.00]A line from beside the track\n');

      final lyrics = await source.of(track);

      expect(lyrics!.isSynced, isTrue);
      expect(lyrics.lines.single.text, 'A line from beside the track');
      expect(lyrics.lines.single.at, const Duration(seconds: 10));
    },
  );

  test(
    'GivenTheSidecarIsSpeltInCapitals_WhenTheWordsAreAskedFor_ThenItIsStillFound',
    () async {
      // What a file that has been through a case-insensitive machine looks
      // like when it lands on a case-sensitive one.
      writeSidecar('[00:01.00]A shouted extension\n', extension: '.LRC');

      final lyrics = await source.of(track);

      expect(lyrics!.lines.single.text, 'A shouted extension');
    },
  );

  test(
    'GivenTheTrackCarriesItsWordsInItsTags_WhenTheyAreAskedFor_ThenTheyComeFromTheFile',
    () async {
      File(track).writeAsBytesSync(
        taggedFlac(
          tags: {
            'TITLE': 'The Track',
            'LYRICS': '[00:05.00]A line from the tags\n',
          },
        ),
      );

      final lyrics = await source.of(track);

      expect(lyrics!.isSynced, isTrue);
      expect(lyrics.lines.single.text, 'A line from the tags');
    },
  );

  test(
    'GivenTagsCarryingPlainWords_WhenTheyAreAskedFor_ThenTheyDoNotFollowTheMusic',
    () async {
      File(track).writeAsBytesSync(
        taggedFlac(
          tags: {'LYRICS': 'A line\nAnother line\n'},
        ),
      );

      final lyrics = await source.of(track);

      expect(lyrics!.isSynced, isFalse);
      expect(lyrics.lines, hasLength(2));
    },
  );

  test(
    'GivenBothASidecarAndTagsCarryWords_WhenTheyAreAskedFor_ThenTheSidecarWins',
    () async {
      // The one of the two the owner can write, correct and delete without a
      // tag editor. Somebody who has put a .lrc beside a track has said what
      // they want that track's words to be.
      File(track).writeAsBytesSync(
        taggedFlac(tags: {'LYRICS': '[00:05.00]From the tags\n'}),
      );
      writeSidecar('[00:05.00]From beside the track\n');

      final lyrics = await source.of(track);

      expect(lyrics!.lines.single.text, 'From beside the track');
    },
  );

  test(
    'GivenASidecarWithNothingInIt_WhenTheWordsAreAskedFor_ThenTheTagsAreStillRead',
    () async {
      File(track).writeAsBytesSync(
        taggedFlac(tags: {'LYRICS': '[00:05.00]From the tags\n'}),
      );
      writeSidecar('   \n');

      final lyrics = await source.of(track);

      expect(lyrics!.lines.single.text, 'From the tags');
    },
  );

  test(
    'GivenATrackWhoseTagCarriesSyncedLyrics_WhenTheyAreAskedFor_ThenTheyComeBackTimed',
    () async {
      // The frame the ordinary tag reader does not surface: this is read out
      // of the file's own header instead.
      final tagged = p.join(music.path, 'tagged.mp3');
      File(tagged).writeAsBytesSync(
        id3Tag(
          frames: [
            syltFrame(
              entries: const [
                (at: Duration(seconds: 12), text: 'A timed line'),
              ],
            ),
          ],
          trailing: List.filled(256, 0x55),
        ),
      );

      final lyrics = await source.of(tagged);

      expect(lyrics!.isSynced, isTrue);
      expect(lyrics.lines.single.text, 'A timed line');
      expect(lyrics.lines.single.at, const Duration(seconds: 12));
    },
  );

  test(
    'GivenATagCarryingBothFrames_WhenTheWordsAreAskedFor_ThenTheTimedOneWins',
    () async {
      // A writer that fills both puts the timed copy in one and the readable
      // copy in the other, and the timed one is the point of this feature.
      final tagged = p.join(music.path, 'both.mp3');
      File(tagged).writeAsBytesSync(
        id3Tag(
          frames: [
            usltFrame('Plain words with no times'),
            syltFrame(
              entries: const [
                (at: Duration(seconds: 3), text: 'A timed line'),
              ],
            ),
          ],
        ),
      );

      final lyrics = await source.of(tagged);

      expect(lyrics!.isSynced, isTrue);
      expect(lyrics.lines.single.text, 'A timed line');
    },
  );

  test(
    'GivenBothASidecarAndASyncedFrame_WhenTheWordsAreAskedFor_ThenTheSidecarStillWins',
    () async {
      final tagged = p.join(music.path, 'sidecar-too.mp3');
      File(tagged).writeAsBytesSync(
        id3Tag(
          frames: [
            syltFrame(
              entries: const [
                (at: Duration(seconds: 3), text: 'From the frame'),
              ],
            ),
          ],
        ),
      );
      File(p.join(music.path, 'sidecar-too.lrc'))
          .writeAsStringSync('[00:03.00]From beside the track\n');

      final lyrics = await source.of(tagged);

      expect(lyrics!.lines.single.text, 'From beside the track');
    },
  );

  test(
    'GivenATrackWithNoWordsAnywhere_WhenTheyAreAskedFor_ThenThereAreNone',
    () async {
      expect(await source.of(track), isNull);
    },
  );

  test(
    'GivenAFileWhoseTagsWillNotParse_WhenItsWordsAreAskedFor_ThenNothingIsThrown',
    () async {
      // The same judgement the scanner makes: a file this reader cannot open
      // is very often one that plays perfectly well, and it is certainly not
      // one to interrupt playback over.
      final broken = p.join(music.path, 'broken.flac');
      File(broken).writeAsBytesSync(List.filled(512, 7));

      expect(await source.of(broken), isNull);
    },
  );

  test(
    'GivenATrackThatIsNoLongerOnDisk_WhenItsWordsAreAskedFor_ThenThereAreNone',
    () async {
      expect(await source.of(p.join(music.path, 'gone.flac')), isNull);
    },
  );
}
