import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../../core/di/providers.dart';
import '../../library/domain/music_catalog.dart';
import '../../library/domain/music_grouping.dart';
import '../../playlists/domain/playlist.dart';
import '../../stats/domain/play_history.dart';
import '../../updates/application/update_controller.dart';
import '../domain/data_export.dart';

final Logger _log = Logger('data-export');

/// The owner's data as the controllers that hold it have it, ready to be made
/// into step 6's document: what the JSON export and the backup ZIP both start
/// from.
///
/// Waited for rather than read as it stands: an export made while a source is
/// still loading would present an empty section as the owner's data. A source
/// that cannot be read stands in as nothing and a problem saying why, so the
/// document says its section is empty for that reason.
///
/// `null` when the library itself could not be read: there is then nothing
/// meaningful to export, and nothing should be offered.
///
/// **Only reads.**
Future<ExportSources?> gatherExportSources(Ref ref) async {
  final catalog = await _libraryOrNull(ref);
  if (catalog == null) return null;

  final problems = <ExportProblem>[];
  // A catalog another version wrote reads as empty until the scan the upgrade
  // owes has refilled it, and an export made in that window would present the
  // empty library as the owner's data.
  if (catalog.isStale) {
    problems.add(
      const ExportProblem(
        'songs',
        'The library is being rebuilt, so no songs are listed',
      ),
    );
  }
  final playlists = await _playlists(ref, problems);
  final history = await _history(ref, problems);

  return ExportSources(
    songs: songsIn(catalog.entries),
    playlists: playlists,
    history: history,
    now: ref.read(clockProvider)(),
    orpheusVersion: ref.read(runningVersionProvider)?.toString(),
    problems: problems,
  );
}

/// `<yyyy>-<MM>-<dd>` on the owner's calendar rather than UTC's: the date on a
/// file is the day they pressed the button.
String exportDateStamp(DateTime now) {
  final local = now.toLocal();
  final year = local.year.toString().padLeft(4, '0');
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');

  return '$year-$month-$day';
}

/// The library once it has loaded, or `null` when it could not be.
Future<MusicCatalog?> _libraryOrNull(Ref ref) async {
  try {
    return await ref.read(musicLibraryControllerProvider.future);
  } on Object catch (error) {
    _log.warning('the library could not be read for the export', error);

    return null;
  }
}

/// The playlists, or none and a problem saying why when they cannot be read.
Future<List<Playlist>> _playlists(Ref ref, List<ExportProblem> problems) async {
  try {
    return await ref.read(playlistsControllerProvider.future);
  } on Object catch (error) {
    _log.warning('the playlists could not be read for the export', error);
    problems.add(
      ExportProblem('playlists', 'The playlists could not be read: $error'),
    );

    return const [];
  }
}

/// The play history, or none and a problem saying why when it could not be
/// read.
///
/// The recorder does not fail on an unreadable store: it answers an empty
/// history and remembers that it could not read it, which is what is asked
/// after the history has been waited for.
Future<PlayHistory> _history(Ref ref, List<ExportProblem> problems) async {
  try {
    final history = await ref.read(playHistoryProvider.future);
    if (!ref.read(playRecorderProvider).readFailed) return history;
  } on Object catch (error) {
    _log.warning('the play history could not be read for the export', error);
  }

  problems.add(
    const ExportProblem(
      'playHistory',
      'The play history could not be read, so no plays are listed',
    ),
  );

  return PlayHistory.empty;
}
