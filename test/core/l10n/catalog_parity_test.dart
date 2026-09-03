import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Both languages stay complete.
///
/// A missing translation is a build failure, not a string that renders as its
/// key in front of an owner who chose the other language.
void main() {
  Map<String, dynamic> catalog(String name) =>
      jsonDecode(File('lib/core/l10n/$name').readAsStringSync())
          as Map<String, dynamic>;

  Set<String> messagesIn(Map<String, dynamic> arb) => {
    for (final key in arb.keys)
      if (!key.startsWith('@')) key,
  };

  test(
    'GivenTheEnglishCatalog_WhenItIsComparedWithThePortugueseOne_ThenNeitherHasAMessageTheOtherLacks',
    () {
      final english = messagesIn(catalog('app_en.arb'));
      final portuguese = messagesIn(catalog('app_pt.arb'));

      expect(
        english.difference(portuguese),
        isEmpty,
        reason: 'untranslated in pt',
      );
      expect(
        portuguese.difference(english),
        isEmpty,
        reason: 'left over in pt, with no English original',
      );
    },
  );

  test(
    'GivenTheTemplateCatalog_WhenEachMessageIsRead_ThenEveryOneCarriesADescription',
    () {
      // The description is what a translator works from, and gen_l10n is
      // configured to refuse a message without one — this is the same rule,
      // asserted where it reads as a rule rather than as a build flag.
      final english = catalog('app_en.arb');

      final undescribed = <String>[];
      for (final key in messagesIn(english)) {
        final meta = english['@$key'];
        if (meta is! Map<String, dynamic> || meta['description'] == null) {
          undescribed.add(key);
        }
      }

      expect(undescribed, isEmpty);
    },
  );

  test(
    'GivenAMessageWithPlaceholders_WhenTheTranslationIsRead_ThenItUsesTheSameOnes',
    () {
      // A translation that dropped a placeholder would render a sentence with
      // a hole in it, and one that invented a placeholder would throw.
      final english = catalog('app_en.arb');
      final portuguese = catalog('app_pt.arb');

      final mismatched = <String>[];
      for (final key in messagesIn(english)) {
        final placeholders = _placeholdersIn(english[key] as String);
        if (placeholders.difference(
              _placeholdersIn(portuguese[key] as String),
            ).isNotEmpty ||
            _placeholdersIn(
              portuguese[key] as String,
            ).difference(placeholders).isNotEmpty) {
          mismatched.add(key);
        }
      }

      expect(mismatched, isEmpty);
    },
  );
}

/// The placeholders in [message], and not the words inside a plural's own
/// branches.
///
/// A placeholder is `{name}` or `{name, plural, ...}`; `{No tracks}` inside a
/// plural branch is prose, and a naive brace match would read the first word of
/// every branch as a placeholder — which differs between languages by
/// definition, and would make this assertion fail on every correctly
/// translated plural.
Set<String> _placeholdersIn(String message) => {
  for (final match in RegExp(r'\{(\w+)\s*[,}]').allMatches(message))
    match.group(1)!,
};
