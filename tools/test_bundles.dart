// Writes the suite into a few test files, each of which imports a share of
// the suite's files and runs every one of them in a group named after it.
//
//     dart run tools/test_bundles.dart [<directory>] [<bundles>]
//
// The defaults are build/test-bundles and 4. tools/verify.sh and
// tools/verify.ps1 run the suite through these files rather than one test
// file at a time, because `flutter test` compiles its files one after the
// other on a single compiler, whatever --concurrency says: with one entry
// point per test file, most of a run was spent compiling. A bundle is
// compiled once and runs its share of the suite in one process, and the
// bundles run side by side.
//
// What a bundle gives up is the process per file: the files of a bundle share
// an isolate. Nothing in the suite may depend on running alone, so this is
// also a check that no test leaks into the next. `flutter test` on its own
// still runs each file in its own process, which is the loop for one area.
//
// The files are shared out by size, largest first, onto the lightest bundle,
// so the bundles finish at about the same time. The directory is emptied and
// rewritten on every run; it lives under build/, which is not committed and
// not analysed.
import 'dart:io';

import 'package:path/path.dart' as p;

/// Writes the bundles and prints the path of each.
void main(List<String> arguments) {
  final directory = Directory(
    arguments.isNotEmpty ? arguments[0] : p.join('build', 'test-bundles'),
  );
  final count = arguments.length > 1 ? int.tryParse(arguments[1]) : 4;
  if (count == null || count < 1) {
    stderr.writeln('tools/test_bundles.dart: the bundle count must be 1 or more');
    exitCode = 2;
    return;
  }

  final tests = Directory('test')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('_test.dart'))
      .toList()
    ..sort((a, b) => _posix(a.path).compareTo(_posix(b.path)));
  if (tests.isEmpty) {
    stderr.writeln('tools/test_bundles.dart: no test files under test/');
    exitCode = 1;
    return;
  }

  final sizes = {for (final file in tests) file: file.lengthSync()};
  final bundles = [for (var i = 0; i < count; i++) <File>[]];
  final weights = List<int>.filled(count, 0);
  for (final file in [...tests]
    ..sort((a, b) => sizes[b]!.compareTo(sizes[a]!))) {
    var lightest = 0;
    for (var i = 1; i < count; i++) {
      if (weights[i] < weights[lightest]) lightest = i;
    }
    bundles[lightest].add(file);
    weights[lightest] += sizes[file]!;
  }

  if (directory.existsSync()) directory.deleteSync(recursive: true);
  directory.createSync(recursive: true);

  for (var i = 0; i < count; i++) {
    final files = bundles[i]
      ..sort((a, b) => _posix(a.path).compareTo(_posix(b.path)));
    if (files.isEmpty) continue;

    final source = StringBuffer()
      ..writeln('// Written by tools/test_bundles.dart. Do not edit.')
      ..writeln("import 'package:flutter_test/flutter_test.dart';")
      ..writeln();
    for (final (index, file) in files.indexed) {
      final uri = _posix(p.relative(file.path, from: directory.path));
      source.writeln("import '$uri' as t$index;");
    }
    source
      ..writeln()
      ..writeln('void main() {');
    for (final (index, file) in files.indexed) {
      final name = _posix(p.relative(file.path, from: 'test'));
      source.writeln("  group('$name', t$index.main);");
    }
    source.writeln('}');

    final bundle = File(p.join(directory.path, 'bundle_${i}_test.dart'))
      ..writeAsStringSync(source.toString());
    stdout.writeln(_posix(bundle.path));
  }
}

/// [path] with forward slashes, as an import and a test name spell it.
String _posix(String path) => p.split(path).join('/');
