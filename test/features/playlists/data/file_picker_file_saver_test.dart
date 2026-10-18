import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/playlists/data/file_picker_file_saver.dart';

/// The names offered to the platform's save dialog.
void main() {
  test('GivenAPlainName_WhenMadeSafe_ThenItIsUnchanged', () {
    expect(safeFileName('Road trip.m3u'), 'Road trip.m3u');
  });

  test('GivenReservedCharacters_WhenMadeSafe_ThenEachBecomesAnUnderscore', () {
    expect(safeFileName('AC/DC.m3u'), 'AC_DC.m3u');
    expect(safeFileName('Rock: 70s?.m3u'), 'Rock_ 70s_.m3u');
    expect(safeFileName(r'<a>"b"\c|d*.m3u'), '_a__b__c_d_.m3u');
  });

  test('GivenControlCharacters_WhenMadeSafe_ThenEachBecomesAnUnderscore', () {
    expect(safeFileName('a\nb\tc\u0000d.m3u'), 'a_b_c_d.m3u');
  });

  test('GivenTrailingDotsAndSpaces_WhenMadeSafe_ThenTheyAreTrimmed', () {
    expect(safeFileName('Mix. . '), 'Mix');
    expect(safeFileName('  Mix.m3u'), 'Mix.m3u');
  });

  test('GivenNothingLeft_WhenMadeSafe_ThenItIsAnUnderscore', () {
    expect(safeFileName(' . '), '_');
    expect(safeFileName(''), '_');
  });
}
