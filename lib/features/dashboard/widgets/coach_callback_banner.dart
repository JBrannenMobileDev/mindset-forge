import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../models/user_profile.dart';

/// Dashboard card when a proactive coach callback is waiting in chat.
class CoachCallbackBanner extends StatelessWidget {
  final UserProfile profile;

  const CoachCallbackBanner({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final callback = profile.pendingCallback;
    if (!profile.hasPendingCallback || callback == null) {
      return const SizedBox.shrink();
    }

    final isPositive = callback.isPositive;
    final accent = isPositive ? AppColors.success : AppColors.warning;
    final glow = isPositive
        ? AppColors.success.withValues(alpha: 0.2)
        : AppColors.warning.withValues(alpha: 0.2);
    final icon = isPositive
        ? Icons.trending_up_rounded
        : Icons.psychology_alt_rounded;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/chat'),
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          child: AppGlowCard(
            glowColor: glow,
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: Icon(icon, color: accent, size: 20),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isPositive
                            ? AppStrings.coachCallbackPositiveTitle
                            : AppStrings.coachCallbackRegressionTitle,
                        style: AppTextStyles.labelLarge,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isPositive
                            ? AppStrings.coachCallbackPositiveSubtitle
                            : AppStrings.coachCallbackRegressionSubtitle,
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: accent, size: 22),
              ],
            ),
          ),
        ),
      ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.08),
    );
  }
}
