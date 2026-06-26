import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';
import 'bottom_nav_shell.dart';
import 'side_nav.dart';

/// Viewport-driven navigation chrome for the main tab shell.
///
/// On phone widths it defers entirely to [BottomNavShell] (the floating pill).
/// At [AppSpacing.tabletBreakpoint] and up it swaps to a persistent left
/// [SideNav] with the routed page filling the remaining space — the standard
/// desktop/web layout. The decision is based purely on available width, so a
/// resized browser transitions live between the two.
class AdaptiveNavShell extends StatelessWidget {
  final Widget child;
  final String location;

  const AdaptiveNavShell({
    super.key,
    required this.child,
    required this.location,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < AppSpacing.tabletBreakpoint) {
          return BottomNavShell(location: location, child: child);
        }
        return Scaffold(
          backgroundColor: AppColors.background,
          body: Row(
            children: [
              SideNav(location: location),
              Expanded(child: child),
            ],
          ),
        );
      },
    );
  }
}
