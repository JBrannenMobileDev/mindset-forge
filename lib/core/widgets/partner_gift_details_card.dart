import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';
import '../constants/app_strings.dart';
import '../constants/app_text_styles.dart';
import 'app_card.dart';

/// Honest disclosure of the partner gift window and the free plan that follows.
/// Shown at signup and invite-accept so partners know what they're getting
/// before they commit — mirrors [PartnerVisibilityCard] for the data boundary.
class PartnerGiftDetailsCard extends StatelessWidget {
  final bool compact;

  const PartnerGiftDetailsCard({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    if (compact) return const _CompactGiftDetails();
    return const _FullGiftDetails();
  }
}

class _CompactGiftDetails extends StatelessWidget {
  const _CompactGiftDetails();

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
        children: [
          Text(
            AppStrings.partnerGiftCompactTitle,
            style: AppTextStyles.labelLarge,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            AppStrings.partnerGiftCompactBody,
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _FullGiftDetails extends StatelessWidget {
  const _FullGiftDetails();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      backgroundColor: AppColors.surfaceElevated,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: const Icon(Icons.card_giftcard_rounded,
                    size: 16, color: AppColors.primary),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  AppStrings.partnerGiftDetailsTitle,
                  style: AppTextStyles.labelLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _GiftLine(
            icon: Icons.auto_awesome_rounded,
            color: AppColors.primary,
            text: AppStrings.partnerGiftDuringWindow,
          ),
          const SizedBox(height: AppSpacing.sm),
          _GiftLine(
            icon: Icons.schedule_rounded,
            color: AppColors.warning,
            text: AppStrings.partnerGiftAfterWindow,
          ),
          const SizedBox(height: AppSpacing.sm),
          _GiftLine(
            icon: Icons.upgrade_rounded,
            color: AppColors.secondary,
            text: AppStrings.partnerGiftUpgradeNote,
          ),
        ],
      ),
    );
  }
}

class _GiftLine extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _GiftLine({
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
