import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';
import 'hover_builder.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;
  final Color? borderColor;
  final double? borderRadius;
  final VoidCallback? onTap;
  final List<BoxShadow>? shadow;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.backgroundColor,
    this.borderColor,
    this.borderRadius,
    this.onTap,
    this.shadow,
  });

  @override
  Widget build(BuildContext context) {
    if (onTap == null) {
      return _decorated(borderColor ?? AppColors.border);
    }
    // Tappable cards get a desktop click cursor and a border that brightens on
    // hover so they read as interactive on web.
    return GestureDetector(
      onTap: onTap,
      child: HoverBuilder(
        builder: (context, hovered) => _decorated(
          hovered
              ? AppColors.primary.withValues(alpha: 0.4)
              : (borderColor ?? AppColors.border),
        ),
      ),
    );
  }

  Widget _decorated(Color border) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: padding ?? const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.surfaceElevated,
        borderRadius:
            BorderRadius.circular(borderRadius ?? AppSpacing.radiusLg),
        border: Border.all(color: border, width: 1),
        boxShadow: shadow,
      ),
      child: child,
    );
  }
}

class AppGlowCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color glowColor;

  const AppGlowCard({
    super.key,
    required this.child,
    this.padding,
    this.glowColor = AppColors.primaryGlow,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: padding,
      shadow: [
        BoxShadow(
          color: glowColor,
          blurRadius: 24,
          spreadRadius: 0,
        ),
      ],
      child: child,
    );
  }
}
