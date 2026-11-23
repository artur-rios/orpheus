import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/library/domain/cover_store.dart';

/// The id a cover is cached under: a hash of its bytes, the same on every
/// platform and in every release, so a cache written by one is read by the
/// next.
void main() {
  Uint8List bytesOf(String text) => Uint8List.fromList(utf8.encode(text));

  for (final (label, text, id) in [
    ('NoBytes', '', 'cbf29ce484222325-0'),
    ('TheLetterA', 'a', 'af63dc4c8601ec8c-1'),
    ('TheWordFoobar', 'foobar', '85944171f73967e8-6'),
  ]) {
    test(
      'Given${label}_WhenTheIdIsTaken_ThenItIsThe64BitFnv1aHashAndTheLength',
      () {
        expect(coverIdOf(bytesOf(text)), id);
      },
    );
  }

  test(
    'GivenAHashWithItsTopBitSet_WhenTheIdIsTaken_ThenItHasNoMinusSign',
    () {
      // 'a' hashes to 0xaf63…, whose top bit is set: a signed rendering of it
      // would start with a minus.
      expect(coverIdOf(bytesOf('a')), isNot(startsWith('-')));
      expect(coverIdOf(bytesOf('a')), matches(RegExp(r'^[0-9a-f]{16}-\d+$')));
    },
  );

  test(
    'GivenTwoPicturesThatDifferInOneByte_WhenTheirIdsAreTaken_ThenTheyDiffer',
    () {
      final first = Uint8List.fromList([1, 2, 3, 4]);
      final second = Uint8List.fromList([1, 2, 3, 5]);

      expect(coverIdOf(first), isNot(coverIdOf(second)));
      expect(coverIdOf(first), coverIdOf(Uint8List.fromList([1, 2, 3, 4])));
    },
  );
}
