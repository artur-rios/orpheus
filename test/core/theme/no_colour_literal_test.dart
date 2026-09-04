import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Colours come from the theme, and from nowhere else.
///
/// A rule nobody checks is a comment. This is the check: every colour in this
/// application is derived from one seed in `lib/core/theme/`, which is what
/// keeps the light and dark screens recognisably the same product — and what
/// makes changing the palette one edit rather than a search.
void main() {
  test(
    'GivenTheWholeApplication_WhenItIsScannedForColourLiterals_ThenTheyExistOnlyInTheThemeItself',
    () {
      final offenders = <String>[];

      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;

        // Compared with forward slashes whatever the platform walks with.
        // Windows yields `lib\core\theme\app_theme.dart`, which matches
        // neither exclusion below as written — so this guard used to fail on
        // the theme's own seed there, and would have skipped nothing in the
        // generated catalogs either.
        final path = entity.path.replaceAll(r'\', '/');

        // The theme is where the seed lives, and the generated catalogs are
        // not hand-written.
        if (path.startsWith('lib/core/theme/')) continue;
        if (path.contains('l10n/generated/')) continue;

        final lines = entity.readAsLinesSync();
        for (final (index, line) in lines.indexed) {
          if (_colourLiteral.hasMatch(line)) {
            offenders.add('$path:${index + 1}: ${line.trim()}');
          }
        }
      }

      expect(offenders, isEmpty, reason: offenders.join('\n'));
    },
  );
}

/// A constructed colour, or one of the named constants that hardcodes one.
final RegExp _colourLiteral = RegExp(
  r'\bColor\(0x|\bColors\.[a-z]|\bColor\.fromARGB\(|\bColor\.fromRGBO\(',
);
