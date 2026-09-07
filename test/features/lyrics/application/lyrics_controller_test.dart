import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/core/di/providers.dart';
import 'package:orpheus/core/settings/in_memory_settings_store.dart';
import 'package:orpheus/features/lyrics/domain/lyrics.dart';
import 'package:orpheus/features/lyrics/domain/remote_lyrics_source.dart';

import '../../../support/entries.dart';
import '../../../support/test_container.dart';

/// Where a track's words come from, and in which order.
///
/// The ordering is the whole feature, and it is what these assert: this
/// machine's own files are asked first and always, a lookup happens only for
/// what they had nothing for, and only while the owner leaves it on. The
/// sheets here are invented lines with times attached.
void main() {
  const sheet = '[00:12.00]The first line\n[00:20.50]The second line\n';

  final found = RemoteLyrics(
    lyrics: Lyrics.synced(const [
      LyricLine(text: 'The first line', at: Duration(seconds: 12)),
    ]),
    text: sheet,
  );

  final library = [
    entry(
      id: '1',
      title: 'The Second Track',
      artist: 'A Band',
      album: 'A Record',
      duration: const Duration(minutes: 3, seconds: 20),
    ),
  ];

  final track = library.first.file.path;

  /// A harness whose library holds the one track, with the lookup on unless
  /// [fetches] says otherwise.
  Harness harnessWith({bool fetches = true}) => Harness(
    library: library,
    settings: InMemorySettingsStore(fetchesLyricsOnline: fetches),
  );

  Future<Lyrics?> wordsOf(Harness harness, String path) async {
    await harness.library();

    return harness.container.read(lyricsProvider(path).future);
  }

  test(
    'GivenThisMachineHasTheWords_WhenTheyAreAskedFor_ThenNothingIsAskedOfAnybody',
    () async {
      // The rule the rest of this depends on: the owner's own files decide,
      // and a track that has words is never the subject of a lookup.
      final harness = harnessWith();
      harness.lyrics.seed(track, Lyrics.plain(const ['A line from a tag']));

      final words = await wordsOf(harness, track);

      expect(words!.lines.first.text, 'A line from a tag');
      expect(harness.remoteLyrics.asked, isEmpty);
      expect(harness.sidecars.written, isEmpty);
    },
  );

  test(
    'GivenThisMachineHasNoWords_WhenTheyAreAskedFor_ThenTheyAreLookedUp',
    () async {
      final harness = harnessWith();
      harness.remoteLyrics.seed('The Second Track', found);

      final words = await wordsOf(harness, track);

      expect(words!.lines.first.text, 'The first line');
    },
  );

  test(
    'GivenATrackIsLookedUp_WhenTheQueryIsBuilt_ThenItCarriesTheTagsAndNotThePath',
    () async {
      // What leaves is what is printed on the sleeve. Not the file's name, not
      // its folder, not anything that says something about this machine.
      final harness = harnessWith();

      await wordsOf(harness, track);

      expect(
        harness.remoteLyrics.asked.single,
        const LyricsQuery(
          title: 'The Second Track',
          artist: 'A Band',
          album: 'A Record',
          duration: Duration(minutes: 3, seconds: 20),
        ),
      );
    },
  );

  test(
    'GivenASheetIsFound_WhenItLands_ThenItIsWrittenBesideTheTrackAsItArrived',
    () async {
      final harness = harnessWith();
      harness.remoteLyrics.seed('The Second Track', found);

      await wordsOf(harness, track);

      expect(harness.sidecars.written, {track: sheet});
    },
  );

  test(
    'GivenTheOwnerTurnedTheLookupOff_WhenWordsAreMissing_ThenNothingIsAsked',
    () async {
      final harness = harnessWith(fetches: false);
      harness.remoteLyrics.seed('The Second Track', found);

      final words = await wordsOf(harness, track);

      expect(words, isNull);
      expect(harness.remoteLyrics.asked, isEmpty);
    },
  );

  test(
    'GivenTheOwnerTurnedTheLookupOff_WhenTheTrackHasItsOwnWords_ThenTheyAreStillRead',
    () async {
      // The switch governs the lookup and nothing else. A `.lrc` and a lyrics
      // tag are read whatever it says.
      final harness = harnessWith(fetches: false);
      harness.lyrics.seed(track, Lyrics.plain(const ['A line from a tag']));

      final words = await wordsOf(harness, track);

      expect(words!.lines.first.text, 'A line from a tag');
    },
  );

  test(
    'GivenTheServiceKnowsNothing_WhenTheLookupComesBackEmpty_ThenThereAreNoWordsAndNothingIsWritten',
    () async {
      final harness = harnessWith();

      expect(await wordsOf(harness, track), isNull);
      expect(harness.sidecars.written, isEmpty);
    },
  );

  test(
    'GivenTheLookupFails_WhenItThrows_ThenThePanelIsToldThereAreNoWordsRatherThanAFailure',
    () async {
      // An unreachable network is not a fault the owner can do anything about,
      // and it leaves them exactly where a track with no words does.
      final harness = harnessWith();
      harness.remoteLyrics.fails = true;

      expect(await wordsOf(harness, track), isNull);
    },
  );

  test(
    'GivenTheSheetCannotBeWrittenBesideTheTrack_WhenItIsFound_ThenTheWordsAreStillShown',
    () async {
      // A read-only mount, and Android's sandbox, which refuses this on every
      // device. It costs the owner the lookup again next launch and nothing in
      // this session.
      final harness = harnessWith();
      harness.remoteLyrics.seed('The Second Track', found);
      harness.sidecars.refuses = true;

      final words = await wordsOf(harness, track);

      expect(words!.lines.first.text, 'The first line');
    },
  );

  test(
    'GivenATrackWithNoArtistTag_WhenItsWordsAreMissing_ThenNoLookupIsMade',
    () async {
      // A lookup on a title alone is a guess between every recording that
      // shares the name, and a file tagged that poorly is exactly the one
      // whose words would come back belonging to somebody else's song.
      final untagged = [entry(id: '2', title: 'The Second Track')];
      final harness = Harness(library: untagged);

      final words = await wordsOf(harness, untagged.first.file.path);

      expect(words, isNull);
      expect(harness.remoteLyrics.asked, isEmpty);
    },
  );

  test(
    'GivenATrackWithNoTitleTag_WhenItsWordsAreMissing_ThenNoLookupIsMade',
    () async {
      final untagged = [entry(id: '3', artist: 'A Band')];
      final harness = Harness(library: untagged);

      final words = await wordsOf(harness, untagged.first.file.path);

      expect(words, isNull);
      expect(harness.remoteLyrics.asked, isEmpty);
    },
  );

  test(
    'GivenATrackTheLibraryDoesNotHold_WhenItsWordsAreMissing_ThenNoLookupIsMade',
    () async {
      final harness = harnessWith();

      final words = await wordsOf(harness, '/library/never-scanned.flac');

      expect(words, isNull);
      expect(harness.remoteLyrics.asked, isEmpty);
    },
  );

  test(
    'GivenATrackWithHalfItsTags_WhenItIsLookedUp_ThenItIsStillAskedAbout',
    () async {
      // Half-tagged libraries are the norm rather than the exception.
      final sparse = [entry(id: '4', title: 'The Second Track', artist: 'A Band')];
      final harness = Harness(library: sparse);

      await wordsOf(harness, sparse.first.file.path);

      expect(
        harness.remoteLyrics.asked.single,
        const LyricsQuery(title: 'The Second Track', artist: 'A Band'),
      );
    },
  );

  test(
    'GivenTheLookupIsTurnedOn_WhenThePreferenceChanges_ThenTheWordsAreAskedForAgain',
    () async {
      // Turning it on is nearly always done in front of a panel that says
      // there are no lyrics for what is playing. Without the re-read, the
      // owner would have to skip the track and come back to find out whether
      // it worked.
      final harness = harnessWith(fetches: false);
      harness.remoteLyrics.seed('The Second Track', found);

      expect(await wordsOf(harness, track), isNull);

      await harness.container
          .read(preferencesControllerProvider.notifier)
          .setFetchesLyricsOnline(true);

      final words = await harness.container.read(
        lyricsProvider(track).future,
      );

      expect(words!.lines.first.text, 'The first line');
    },
  );
}
