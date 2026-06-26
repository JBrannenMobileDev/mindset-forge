import 'package:flutter/material.dart';
import '../constants/app_spacing.dart';

/// Constrains content width on wide screens (tablet/desktop/web).
/// On mobile, renders the child as-is. On wider screens, centers
/// the content inside a max-width box.
class ResponsiveLayout extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ResponsiveLayout({
    super.key,
    required this.child,
    this.maxWidth = AppSpacing.maxContentWidth * 1.4,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <= AppSpacing.mobileBreakpoint) {
          return child;
        }
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: child,
          ),
        );
      },
    );
  }
}

/// Desktop content frame: centers a multi-column composition up to
/// [maxWidth] and adds symmetric horizontal breathing room. Unlike
/// [ResponsiveLayout] (which caps reading width at ~680 for single-column
/// screens), this is the wrapper for the wide per-screen desktop layouts so
/// they can spread out without stretching edge-to-edge on large monitors.
class WebContentFrame extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final double horizontalPadding;

  const WebContentFrame({
    super.key,
    required this.child,
    this.maxWidth = AppSpacing.webContentMaxWidth,
    this.horizontalPadding = AppSpacing.webContentPaddingH,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: child,
        ),
      ),
    );
  }
}

/// Centers content in a column layout on wide screens, showing
/// two panels side by side when space is available.
class ResponsiveTwoColumn extends StatelessWidget {
  final Widget primary;
  final Widget? secondary;
  final double maxWidth;

  const ResponsiveTwoColumn({
    super.key,
    required this.primary,
    this.secondary,
    this.maxWidth = AppSpacing.desktopBreakpoint,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (secondary == null ||
            constraints.maxWidth < AppSpacing.tabletBreakpoint) {
          return primary;
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: primary),
            const SizedBox(width: AppSpacing.lg),
            Expanded(flex: 2, child: secondary!),
          ],
        );
      },
    );
  }
}
