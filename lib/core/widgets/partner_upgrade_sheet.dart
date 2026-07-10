import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';
import '../constants/app_text_styles.dart';
import 'app_button.dart';

/// Bottom sheet shown when a free partner account hits a usage limit or taps a
/// locked premium feature. Uses social proof (the person they support) to drive
/// conversion toward their own trial.
Future<void> showPartnerUpgradeSheet(
  BuildContext context, {
  String featureName = 'this feature',
  String? partnerName,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
    ),
    builder: (_) => _PartnerUpgradeSheet(
      featureName: featureName,
      partnerName: partnerName,
    ),
  );
}

/// Bottom sheet shown when a free partner taps a personal feature before they've
/// set up their own journey. The limited features (coaching, journaling, goals)
/// need the identity/goal context captured during onboarding to work well, so we
/// route them through the real onboarding first (which is also the magic moment).
Future<void> showPartnerSetupSheet(
  BuildContext context, {
  String featureName = 'this feature',
  String? partnerName,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
    ),
    builder: (_) => _PartnerSetupSheet(
      featureName: featureName,
      partnerName: partnerName,
    ),
  );
}

class _PartnerSetupSheet extends StatelessWidget {
  final String featureName;
  final String? partnerName;

  const _PartnerSetupSheet({required this.featureName, this.partnerName});

  @override
  Widget build(BuildContext context) {
    final supporter = (partnerName != null && partnerName!.isNotEmpty)
        ? partnerName!
        : 'your partner';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.secondary],
                ),
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                boxShadow: const [
                  BoxShadow(color: AppColors.primaryGlow, blurRadius: 24, spreadRadius: 1),
                ],
              ),
              child: const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 28),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Set up your journey first', style: AppTextStyles.headlineSmall),
            const SizedBox(height: AppSpacing.sm),
            Text(
              "You've been supporting $supporter. Ready for your own? Take 2 minutes to set up your mindset profile so $featureName is personalized to you. It's free.",
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
              ),
              child: Text(
                "You'll get a personalized mindset analysis at the end, on us.",
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppPrimaryButton(
              label: 'Start My Journey',
              icon: Icons.arrow_forward_rounded,
              onPressed: () {
                Navigator.of(context).pop();
                context.push('/onboarding');
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Maybe later',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PartnerUpgradeSheet extends StatelessWidget {
  final String featureName;
  final String? partnerName;

  const _PartnerUpgradeSheet({required this.featureName, this.partnerName});

  @override
  Widget build(BuildContext context) {
    final supporter = (partnerName != null && partnerName!.isNotEmpty)
        ? partnerName!
        : 'your partner';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.secondary],
                ),
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                boxShadow: const [
                  BoxShadow(color: AppColors.primaryGlow, blurRadius: 24, spreadRadius: 1),
                ],
              ),
              child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 28),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Ready for your own transformation?',
                style: AppTextStyles.headlineSmall),
            const SizedBox(height: AppSpacing.sm),
            Text(
              "You've seen $supporter grow. Unlock $featureName and the full MindsetForge experience for yourself.",
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
            _benefit(Icons.chat_bubble_outline_rounded, 'Unlimited AI coaching',
                '24/7 personalized guidance, no weekly limit'),
            _benefit(Icons.track_changes_rounded, 'Unlimited goals',
                'Track everything you\'re working on, not just one'),
            _benefit(Icons.auto_graph_rounded, 'Your full mindset toolkit',
                'Deep dives, weekly insights, and your evolving blueprint'),
            const SizedBox(height: AppSpacing.lg),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
              ),
              child: Text(
                'Start with a 7-day free trial. Cancel anytime.',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppPrimaryButton(
              label: 'Start My Free Trial',
              icon: Icons.arrow_forward_rounded,
              onPressed: () {
                Navigator.of(context).pop();
                context.push('/pricing?source=partner_upgrade');
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Maybe later',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _benefit(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Icon(icon, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.labelLarge),
                Text(
                  subtitle,
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
