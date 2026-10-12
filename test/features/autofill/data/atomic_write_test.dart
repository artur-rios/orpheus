import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/autofill/data/atomic_write.dart';
import 'package:path/path.dart' as p;

/// Replacing a file whole, or not at all.
void main() {
  late Directory root;

  setUp(() async => root = await Directory.systemTemp.createTemp('orpheus-atomic'));
  tearDown(() async {
    if (root.existsSync()) await root.delete(recursive: true);
  });

  List<String> namesIn(Directory directory) =>
      [for (final entity in directory.listSync()) p.basename(entity.path)]..sort();

  test('GivenAFile_WhenReplacedAtomically_ThenItHoldsTheNewBytesAndNoTemporaryFileRemains', () {
    final path = p.join(root.path, 'a.flac');
    File(path).writeAsBytesSync([1, 2, 3]);

    replaceFileAtomically(path, Uint8List.fromList([4, 5, 6, 7]));

    expect(File(path).readAsBytesSync(), [4, 5, 6, 7]);
    expect(namesIn(root), ['a.flac']);
  });

  test('GivenATargetTheRenameCannotReplace_WhenReplacedAtomically_ThenItThrowsAndLeavesItAndNoTemporaryFile', () {
    // A directory where the file should be: the temporary file is written,
    // and the rename over the target is what fails.
    final path = p.join(root.path, 'a.flac');
    Directory(path).createSync();
    File(p.join(path, 'inside')).writeAsBytesSync([1]);

    expect(
      () => replaceFileAtomically(path, Uint8List.fromList([4, 5, 6])),
      throwsA(isA<FileSystemException>()),
    );

    expect(Directory(path).existsSync(), isTrue);
    expect(File(p.join(path, 'inside')).readAsBytesSync(), [1]);
    expect(namesIn(root), ['a.flac']);
  });

  test('GivenAPlainFile_WhenItsTargetIsResolved_ThenItIsThatPathUnchanged', () {
    final path = p.join(root.path, 'a.flac');
    File(path).writeAsBytesSync([1]);

    expect(resolvedTarget(path), path);
  });

  test('GivenNothingAtThePath_WhenItsTargetIsResolved_ThenItIsThatPathUnchanged', () {
    final path = p.join(root.path, 'gone.flac');

    expect(resolvedTarget(path), path);
  });

  test('GivenASymbolicLink_WhenItsTargetIsResolved_ThenItIsTheFileItPointsAt', () {
    final target = p.join(root.path, 'real.flac');
    File(target).writeAsBytesSync([1]);
    final link = Link(p.join(root.path, 'a.flac'))..createSync(target);

    expect(FileSystemEntity.identicalSync(resolvedTarget(link.path), target), isTrue);
    expect(FileSystemEntity.isLinkSync(resolvedTarget(link.path)), isFalse);
  }, skip: _noLinks);

  test('GivenASymbolicLink_WhenReplacedAtomically_ThenTheFileItPointsAtIsReplacedAndTheLinkKept', () {
    final target = p.join(root.path, 'real.flac');
    File(target).writeAsBytesSync([1, 2, 3]);
    final link = Link(p.join(root.path, 'a.flac'))..createSync(target);

    replaceFileAtomically(link.path, Uint8List.fromList([4, 5, 6]));

    expect(FileSystemEntity.isLinkSync(link.path), isTrue);
    expect(File(target).readAsBytesSync(), [4, 5, 6]);
    expect(File(link.path).readAsBytesSync(), [4, 5, 6]);
    expect(namesIn(root), ['a.flac', 'real.flac']);
  }, skip: _noLinks);

  test('GivenALinkToNothing_WhenReplacedAtomically_ThenItThrowsAndCreatesNothing', () {
    final link = Link(p.join(root.path, 'a.flac'))..createSync(p.join(root.path, 'gone.flac'));

    expect(
      () => replaceFileAtomically(link.path, Uint8List.fromList([4, 5, 6])),
      throwsA(isA<FileSystemException>()),
    );

    expect(namesIn(root), ['a.flac']);
    expect(FileSystemEntity.isLinkSync(link.path), isTrue);
  }, skip: _noLinks);

  test('GivenAReadOnlyFile_WhenReplacedAtomically_ThenItIsRefusedAndLeftAsItWas', () {
    final path = p.join(root.path, 'a.flac');
    File(path).writeAsBytesSync([1, 2, 3]);
    final marked = Platform.isWindows
        ? Process.runSync('attrib', ['+R', path])
        : Process.runSync('chmod', ['444', path]);
    expect(marked.exitCode, 0);
    addTearDown(
      () => Platform.isWindows ? Process.runSync('attrib', ['-R', path]) : Process.runSync('chmod', ['644', path]),
    );

    expect(
      () => replaceFileAtomically(path, Uint8List.fromList([4, 5, 6])),
      throwsA(isA<FileSystemException>()),
    );

    expect(File(path).readAsBytesSync(), [1, 2, 3]);
    expect(namesIn(root), ['a.flac']);
  }, skip: _isRoot ? 'a superuser writes to read-only files' : null);
}

/// Why the symbolic-link tests are skipped, where they are: on Windows,
/// creating a link may need a privilege the test runner does not have.
final String? _noLinks = Platform.isWindows ? 'creating a symbolic link on Windows may need privileges' : null;

/// Whether this runs as root, which no file mode refuses.
final bool _isRoot = !Platform.isWindows && Platform.environment['USER'] == 'root';
