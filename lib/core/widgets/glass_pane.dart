import 'dart:ui';

import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';

/// Frosted-glass card that floats over the blurred nebula backdrop. Used by the
/// auth flow (form/CTAs) and the onboarding step pane on wide screens.
///
/// Translucent with a localized [BackdropFilter] so the violet/cyan nebula
/// frosts through the edges — the premium "glass" feel. The blur is card-sized,
/// so the cost stays low.
class GlassPane extends StatelessWidget {
  final Widget child;

  /// Inner padding around [child]. Defaults to [AppSpacing.xl].
  final EdgeInsetsGeometry padding;

  const GlassPane({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.xl),
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 40,
                offset: const Offset(0, 16),
              ),
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.06),
                blurRadius: 48,
                spreadRadius: -8,
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
