import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../application/media_session_controller.dart';

/// Keeps the media session supplied with the words it falls back to.
///
/// The one thing the session needs that only the widget tree has: the three
/// Unknown words come out of `AppLocalizations`, which is resolved from the
/// locale a `MaterialApp` settled on and is reachable only through a
/// `BuildContext`. Rather than teach the application layer to resolve a locale
/// a second time — a rule that would drift from the one the rest of the
/// interface reads by — the shell hands the words over and hands them over
/// again when the language changes.
///
/// It draws nothing. [child] is passed through untouched, and this widget's
/// whole contribution is the call in [didChangeDependencies] — which is where
/// a localization change surfaces, and which is why this is a stateful widget
/// rather than a line in somebody's `build`.
class MediaSessionNamesScope extends ConsumerStatefulWidget {
  /// Wraps [child].
  const MediaSessionNamesScope({required this.child, super.key});

  /// What is shown. Unchanged by this widget.
  final Widget child;

  @override
  ConsumerState<MediaSessionNamesScope> createState() =>
      _MediaSessionNamesScopeState();
}

class _MediaSessionNamesScopeState
    extends ConsumerState<MediaSessionNamesScope> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final l10n = AppLocalizations.of(context);
    ref
        .read(mediaSessionControllerProvider.notifier)
        .remember(
          MediaSessionNames(
            unknownTitle: l10n.musicUnknownTitle,
            unknownArtist: l10n.musicUnknownArtist,
            unknownAlbum: l10n.musicUnknownAlbum,
          ),
        );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
