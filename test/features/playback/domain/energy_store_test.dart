import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/playback/domain/energy_store.dart';

/// The id a track's analysed spectrum is cached under.
///
/// The same file must find its analysis again in the next run, and a file
/// replaced at the same path must not find the old one's.
void main() {
  final modified = DateTime.utc(2026, 1, 1);

  String idOf({
    String path = '/music/a.flac',
    int length = 1024,
    DateTime? at,
  }) => energyIdOf(path: path, length: length, modified: at ?? modified);

  test(
    'GivenAPathALengthAndATime_WhenTheIdIsTaken_ThenItIsTheirFnv1aHash',
    () {
      // FNV-1a over "/music/a.flac 1024 0".
      expect(
        energyIdOf(
          path: '/music/a.flac',
          length: 1024,
          modified: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        ),
        'fcf97f89f03fd09a',
      );
    },
  );

  test('GivenTheSameFile_WhenTheIdIsTakenTwice_ThenItIsTheSame', () {
    expect(idOf(), idOf());
    expect(idOf(), matches(RegExp(r'^[0-9a-f]{16}$')));
  });

  test(
    'GivenTheFileReplacedByOneOfAnotherLength_WhenTheIdIsTaken_ThenItDiffers',
    () {
      expect(idOf(length: 2048), isNot(idOf()));
    },
  );

  test(
    'GivenTheFileRewrittenLater_WhenTheIdIsTaken_ThenItDiffers',
    () {
      expect(idOf(at: modified.add(const Duration(seconds: 1))), isNot(idOf()));
    },
  );

  test('GivenAnotherPath_WhenTheIdIsTaken_ThenItDiffers', () {
    expect(idOf(path: '/music/b.flac'), isNot(idOf()));
  });
}
