import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../models/user_profile.dart';

/// Prominent dashboard card when a new weekly review is unread.
class WeeklyInsightBanner extends StatelessWidget {
  final UserProfile profile;

  const WeeklyInsightBanner({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    if (!profile.hasUnreadWeeklyInsight) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/progress'),
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          child: AppGlowCard(
            glowColor: AppColors.primaryGlow,
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.weeklyInsightReadyTitle,
                        style: AppTextStyles.labelLarge,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        AppStrings.weeklyInsightReadySubtitle,
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.08),
    );
  }
}
