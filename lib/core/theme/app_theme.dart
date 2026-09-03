import 'package:flutter/material.dart';

import 'app_spacing.dart';

/// The light and dark themes, and the single source of colours, spacing and
/// typography for every screen.
///
/// Nothing outside this file declares a colour. Widgets read
/// `Theme.of(context).colorScheme`, and the guard test in
/// `test/core/theme/no_colour_literal_test.dart` is what keeps that true — a
/// prohibition nobody checks is a comment.
abstract final class AppTheme {
  /// The seed the two schemes are derived from.
  ///
  /// A single seed rather than a hand-built palette: Material 3 generates the
  /// tonal range for both brightnesses from it, which is what keeps the light
  /// and dark screens recognisably the same product.
  static const Color _seed = Color(0xFF4A6FA5);

  /// The light theme.
  static ThemeData get light => _build(Brightness.light);

  /// The dark theme.
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
    );

    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      // Comfortable rather than compact: this application is read at arm's
      // length on a desktop and at a phone's distance on Android, and the
      // dense defaults are too tight for either.
      visualDensity: VisualDensity.comfortable,

      cardTheme: CardThemeData(
        margin: const EdgeInsets.all(AppSpacing.sm),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
      ),
    );
  }
}
