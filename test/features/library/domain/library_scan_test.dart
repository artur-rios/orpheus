import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/library/domain/library_scan.dart';

/// How far a scan has got, as the progress bar draws it.
void main() {
  test(
    'GivenAScanStillWalkingTheFolders_WhenItsFractionIsAsked_ThenThereIsNone',
    () {
      const progress = ScanProgress(filesFound: 10, filesRead: 5);

      expect(progress.fraction, isNull);
    },
  );

  test(
    'GivenAWalkThatFoundNothing_WhenItsFractionIsAsked_ThenThereIsNone',
    () {
      const progress = ScanProgress(walking: false);

      expect(progress.fraction, isNull);
    },
  );

  for (final (label, read, fraction) in [
    ('NoneRead', 0, 0.0),
    ('HalfRead', 5, 0.5),
    ('AllRead', 10, 1.0),
    ('MoreReadThanFound', 12, 1.0),
  ]) {
    test(
      'GivenTenFilesFoundAnd${label}_WhenItsFractionIsAsked_ThenItIs$fraction',
      () {
        final progress = ScanProgress(
          filesFound: 10,
          filesRead: read,
          walking: false,
        );

        expect(progress.fraction, fraction);
      },
    );
  }
}
