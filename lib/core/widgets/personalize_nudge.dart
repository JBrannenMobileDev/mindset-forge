import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';
import '../constants/app_text_styles.dart';
import '../../providers/auth_provider.dart';

/// Non-blocking nudge for a gifted partner account that hasn't personalized yet.
///
/// Shown inside personal features (coach chat, journal) so an invitee using
/// their free premium window is encouraged to run onboarding — which is what
/// makes coaching/journaling actually tailored to them — without ever blocking
/// the feature. Self-gating: renders nothing unless the current user is a
/// partner account with an active gifted-premium window and no onboarding yet.
class PersonalizeNudge extends ConsumerWidget {
  const PersonalizeNudge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentUserProfileProvider).valueOrNull;
    if (profile == null ||
        !profile.isPartnerAccount ||
        !profile.hasGiftedPremium ||
        profile.hasCompletedOnboarding) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          onTap: () => context.push('/onboarding'),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: const Icon(Icons.auto_awesome_rounded,
                      size: 18, color: AppColors.primary),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Make this yours', style: AppTextStyles.labelLarge),
                      Text(
                        'Personalize in 2 min so this is tailored to you.',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded,
                    size: 14, color: AppColors.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
