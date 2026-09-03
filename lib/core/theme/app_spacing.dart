/// The spacing scale every screen measures with.
///
/// A four-pixel base, because it divides the Material density steps cleanly
/// and keeps a rail, a list row, and a grid cell aligned to the same grid
/// without anyone reaching for an arbitrary number.
abstract final class AppSpacing {
  /// 4 — the base step. Gaps inside a single control.
  static const double xs = 4;

  /// 8 — between related controls.
  static const double sm = 8;

  /// 16 — the default gap, and the default screen padding.
  static const double md = 16;

  /// 24 — between groups within a screen.
  static const double lg = 24;

  /// 32 — between major regions.
  static const double xl = 32;

  /// 48 — around a centred empty or failure state.
  static const double xxl = 48;
}

/// The corner radii the surfaces use.
abstract final class AppRadius {
  /// 4 — chips and inline controls.
  static const double sm = 4;

  /// 8 — cards, list tiles, and dialogs.
  static const double md = 8;

  /// 16 — the grid layout's cover tiles.
  static const double lg = 16;
}
