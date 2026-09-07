import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orpheus/core/l10n/generated/app_localizations.dart';
import 'package:orpheus/features/playback/domain/playback_queue.dart';
import 'package:orpheus/features/playback/presentation/music_display_name.dart';

import '../../../support/entries.dart';

/// What a queue is called on the bar and at the top of the player.
///
/// The rule these cover used to be stated twice — once here and once as a
/// `namesOwnRecord` getter on the queue that nothing in the application ever
/// read. This is the copy that is actually rendered.
void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  final tracks = [file('1'), file('2')];

  PlaybackQueue queue(QueueKind kind, {String? label}) =>
      PlaybackQueue(tracks: tracks, kind: kind, label: label);

  test(
    'GivenAnAlbumOrArtistQueue_WhenItIsNamed_ThenItNamesTheRecordItself',
    () {
      // An album or artist queue *is* a record: every track in it belongs to
      // the same one, so the bar keeps naming the queue as it plays through.
      expect(queueLabelOf(queue(QueueKind.album, label: 'OK'), l10n), 'OK');
      expect(
        queueLabelOf(queue(QueueKind.artist, label: 'Radiohead'), l10n),
        'Radiohead',
      );
    },
  );

  test(
    'GivenAnAlbumOrArtistQueueWhoseTagNamesNothing_WhenItIsNamed_ThenTheAbsenceGetsItsOwnWord',
    () {
      expect(
        queueLabelOf(queue(QueueKind.album), l10n),
        l10n.musicUnknownAlbum,
      );
      expect(
        queueLabelOf(queue(QueueKind.artist), l10n),
        l10n.musicUnknownArtist,
      );
    },
  );

  test(
    'GivenATrackQueue_WhenItIsNamed_ThenNothingIsSaidBesideTheTracksOwnTitle',
    () {
      // The bar and the player already show the track's own title next to
      // this, so a label here would repeat it.
      expect(queueLabelOf(queue(QueueKind.track), l10n), isNull);
    },
  );

  test(
    'GivenAShuffleEverythingQueue_WhenItIsNamed_ThenItsOwnPhraseIsShownAsWritten',
    () {
      // A playlist's label is not a tag — this application wrote it — so there
      // is no Unknown word behind it, and a queue with none is named by
      // whatever is playing instead.
      expect(
        queueLabelOf(queue(QueueKind.playlist, label: 'Everything'), l10n),
        'Everything',
      );
      expect(queueLabelOf(queue(QueueKind.playlist), l10n), isNull);
      expect(queueLabelOf(queue(QueueKind.playlist, label: '   '), l10n), isNull);
    },
  );
}
