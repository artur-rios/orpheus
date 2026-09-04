import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/playback/data/file_energy_store.dart';
import 'package:orpheus/features/playback/domain/track_energy.dart';
import 'package:path/path.dart' as p;

/// Where analysed spectra are kept between runs.
///
/// A cache, and everything asserted here follows from that: what goes in comes
/// back, what was never put in is absent rather than an error, and a file that
/// is not one of ours is treated as absent too — because the answer to all
/// three is the same, which is to analyse the track again.
void main() {
  late Directory support;
  late FileEnergyStore store;

  setUp(() {
    support = Directory.systemTemp.createTempSync('orpheus-energy-store');
    store = FileEnergyStore(p.join(support.path, 'energy'));
  });

  tearDown(() => support.deleteSync(recursive: true));

  MeasuredEnergy grid() => MeasuredEnergy(
    levels: Uint8List.fromList(List.generate(96, (at) => at % 256)),
    bands: 16,
    frame: const Duration(milliseconds: 32),
  );

  test(
    'GivenAnAnalysis_WhenItIsStoredAndReadBack_ThenItIsTheSameGrid',
    () async {
      await store.put('airbag', grid());

      final read = await store.read('airbag');

      expect(read, isNotNull);
      expect(read!.levels, grid().levels);
      expect(read.bands, 16);
      expect(read.frame, const Duration(milliseconds: 32));
    },
  );

  test(
    'GivenATrackNeverAnalysed_WhenItIsAskedFor_ThenNothingComesBackRatherThanAnError',
    () => expect(store.read('never-seen'), completion(isNull)),
  );

  test(
    'GivenAFileTheStoreDidNotWrite_WhenItIsAskedFor_ThenNothingComesBack',
    () async {
      // A cache file from an older version of this application, which is what
      // the layout version in the header exists to catch.
      await store.put('airbag', grid());
      File(store.pathFor('airbag')).writeAsBytesSync(Uint8List(80));

      expect(await store.read('airbag'), isNull);
    },
  );

  test(
    'GivenStoredAnalyses_WhenTheStoreIsCleared_ThenNoneOfThemRemain',
    () async {
      await store.put('airbag', grid());

      await store.clear();

      expect(await store.read('airbag'), isNull);
      expect(Directory(store.directory).existsSync(), isFalse);
    },
  );

  test('GivenTheSameTrackAnalysedTwice_WhenTheSecondIsStored_ThenItReplacesTheFirst', () async {
    await store.put('airbag', grid());
    await store.put(
      'airbag',
      MeasuredEnergy(
        levels: Uint8List.fromList(List.filled(32, 7)),
        bands: 16,
        frame: const Duration(milliseconds: 32),
      ),
    );

    expect((await store.read('airbag'))!.frames, 2);
  });
}
