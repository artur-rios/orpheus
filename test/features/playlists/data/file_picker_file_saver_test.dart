import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/playlists/data/file_picker_file_saver.dart';
import 'package:path/path.dart' as p;

/// The names offered to the platform's save dialog, and what is said about
/// where the file went.
void main() {
  test('GivenAFileLocation_WhenSaved_ThenItsPathIsKnown', () {
    final path = p.join(Directory.systemTemp.path, 'Road trip.m3u');

    expect(savedFileAt(Uri.file(path)).path, path);
  });

  test('GivenADocumentProviderLocation_WhenSaved_ThenNoPathIsGiven', () {
    final location = Uri.parse(
      'content://com.android.providers.downloads.documents/document/42',
    );

    expect(savedFileAt(location).path, isNull);
  });

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
