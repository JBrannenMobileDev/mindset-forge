import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';
import 'bottom_nav_shell.dart';
import 'mobile_web_gate.dart';
import 'side_nav.dart';

/// Viewport-driven navigation chrome for the main tab shell.
///
/// On phone widths it defers entirely to [BottomNavShell] (the floating pill).
/// At [AppSpacing.tabletBreakpoint] and up it swaps to a persistent left
/// [SideNav] with the routed page filling the remaining space — the standard
/// desktop/web layout. The decision is based purely on available width, so a
/// resized browser transitions live between the two.
///
/// On the web the phone layout is never rendered: small viewports show the
/// [MobileWebGate] instead, steering visitors to the native app where the full
/// mobile experience lives.
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
          // Web small screens fall back to the app store gate; the phone UI is
          // native-only.
          if (kIsWeb) {
            return const MobileWebGate();
          }
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
