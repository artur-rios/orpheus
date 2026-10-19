import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/data_export/domain/data_export.dart';
import 'package:orpheus/features/stats/domain/play_history.dart';

import '../../support/entries.dart';

/// The schema document says what the export writes.
///
/// The file is for people and for tools that know nothing of Orpheus's code, so
/// it is only worth having while it is true. Its field tables are prose, but
/// the order of the top-level keys is a list a test can hold it to.
void main() {
  /// The first fenced block after the heading [heading], one entry per line.
  List<String> blockUnder(String heading) {
    final lines = File('docs/data-export.md').readAsStringSync().split('\n');
    final start = lines.indexWhere((line) => line.trim() == heading);
    expect(start, isNonNegative, reason: 'docs/data-export.md has no $heading');

    final open = lines.indexWhere((line) => line.startsWith('```'), start);
    expect(open, isNonNegative, reason: 'no fenced block under $heading');

    final close = lines.indexWhere((line) => line.startsWith('```'), open + 1);
    expect(close, isNonNegative, reason: 'the block under $heading is open');

    return lines.sublist(open + 1, close);
  }

  final built = buildDataExport(
    ExportSources(
      songs: [entry(id: 'a', title: 'Alpha', artist: 'Ann')],
      playlists: const [],
      history: PlayHistory.empty,
      now: DateTime.utc(2026, 10, 18),
      orpheusVersion: '1.5.0',
    ),
  );

  test('GivenTheSchemaDocument_WhenItsTopLevelKeysAreRead_ThenTheyMatchTheBuiltDocument', () {
    final documented = [
      for (final line in blockUnder('## Top-level keys'))
        if (line.trim().isNotEmpty) line.trim(),
    ];

    expect(documented, built.keys.toList());
  });

  test('GivenTheSchemaDocumentsExample_WhenItIsParsed_ThenItIsAnExportInTheBuiltOrderAtTheCurrentVersion', () {
    final example =
        jsonDecode(blockUnder('## Example').join('\n')) as Map<String, Object?>;

    expect(example.keys.toList(), built.keys.toList());
    expect(example['format'], dataExportFormat);
    expect(example['formatVersion'], dataExportFormatVersion);
  });
}
