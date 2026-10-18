import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../library/domain/music_entry.dart';
import '../application/music_navigator.dart';

/// Which navigator the music rows below steer, and what they play from.
///
/// Handed down rather than passed to every row: a row is three or four
/// widgets below the browser that draws it, and the lists, the tiles and the
/// track menus would otherwise each grow two parameters they only forward.
/// Where there is no scope — the Music tab — the rows steer the Music tab's
/// own place and play from the whole library, exactly as they always have.
class MusicScope extends InheritedWidget {
  /// Creates a scope over [child].
  const MusicScope({
    required this.navigator,
    required this.within,
    required super.child,
    super.key,
  });

  /// What a row's drill moves.
  final MusicNavigator navigator;

  /// What a row's "play the album" or "play the artist" gathers its queue
  /// from.
  ///
  /// The part of the library the screen is showing: under Rock, playing an
  /// artist plays their Rock records, not everything they ever made — the
  /// queue is what the owner was looking at when they pressed play.
  final List<MusicEntry> within;

  /// The nearest scope above [context], or `null` where there is none.
  static MusicScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MusicScope>();

  @override
  bool updateShouldNotify(MusicScope oldWidget) =>
      navigator != oldWidget.navigator || within != oldWidget.within;
}

/// The navigator a music row at [context] steers: the scope's, or the Music
/// tab's own where there is no scope.
MusicNavigator musicNavigatorOf(BuildContext context, WidgetRef ref) =>
    MusicScope.maybeOf(context)?.navigator ??
    ref.read(musicBrowseControllerProvider.notifier);

/// What a music row at [context] plays an album or an artist from: the
/// scope's part of the library, or `null` — the whole library — where there
/// is no scope.
List<MusicEntry>? musicWithinOf(BuildContext context) =>
    MusicScope.maybeOf(context)?.within;
