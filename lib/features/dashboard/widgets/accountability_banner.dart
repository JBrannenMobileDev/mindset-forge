import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../models/user_profile.dart';
import '../../../providers/auth_provider.dart';

/// Dashboard entry point for the accountability feature. Adapts to the account:
/// - Partner accounts see who they're supporting + a tap-through to their dash.
/// - Subscribed users with no partner yet see an invite CTA (after a few days).
class AccountabilityBanner extends StatelessWidget {
  final UserProfile profile;

  const AccountabilityBanner({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    if (profile.isPartnerAccount) {
      final daysLeft = profile.giftedPremiumDaysRemaining;
      final expiringSoon = daysLeft != null && daysLeft <= 3;
      return Column(
        children: [
          _PartnerSupportingBanner(profile: profile),
          if (expiringSoon) ...[
            const SizedBox(height: AppSpacing.md),
            _PremiumExpiringBanner(daysLeft: daysLeft),
          ],
        ],
      );
    }
    return _InvitePartnerBanner(profile: profile);
  }
}

/// Conversion nudge shown to a gifted partner in the final days of their free
/// premium window: keep the momentum going by starting their own trial.
class _PremiumExpiringBanner extends StatelessWidget {
  final int daysLeft;
  const _PremiumExpiringBanner({required this.daysLeft});

  @override
  Widget build(BuildContext context) {
    final dayLabel = daysLeft <= 1 ? 'today' : 'in $daysLeft days';
    return GestureDetector(
      onTap: () => context.push('/pricing?source=partner_upgrade'),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: const Icon(Icons.hourglass_bottom_rounded,
                  color: AppColors.warning, size: 24),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your premium access ends $dayLabel',
                      style: AppTextStyles.labelLarge),
                  const SizedBox(height: 2),
                  Text(
                    'Keep the momentum going — start your own free trial.',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: AppColors.textMuted, size: 14),
          ],
        ),
      ).animate().fadeIn(duration: 400.ms),
    );
  }
}

class _PartnerSupportingBanner extends StatelessWidget {
  final UserProfile profile;
  const _PartnerSupportingBanner({required this.profile});

  @override
  Widget build(BuildContext context) {
    final active = profile.accountabilityRelationships
        .where((r) => r.type == 'partner' && r.status == 'active')
        .toList();
    if (active.isEmpty) return const SizedBox.shrink();

    final rel = active.first;
    final name = (rel.primaryName ?? '').isNotEmpty ? rel.primaryName! : 'your partner';
    final primaryUid = rel.primaryUid ?? '';

    return GestureDetector(
      onTap: primaryUid.isEmpty ? null : () => context.push('/partner-view/$primaryUid'),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary.withValues(alpha: 0.18),
              AppColors.secondary.withValues(alpha: 0.10),
            ],
          ),
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: const Icon(Icons.people_rounded, color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("You're supporting $name", style: AppTextStyles.labelLarge),
                  const SizedBox(height: 2),
                  Text(
                    'Check their progress and send some encouragement.',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textMuted, size: 14),
          ],
        ),
      ).animate().fadeIn(duration: 400.ms),
    );
  }
}

class _InvitePartnerBanner extends ConsumerWidget {
  final UserProfile profile;
  const _InvitePartnerBanner({required this.profile});

  Future<void> _dismiss(WidgetRef ref) async {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;
    await ref.read(firestoreServiceProvider).updateUserField(uid, {
      'invitePromptsDismissed': true,
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPartner = profile.accountabilityRelationships
        .any((r) => r.type == 'primary' && r.status == 'active');
    final daysSinceSignup =
        DateTime.now().difference(profile.createdAt).inDays;

    // Only nudge once they've settled in and don't already have a partner.
    if (hasPartner || daysSinceSignup < 3) return const SizedBox.shrink();

    // Respect the global "don't nag" controls shared with the invite prompts.
    if (profile.invitePromptsDismissed) return const SizedBox.shrink();
    final snooze = profile.invitePromptSnoozedUntil;
    if (snooze != null && DateTime.now().isBefore(snooze)) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: () => context.push('/accountability'),
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.14),
                  AppColors.secondary.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  child: const Icon(Icons.person_add_rounded, color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Add an accountability partner', style: AppTextStyles.labelLarge),
                      const SizedBox(height: 2),
                      Text(
                        'People who are watched show up more. Invite someone, free for them.',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.xl),
              ],
            ),
          ),
          Positioned(
            top: AppSpacing.xs,
            right: AppSpacing.xs,
            child: InkWell(
              onTap: () => _dismiss(ref),
              customBorder: const CircleBorder(),
              child: const Padding(
                padding: EdgeInsets.all(AppSpacing.xs),
                child: Icon(Icons.close_rounded, color: AppColors.textMuted, size: 16),
              ),
            ),
          ),
        ],
      ).animate().fadeIn(duration: 400.ms),
    );
  }
}
