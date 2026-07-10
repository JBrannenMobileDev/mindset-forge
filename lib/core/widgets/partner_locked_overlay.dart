import 'dart:ui';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';
import '../constants/app_strings.dart';
import '../constants/app_text_styles.dart';

/// Dims and blurs [child] when a partner item is over the free-plan cap.
/// Tapping the overlay should call [onLockedTap] (typically the upgrade sheet)
/// unless [blockTap] is false, in which case taps pass through to [child].
class PartnerLockedOverlay extends StatelessWidget {
  final bool isLocked;
  final VoidCallback? onLockedTap;
  final bool blockTap;
  final Widget child;

  const PartnerLockedOverlay({
    super.key,
    required this.isLocked,
    required this.child,
    this.onLockedTap,
    this.blockTap = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!isLocked) return child;

    return Stack(
      children: [
        child,
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
              child: Material(
                color: AppColors.scrim.withValues(alpha: 0.35),
                child: blockTap
                    ? InkWell(
                        onTap: onLockedTap,
                        child: _lockBadge(),
                      )
                    : IgnorePointer(child: _lockBadge()),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _lockBadge() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_rounded, size: 16, color: AppColors.primary),
            const SizedBox(width: AppSpacing.xs),
            Text(
              AppStrings.partnerLockedItemLabel,
              style:
                  AppTextStyles.labelSmall.copyWith(color: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}
