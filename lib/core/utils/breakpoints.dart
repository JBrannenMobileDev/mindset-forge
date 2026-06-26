import 'package:flutter/widgets.dart';
import '../constants/app_spacing.dart';

/// Semantic viewport breakpoints for the adaptive (mobile/tablet/desktop) UI.
///
/// Layout is driven by available width, never by platform. A wide tablet or a
/// resized desktop browser get the same treatment at the same width, so the
/// same breakpoints power both the navigation chrome and the per-screen
/// compositions.
abstract final class Breakpoints {
  static double widthOf(BuildContext context) =>
      MediaQuery.sizeOf(context).width;

  /// Phone-sized: floating bottom nav + single-column screens.
  static bool isMobile(BuildContext context) =>
      widthOf(context) < AppSpacing.tabletBreakpoint;

  static bool isTablet(BuildContext context) {
    final w = widthOf(context);
    return w >= AppSpacing.tabletBreakpoint && w < AppSpacing.desktopBreakpoint;
  }

  static bool isDesktop(BuildContext context) =>
      widthOf(context) >= AppSpacing.desktopBreakpoint;

  /// True once the sidebar chrome and wide compositions should engage
  /// (tablet and up). This is the primary decision point for the shell.
  static bool isWide(BuildContext context) =>
      widthOf(context) >= AppSpacing.tabletBreakpoint;

  /// Width-based variant for use inside a [LayoutBuilder], where the available
  /// content area (the region beside the sidebar) — not the whole screen —
  /// should decide whether a screen renders its multi-column desktop layout.
  static bool isWideWidth(double width) => width >= AppSpacing.tabletBreakpoint;
}
