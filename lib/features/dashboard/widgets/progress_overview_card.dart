import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/manifestation_system_explainer.dart';
import '../../../models/user_profile.dart';
import 'alignment_score_widget.dart';
import 'weekly_chart_widget.dart';

/// Consolidated "Your Progress" card. A segmented toggle swaps between the
/// manifestation alignment view and the weekly activity chart so the two
/// stats share one card instead of two separately-headed sections.
class ProgressOverviewCard extends StatefulWidget {
  final UserProfile profile;

  const ProgressOverviewCard({super.key, required this.profile});

  @override
  State<ProgressOverviewCard> createState() => _ProgressOverviewCardState();
}

/// At/above this card width the two views are shown side by side instead of
/// behind a toggle (the full-width desktop progress card); narrower placements
/// (phones, the single-column reflow) keep the compact segmented toggle.
const double _kProgressDualPaneMinWidth = 640;

class _ProgressOverviewCardState extends State<ProgressOverviewCard> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= _kProgressDualPaneMinWidth) {
            return _buildDualPane(context);
          }
          return _buildToggle(context);
        },
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildToggle(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _SegmentToggle(
                index: _tab,
                labels: const [
                  AppStrings.progressTabAlignment,
                  AppStrings.progressTabActivity,
                ],
                onChanged: (i) => setState(() => _tab = i),
              ),
            ),
            // The "how this works" explainer only applies to alignment.
            if (_tab == 0) ...[
              const SizedBox(width: AppSpacing.sm),
              _infoButton(context),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, animation) =>
                FadeTransition(opacity: animation, child: child),
            child: _tab == 0
                ? AlignmentScoreBody(
                    key: const ValueKey('alignment'),
                    profile: widget.profile,
                  )
                : WeeklyChartBody(
                    key: const ValueKey('activity'),
                    profile: widget.profile,
                  ),
          ),
        ),
      ],
    );
  }

  /// Wide layout: both views at once, each under its own label, so the desktop
  /// progress card uses its full width instead of hiding half behind a toggle.
  Widget _buildDualPane(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: _PaneLabel(AppStrings.progressTabAlignment),
                  ),
                  _infoButton(context),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              AlignmentScoreBody(profile: widget.profile),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.xl),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _PaneLabel(AppStrings.progressTabActivity),
              const SizedBox(height: AppSpacing.lg),
              WeeklyChartBody(profile: widget.profile),
            ],
          ),
        ),
      ],
    );
  }

  Widget _infoButton(BuildContext context) {
    return IconButton(
      onPressed: () => showManifestationSystemSheet(context),
      icon: const Icon(Icons.info_outline_rounded),
      color: AppColors.textSecondary,
      iconSize: AppSpacing.iconLg,
      tooltip: 'How this works',
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
    );
  }
}

/// Small uppercase section label for the dual-pane progress views.
class _PaneLabel extends StatelessWidget {
  final String label;

  const _PaneLabel(this.label);

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

/// Full-width two-segment pill switch (active segment filled with primary).
class _SegmentToggle extends StatelessWidget {
  final int index;
  final List<String> labels;
  final ValueChanged<int> onChanged;

  const _SegmentToggle({
    required this.index,
    required this.labels,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          for (int i = 0; i < labels.length; i++)
            Expanded(child: _segment(labels[i], i)),
        ],
      ),
    );
  }

  Widget _segment(String label, int i) {
    final selected = i == index;
    return GestureDetector(
      onTap: () => onChanged(i),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs + 2),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: selected ? Colors.white : AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
