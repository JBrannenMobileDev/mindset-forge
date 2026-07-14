import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../models/user_profile.dart';
import '../../../providers/identity_provider.dart';
import '../../mindset/widgets/identity_evolve_sheet.dart';

/// Prompts the user to refresh a stale identity statement. Shown on the
/// dashboard and Mindset hub when [IdentityEvolution.shouldShowNudge] is true.
class IdentityEvolveBanner extends ConsumerWidget {
  final UserProfile profile;

  const IdentityEvolveBanner({super.key, required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AppGlowCard(
            glowColor: AppColors.primaryGlow,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusSm),
                      ),
                      child: const Icon(
                        Icons.fingerprint_rounded,
                        size: 20,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(
                          right: AppSpacing.lg,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppStrings.identityEvolveNudgeTitle,
                              style: AppTextStyles.labelLarge,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              AppStrings.identityEvolveNudgeSubtitle,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                AppPrimaryButton(
                  label: AppStrings.identityEvolveNudgeAction,
                  onPressed: () => showIdentityEvolveSheet(
                    context,
                    ref,
                    profile: profile,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: AppSpacing.sm,
            right: AppSpacing.sm,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => ref
                    .read(identityProvider.notifier)
                    .dismissEvolveNudge(),
                customBorder: const CircleBorder(),
                child: const Padding(
                  padding: EdgeInsets.all(AppSpacing.xs),
                  child: Icon(
                    Icons.close_rounded,
                    color: AppColors.textMuted,
                    size: 18,
                  ),
                ),
              ),
            ),
          ),
        ],
      ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.08),
    );
  }
}
