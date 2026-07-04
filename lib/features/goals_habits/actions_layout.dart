import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';

/// Where an Actions tab is rendered — drives padding and scroll behaviour.
enum ActionsLayoutContext {
  /// Inside mobile TabBarView — full-width gutters, clears floating nav.
  mobileTab,

  /// A column in the desktop multi-column grid — no extra horizontal pad.
  desktopColumn,

  /// A stacked section in the desktop single-column reflow — section spacing.
  desktopSection,
}

/// List padding for an Actions tab surface.
EdgeInsets actionsTabPadding(ActionsLayoutContext context) {
  switch (context) {
    case ActionsLayoutContext.mobileTab:
      return const EdgeInsets.fromLTRB(
        AppSpacing.screenPaddingH,
        AppSpacing.lg,
        AppSpacing.screenPaddingH,
        100,
      );
    case ActionsLayoutContext.desktopColumn:
      return const EdgeInsets.only(
        top: AppSpacing.lg,
        bottom: AppSpacing.xxl,
      );
    case ActionsLayoutContext.desktopSection:
      return const EdgeInsets.only(bottom: AppSpacing.sectionGap);
  }
}

/// Desktop uses shrink-wrapped lists inside the outer page scroll.
bool actionsTabShrinkWrap(ActionsLayoutContext context) =>
    context != ActionsLayoutContext.mobileTab;

ScrollPhysics? actionsTabScrollPhysics(ActionsLayoutContext context) =>
    actionsTabShrinkWrap(context)
        ? const NeverScrollableScrollPhysics()
        : null;

/// Section label for desktop Actions columns — matches dashboard overline style.
class ActionsDesktopSectionLabel extends StatelessWidget {
  final String label;

  const ActionsDesktopSectionLabel(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: AppTextStyles.overline.copyWith(
        color: AppColors.textMuted,
        letterSpacing: 1.2,
      ),
    );
  }
}

/// Desktop grid reflow thresholds — measured on padded content beside sidebar.
const double kActionsMaxWidth = 1200;
const double kActionsThreeColumnMinWidth = 1000;
const double kActionsTwoColumnMinWidth = 720;
