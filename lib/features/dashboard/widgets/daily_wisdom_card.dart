import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/utils/app_date_utils.dart';
import '../../../models/user_profile.dart';
import '../../../providers/daily_wisdom_provider.dart';

class DailyWisdomCard extends ConsumerWidget {
  final UserProfile profile;

  const DailyWisdomCard({super.key, required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Kick off generation (idempotent — the notifier guards against duplicates).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(dailyWisdomProvider.notifier).loadForProfile(profile);
    });

    final wisdomState = ref.watch(dailyWisdomProvider);

    return AppGlowCard(
      glowColor: AppColors.primaryGlow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.xs),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: const Icon(Icons.wb_sunny_rounded, color: AppColors.primary, size: 16),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                AppStrings.dailyWisdom,
                style: AppTextStyles.labelMedium.copyWith(color: AppColors.primary),
              ),
              const Spacer(),
              Text(
                AppDateUtils.formatDateShort(DateTime.now()),
                style: AppTextStyles.labelSmall,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (wisdomState.isLoading || wisdomState.wisdom == null)
            Column(
              children: [
                const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Channeling today\'s wisdom...',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                ),
              ],
            )
          else
            Text(
              wisdomState.wisdom!,
              style: AppTextStyles.bodyLarge.copyWith(
                fontStyle: FontStyle.italic,
                height: 1.7,
                color: AppColors.textPrimary,
              ),
            ).animate().fadeIn(duration: 600.ms),
        ],
      ),
    );
  }
}
