import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/core/platform/host_platform.dart';
import 'package:orpheus/features/library/data/default_music_folders.dart';
import 'package:path/path.dart' as p;

/// The folders a first launch offers to add.
///
/// Only the ones that exist. The assertions are about the temporary home this
/// test builds, never about the whole list: a desktop's `XDG_MUSIC_DIR` is
/// read from the real environment, and a machine that sets it adds its own.
void main() {
  late Directory home;

  setUp(() {
    home = Directory.systemTemp.createTempSync('orpheus-home-');
  });

  tearDown(() {
    if (home.existsSync()) home.deleteSync(recursive: true);
  });

  test(
    'GivenADesktopHomeWithAMusicFolder_WhenTheOfferIsMade_ThenItIsOffered',
    () {
      Directory(p.join(home.path, 'Music')).createSync();

      final offered = defaultMusicFolders(platform: _Desktop(home.path));

      expect(offered, contains(p.normalize(p.join(home.path, 'Music'))));
    },
  );

  test(
    'GivenADesktopHomeWithNoMusicFolder_WhenTheOfferIsMade_ThenNothingInItIsOffered',
    () {
      final offered = defaultMusicFolders(platform: _Desktop(home.path));

      expect(offered.where((folder) => p.isWithin(home.path, folder)), isEmpty);
    },
  );

  test(
    'GivenAFileNamedMusicInTheHome_WhenTheOfferIsMade_ThenItIsNotOffered',
    () {
      File(p.join(home.path, 'Music')).writeAsStringSync('not a folder');

      final offered = defaultMusicFolders(platform: _Desktop(home.path));

      expect(offered.where((folder) => p.isWithin(home.path, folder)), isEmpty);
    },
  );

  test(
    'GivenAHostWithNoHomeDirectory_WhenTheOfferIsMade_ThenNoHomeFolderIsOffered',
    () {
      Directory(p.join(home.path, 'Music')).createSync();

      final offered = defaultMusicFolders(platform: const _Desktop(null));

      expect(offered.where((folder) => p.isWithin(home.path, folder)), isEmpty);
    },
  );

  test(
    'GivenAnyHost_WhenTheOfferIsMade_ThenEachFolderIsOfferedOnce',
    () {
      Directory(p.join(home.path, 'Music')).createSync();

      final offered = defaultMusicFolders(platform: _Desktop(home.path));

      expect(offered.toSet(), hasLength(offered.length));
    },
  );

  test(
    'GivenAnAndroidHost_WhenTheOfferIsMade_ThenOnlyItsSharedStorageIsConsidered',
    () {
      // The home is not where Android keeps music: none of it is offered,
      // however it is laid out.
      Directory(p.join(home.path, 'Music')).createSync();

      final offered = defaultMusicFolders(platform: _Android(home.path));

      expect(offered.where((folder) => p.isWithin(home.path, folder)), isEmpty);
      expect(
        offered,
        everyElement(
          anyOf(startsWith('/storage/emulated/0/'), startsWith('/sdcard/')),
        ),
      );
    },
  );
}

/// A desktop whose home is [homeDirectory], whatever the suite runs on.
class _Desktop extends HostPlatform {
  const _Desktop(this.homeDirectory);

  @override
  final String? homeDirectory;

  @override
  bool get isAndroid => false;
}

/// An Android device, whatever the suite runs on.
class _Android extends HostPlatform {
  const _Android(this.homeDirectory);

  @override
  final String? homeDirectory;

  @override
  bool get isAndroid => true;
}
