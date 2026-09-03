
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';

/// A record's sleeve, or the glyph that stands in for one.
///
/// One widget for every place a sleeve appears — a row, a tile, the bar, the
/// full player — because they are the same picture at four sizes, and four
/// widgets drawing it would be four chances for a record to look like a
/// different record depending on where it was seen.
///
/// The picture is read from the cover store, which the scan already filled: it
/// is never fetched over a network and never parsed out of the audio file
/// while a list is scrolling.
class AlbumArt extends ConsumerWidget {
  /// Creates a sleeve for [coverId], which is `null` for a record no picture
  /// was found for.
  const AlbumArt({
    required this.coverId,
    required this.side,
    this.radius,
    super.key,
  });

  /// The picture in the cover store, or `null`.
  final String? coverId;

  /// How wide and tall the square is.
  final double side;

  /// The corner radius, defaulting to one proportional to [side] — so that the
  /// forty-pixel sleeve in a row and the four-hundred-pixel one on the player
  /// are recognisably the same shape.
  final double? radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final corner = BorderRadius.circular(radius ?? side * 0.08);

    final id = coverId;
    final image = id == null
        ? null
        : ref.watch(albumArtControllerProvider(id)).value;

    return Semantics(
      label: l10n.albumCoverLabel,
      image: true,
      child: ClipRRect(
        borderRadius: corner,
        child: SizedBox.square(
          dimension: side,
          child: image == null
              ? _Placeholder(side: side)
              : RawImage(image: image, fit: BoxFit.cover),
        ),
      ),
    );
  }
}

/// What stands in for a sleeve that is not there, or has not decoded yet.
class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.side});

  final double side;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.album_outlined,
        size: side * 0.42,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// A sleeve with a shadow under it, for the full player.
///
/// The one flourish on that screen, and it earns its place: a sleeve lying
/// flat on the surface reads as a swatch, where a sleeve with a shadow under
/// it reads as an object being held up to be looked at.
class RaisedAlbumArt extends StatelessWidget {
  /// Creates the sleeve.
  const RaisedAlbumArt({required this.coverId, required this.side, super.key});

  /// The picture in the cover store, or `null`.
  final String? coverId;

  /// How wide and tall the square is.
  final double side;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.md),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.28),
            blurRadius: side * 0.10,
            offset: Offset(0, side * 0.035),
          ),
        ],
      ),
      child: AlbumArt(coverId: coverId, side: side, radius: AppSpacing.md),
    );
  }
}
