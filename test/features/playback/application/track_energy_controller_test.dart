import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/core/di/providers.dart';
import 'package:orpheus/features/playback/domain/energy_store.dart';
import 'package:orpheus/features/playback/domain/track_energy.dart';
import 'package:path/path.dart' as p;

import '../../../support/fakes.dart';
import '../../../support/test_container.dart';

/// How a track's spectrum reaches the bars.
///
/// The rules this is about are the ones an owner would notice: a track is
/// analysed once and not again, a track that cannot be analysed still draws
/// bars, and nothing on this path ever leaves the screen without something to
/// show.
void main() {
  late Directory music;
  late String track;

  setUp(() {
    music = Directory.systemTemp.createTempSync('orpheus-energy');
    track = p.join(music.path, 'airbag.flac');
    File(track).writeAsBytesSync(Uint8List.fromList(List.filled(2048, 9)));
  });

  tearDown(() => music.deleteSync(recursive: true));

  /// A grid standing at [level] everywhere.
  MeasuredEnergy flat(int level) => MeasuredEnergy(
    levels: Uint8List.fromList(List.filled(64, level)),
    bands: TrackEnergy.defaultBands,
    frame: const Duration(milliseconds: 32),
  );

  /// The id [track] is cached under, as the controller works it out.
  String idOf(String path) {
    final stat = File(path).statSync();

    return energyIdOf(path: path, length: stat.size, modified: stat.modified);
  }

  test('GivenATrackThatHasNeverBeenPlayed_WhenTheBarsAskForIt_ThenItIsAnalysedAndKept', () async {
    final harness = Harness(
      analysis: ScriptedTrackAnalysis({track: flat(200)}),
    );

    final measured = await harness.container.read(
      measuredTrackEnergyProvider(track).future,
    );

    expect(measured, isNotNull);
    expect(harness.analysis.asked, [track]);
    expect(harness.energies.written, [idOf(track)]);
  });

  test('GivenATrackAlreadyAnalysed_WhenTheBarsAskForItAgain_ThenItIsNotDecodedTwice', () async {
    // The whole reason the analysis is cached: decoding a track takes a
    // second, and a queue that comes back to the same record would otherwise
    // spend it again every time.
    final harness = Harness();
    harness.energies.seed(idOf(track), flat(120));

    final measured = await harness.container.read(
      measuredTrackEnergyProvider(track).future,
    );

    expect(measured, isNotNull);
    expect(harness.analysis.asked, isEmpty);
  });

  test(
    'GivenATrackThatCouldNotBeAnalysed_WhenTheBarsAskForIt_ThenNothingIsCached',
    () async {
      // A format libmpv would not decode, or a decode that timed out. The bars
      // fall back, and nothing is written that would have to be invalidated.
      final harness = Harness();

      final measured = await harness.container.read(
        measuredTrackEnergyProvider(track).future,
      );

      expect(measured, isNull);
      expect(harness.energies.written, isEmpty);
    },
  );

  test(
    'GivenATrackThatIsNoLongerOnDisk_WhenTheBarsAskForIt_ThenNothingIsDecoded',
    () async {
      final harness = Harness();
      final gone = p.join(music.path, 'deleted.flac');

      final measured = await harness.container.read(
        measuredTrackEnergyProvider(gone).future,
      );

      expect(measured, isNull);
      expect(harness.analysis.asked, isEmpty);
    },
  );

  test('GivenAnAnalysisThatHasNotLandedYet_WhenTheBarsAreDrawn_ThenTheStandInIsWhatTheyShow', () async {
    final harness = Harness(
      analysis: ScriptedTrackAnalysis({track: flat(200)}),
    );

    // Held open across the await, because the bars themselves hold it open:
    // read and dropped, the analysis would be started again on the next look.
    final watch = harness.container.listen(
      trackEnergyProvider(track),
      (_, _) {},
    );
    addTearDown(watch.close);

    expect(watch.read(), isA<SynthesisedEnergy>());

    await harness.container.read(measuredTrackEnergyProvider(track).future);

    expect(watch.read(), isA<MeasuredEnergy>());
  });

  test('GivenATrackThatCouldNotBeAnalysed_WhenTheBarsAreDrawn_ThenTheyStillHaveSomethingToShow', () async {
    final harness = Harness();

    final watch = harness.container.listen(
      trackEnergyProvider(track),
      (_, _) {},
    );
    addTearDown(watch.close);

    await harness.container.read(measuredTrackEnergyProvider(track).future);

    expect(watch.read(), isA<SynthesisedEnergy>());
  });

  test(
    'GivenAnAnalysisThatCannotBeCached_WhenTheBarsAskForIt_ThenTheyStillGetIt',
    () async {
      // A full disk, or a cache directory that cannot be written. The cost is
      // one more analysis the next time this track is played, and the owner is
      // told nothing — there is nothing they would do about it.
      final harness = Harness(
        analysis: ScriptedTrackAnalysis({track: flat(200)}),
      );
      harness.energies.failOnPut = true;

      final measured = await harness.container.read(
        measuredTrackEnergyProvider(track).future,
      );

      expect(measured, isNotNull);
      expect(harness.energies.written, isEmpty);
    },
  );

  test('GivenATrackReplacedByADifferentRip_WhenTheBarsAskForIt_ThenTheOldSpectrumIsNotUsed', () async {
    // Same path, different file. The cache key carries the length and the
    // modification time so that the bars do not draw the previous rip's
    // spectrum over the new one.
    final before = idOf(track);
    File(track).writeAsBytesSync(Uint8List.fromList(List.filled(4096, 1)));

    expect(idOf(track), isNot(before));
  });
}
