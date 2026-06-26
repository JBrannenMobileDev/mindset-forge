abstract final class AppSpacing {
  // Base spacing scale
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
  static const double xxxl = 64.0;

  // Padding presets
  static const double screenPaddingH = 20.0;
  static const double screenPaddingV = 24.0;
  static const double cardPadding = 20.0;
  static const double sectionGap = 28.0;

  // Border radii
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 24.0;
  static const double radiusFull = 100.0;

  // Icon sizes
  static const double iconSm = 16.0;
  static const double iconMd = 20.0;
  static const double iconLg = 24.0;
  static const double iconXl = 32.0;

  // Component heights
  static const double buttonHeight = 52.0;
  static const double inputHeight = 52.0;

  // Floating bottom nav geometry (single source of truth shared by the shell
  // and any screen that needs to clear the floating pill, e.g. the chat input).
  static const double bottomNavHeight = 58.0; // actual pill height
  static const double bottomNavMargin = 8.0; // gap below the pill
  static const double appBarHeight = 60.0;
  static const double chipHeight = 36.0;

  // Web breakpoints
  static const double mobileBreakpoint = 600.0;
  static const double tabletBreakpoint = 900.0;
  static const double desktopBreakpoint = 1280.0;
  static const double maxContentWidth = 480.0;

  // Desktop / web shell geometry. The sidebar replaces the floating bottom nav
  // at [tabletBreakpoint] and up; web content centers within
  // [webContentMaxWidth] so the multi-column compositions never stretch
  // edge-to-edge on ultra-wide monitors.
  static const double sideNavWidth = 240.0;
  static const double webContentMaxWidth = 1100.0;
  static const double webContentPaddingH = xl; // 32
}
