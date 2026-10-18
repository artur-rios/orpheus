import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/features/library/domain/music_entry.dart';
import 'package:orpheus/features/playback/presentation/album_art.dart';
import 'package:orpheus/features/playlists/domain/playlist.dart';
import 'package:orpheus/features/playlists/presentation/playlist_cover.dart';

import '../../../support/entries.dart';
import '../../../support/fake_playlists.dart';
import '../../../support/pump.dart';
import '../../../support/test_container.dart';

/// A playlist's picture: the owner's own, or a mosaic of its records.
void main() {
  final made = DateTime.utc(2026, 1, 1);

  // Five records, each with its own sleeve, so that a mosaic of four has one
  // left over to leave out.
  final songs = [
    for (var i = 1; i <= 5; i++)
      entry(
        id: '$i',
        title: 'Song $i',
        artist: 'Artist',
        album: 'Record $i',
        coverId: 'cover-$i',
      ),
  ];

  Playlist playlistOf(List<MusicEntry> entries, {String? coverId}) => Playlist(
    id: 'p1',
    name: 'Road trip',
    entries: [
      for (final (index, song) in entries.indexed)
        PlaylistEntry(id: 'e$index', path: song.file.path),
    ],
    coverId: coverId,
    createdAt: made,
    modifiedAt: made,
  );

  Future<void> show(
    WidgetTester tester,
    Harness harness,
    Playlist playlist,
  ) async {
    await tester.pumpHarness(
      harness,
      Scaffold(
        body: Center(child: PlaylistCover(playlist: playlist, side: 120)),
      ),
    );
  }

  List<String?> sleevesShown(WidgetTester tester) => [
    for (final art in tester.widgetList<AlbumArt>(find.byType(AlbumArt)))
      art.coverId,
  ];

  testWidgets(
    'GivenAPlaylistOfFiveRecords_WhenItsCoverIsDrawn_ThenItIsAMosaicOfTheFirstFour',
    (tester) async {
      await show(tester, Harness(library: songs), playlistOf(songs));

      expect(sleevesShown(tester), [
        'cover-1',
        'cover-2',
        'cover-3',
        'cover-4',
      ]);
      // Each a quarter of the square.
      expect(tester.getSize(find.byType(AlbumArt).first), const Size(60, 60));
    },
  );

  testWidgets(
    'GivenAPlaylistOfOneRecord_WhenItsCoverIsDrawn_ThenItIsThatSleeveAlone',
    (tester) async {
      await show(
        tester,
        Harness(library: songs),
        playlistOf([songs.first, songs.first]),
      );

      expect(sleevesShown(tester), ['cover-1']);
      expect(tester.getSize(find.byType(AlbumArt)), const Size(120, 120));
    },
  );

  testWidgets(
    'GivenAPlaylistWithNoSleeves_WhenItsCoverIsDrawn_ThenItIsThePlaceholder',
    (tester) async {
      await show(tester, Harness(library: songs), playlistOf(const []));

      expect(find.byType(AlbumArt), findsNothing);
      expect(find.byIcon(Icons.playlist_play), findsOneWidget);
    },
  );

  testWidgets(
    'GivenACustomCover_WhenTheCoverIsDrawn_ThenItIsThePictureNotTheMosaic',
    (tester) async {
      final harness = Harness(library: songs);
      final png = base64Decode(onePixelPng);
      harness.playlistCovers.covers['p1'] = png;

      await show(tester, harness, playlistOf(songs, coverId: 'p1'));

      expect(find.byType(AlbumArt), findsNothing);
      final image = tester.widget<Image>(
        find.descendant(
          of: find.byType(PlaylistCover),
          matching: find.byType(Image),
        ),
      );
      expect((image.image as MemoryImage).bytes, png);
    },
  );

  testWidgets(
    'GivenACustomCoverWhoseFileIsGone_WhenTheCoverIsDrawn_ThenTheMosaicStandsIn',
    (tester) async {
      await show(
        tester,
        Harness(library: songs),
        playlistOf(songs, coverId: 'p1'),
      );

      expect(sleevesShown(tester), hasLength(4));
    },
  );
}
