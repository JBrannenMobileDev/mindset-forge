import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../models/user_profile.dart';

/// Dashboard card when the user is ready for a deeper blueprint excavation.
class BlueprintEvolutionBanner extends StatelessWidget {
  final UserProfile profile;

  const BlueprintEvolutionBanner({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    if (!profile.hasBlueprintEvolutionReady) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/blueprint-evolution'),
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          child: AppGlowCard(
            glowColor: AppColors.secondary.withValues(alpha: 0.2),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.secondaryContainer,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: const Icon(Icons.auto_awesome_rounded,
                      color: AppColors.secondary, size: 20),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.blueprintEvolutionBannerTitle,
                        style: AppTextStyles.labelLarge,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        AppStrings.blueprintEvolutionBannerSubtitle,
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.secondary, size: 22),
              ],
            ),
          ),
        ),
      ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.08),
    );
  }
}
