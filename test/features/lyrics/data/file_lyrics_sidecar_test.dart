import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/lyrics/data/file_lyrics_sidecar.dart';
import 'package:orpheus/features/lyrics/data/file_lyrics_source.dart';
import 'package:path/path.dart' as p;

/// Writing a fetched sheet beside the track.
///
/// Against a temporary folder, because that is the whole of what this class
/// does. The rules it has to keep are the reason it has a test at all: it puts
/// one file in a folder it does not own, it never touches the track, it never
/// replaces a sheet somebody else wrote, and it reports a refusal rather than
/// throwing one. The sheets here are invented lines with times attached.
void main() {
  const sidecar = FileLyricsSidecar();
  const source = FileLyricsSource();
  const sheet = '[00:12.00]The first line\n[00:20.50]The second line\n';

  late Directory music;
  late String track;

  setUp(() {
    music = Directory.systemTemp.createTempSync('orpheus-sidecar');
    track = p.join(music.path, 'the-track.flac');
    File(track).writeAsStringSync('not really audio');
  });

  tearDown(() => music.deleteSync(recursive: true));

  File beside(String extension) =>
      File(p.join(music.path, 'the-track$extension'));

  test(
    'GivenATrackWithNoSheetBesideIt_WhenOneIsWritten_ThenItLandsAsTheLrcNextToIt',
    () async {
      expect(await sidecar.write(track, sheet), isTrue);

      expect(beside('.lrc').readAsStringSync(), sheet);
    },
  );

  test(
    'GivenASheetHasBeenWritten_WhenTheWordsAreAskedForAgain_ThenTheyAreReadFromDisk',
    () async {
      // The point of writing it at all: the next launch finds it locally and
      // asks nobody anything.
      await sidecar.write(track, sheet);

      final lyrics = await source.of(track);

      expect(lyrics!.isSynced, isTrue);
      expect(lyrics.lines.first.text, 'The first line');
    },
  );

  test(
    'GivenASheetIsWritten_WhenItLands_ThenTheTrackItselfIsUntouched',
    () async {
      final before = File(track).readAsBytesSync();

      await sidecar.write(track, sheet);

      expect(File(track).readAsBytesSync(), before);
    },
  );

  test(
    'GivenTheOwnerAlreadyWroteASheet_WhenAFetchedOneWouldLand_ThenTheirsIsKept',
    () async {
      const theirs = '[00:01.00]The line the owner wrote\n';
      beside('.lrc').writeAsStringSync(theirs);

      expect(await sidecar.write(track, sheet), isFalse);

      expect(beside('.lrc').readAsStringSync(), theirs);
    },
  );

  test(
    'GivenASheetSpeltInCapitals_WhenAFetchedOneWouldLand_ThenItIsNotWrittenTwice',
    () async {
      // The reader probes both spellings. Writing `.lrc` beside an existing
      // `.LRC` would leave two sheets for one track, and the reader would go
      // on preferring the other one.
      const theirs = '[00:01.00]The line the owner wrote\n';
      beside('.LRC').writeAsStringSync(theirs);

      expect(await sidecar.write(track, sheet), isFalse);

      // Counted, rather than asked for by name. Two of this project's three
      // targets have a case-insensitive file system, where `.lrc` and `.LRC`
      // are the same file and asking whether `.lrc` exists answers something
      // different than it does on the third. What has to hold everywhere is
      // that the folder still has one sheet in it and it is the owner's.
      expect(
        music
            .listSync()
            .map((entity) => p.basename(entity.path))
            .where((name) => name.toLowerCase().endsWith('.lrc')),
        ['the-track.LRC'],
      );
      expect(beside('.LRC').readAsStringSync(), theirs);
    },
  );

  test(
    'GivenAFolderThatCannotBeWrittenTo_WhenASheetWouldLand_ThenItIsRefusedNotThrown',
    () async {
      // A read-only mount, a share the owner can only read, and Android's
      // scoped storage all arrive here. None of them is a fault, and none of
      // them costs the owner the words in this session.
      final missing = p.join(music.path, 'gone', 'the-track.flac');

      expect(await sidecar.write(missing, sheet), isFalse);
    },
  );

  test(
    'GivenTheWriteFailsPartWayThrough_WhenItHasGivenUp_ThenNoWorkingFileIsLeftBehind',
    () async {
      // The sheet goes to a temporary file and is renamed into place, so that
      // a process killed mid-write leaves either no sidecar or a whole one.
      // This is the other half of that: a rename that cannot land must not
      // leave the temporary file in somebody's music folder. A directory
      // standing where the sidecar would go is the portable way to make the
      // rename fail — `File.existsSync` does not see a directory, so the write
      // gets as far as the rename before it is refused.
      Directory(p.join(music.path, 'the-track.lrc')).createSync();

      expect(await sidecar.write(track, sheet), isFalse);

      expect(
        music
            .listSync()
            .map((entity) => p.basename(entity.path))
            .where((name) => name.endsWith('.part')),
        isEmpty,
      );
    },
  );

  test(
    'GivenASheetWithAccentedWords_WhenItIsWrittenAndReadBack_ThenItSurvivesAsUtf8',
    () async {
      const accented = '[00:12.00]Uma canção\n';

      await sidecar.write(track, accented);

      expect((await source.of(track))!.lines.first.text, 'Uma canção');
    },
  );
}
