import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';
import '../constants/app_strings.dart';
import '../constants/app_text_styles.dart';
import 'app_card.dart';

/// Honest disclosure of what an accountability partner can — and cannot — see,
/// shown at invite time. Mirrors the shareable fields in `PartnerProgress`
/// (the Cloud Function only returns those), so this is the single source of
/// truth for the data boundary. If partner-visible fields change, update here.
///
/// - `compact` (invite prompt sheet): two tight summary lines.
/// - full (invite form): itemized "can see" / "always private" lists.
class PartnerVisibilityCard extends StatelessWidget {
  final bool compact;

  const PartnerVisibilityCard({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    if (compact) return const _CompactVisibility();
    return const _FullVisibility();
  }
}

class _CompactVisibility extends StatelessWidget {
  const _CompactVisibility();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _SummaryLine(
            icon: Icons.visibility_outlined,
            color: AppColors.success,
            text: AppStrings.partnerVisibilitySeeSummary,
          ),
          SizedBox(height: AppSpacing.sm),
          _SummaryLine(
            icon: Icons.lock_outline_rounded,
            color: AppColors.textMuted,
            text: AppStrings.partnerVisibilityPrivateSummary,
          ),
        ],
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _SummaryLine({
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}

class _FullVisibility extends StatelessWidget {
  const _FullVisibility();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      backgroundColor: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GroupHeader(
            icon: Icons.visibility_outlined,
            color: AppColors.success,
            label: AppStrings.partnerVisibilityTitle,
          ),
          const SizedBox(height: AppSpacing.sm),
          const _VisibilityItem(text: AppStrings.partnerVisibilitySeeStreak),
          const _VisibilityItem(text: AppStrings.partnerVisibilitySeeProgress),
          const _VisibilityItem(text: AppStrings.partnerVisibilitySeeGoals),
          const _VisibilityItem(text: AppStrings.partnerVisibilitySeeEvidence),
          const _VisibilityItem(text: AppStrings.partnerVisibilitySeeIdentity),
          const _VisibilityItem(text: AppStrings.partnerVisibilitySeeSlip),
          const SizedBox(height: AppSpacing.md),
          _GroupHeader(
            icon: Icons.lock_outline_rounded,
            color: AppColors.textMuted,
            label: AppStrings.partnerVisibilityPrivateTitle,
          ),
          const SizedBox(height: AppSpacing.sm),
          const _VisibilityItem(
            text: AppStrings.partnerVisibilityPrivateJournal,
            isPrivate: true,
          ),
          const _VisibilityItem(
            text: AppStrings.partnerVisibilityPrivateChat,
            isPrivate: true,
          ),
          const _VisibilityItem(
            text: AppStrings.partnerVisibilityPrivateBeliefs,
            isPrivate: true,
          ),
          const _VisibilityItem(
            text: AppStrings.partnerVisibilityPrivateCoach,
            isPrivate: true,
          ),
        ],
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;

  const _GroupHeader({
    required this.icon,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: AppSpacing.sm),
        Text(label, style: AppTextStyles.labelLarge),
      ],
    );
  }
}

class _VisibilityItem extends StatelessWidget {
  final String text;
  final bool isPrivate;

  const _VisibilityItem({required this.text, this.isPrivate = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 24, bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isPrivate ? Icons.remove_rounded : Icons.check_rounded,
            size: 16,
            color: isPrivate ? AppColors.textMuted : AppColors.success,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
