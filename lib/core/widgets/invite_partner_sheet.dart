import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';
import '../constants/app_strings.dart';
import '../constants/app_text_styles.dart';
import 'app_button.dart';
import 'partner_visibility_card.dart';

/// What the user chose on the invite prompt, so the coordinator can snooze /
/// dismiss / trigger the share flow accordingly.
enum InvitePromptResult { invited, notNow, dismissed, none }

/// Reusable accountability-partner invite prompt, shown at high-intent moments
/// (onboarding done, perfect day, streak milestones). Styled to match
/// `partner_upgrade_sheet.dart`. Copy is passed in by the caller so this widget
/// stays trigger-agnostic.
Future<InvitePromptResult> showInvitePartnerSheet(
  BuildContext context, {
  required String title,
  required String body,
  IconData icon = Icons.people_rounded,
}) async {
  final result = await showModalBottomSheet<InvitePromptResult>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
    ),
    builder: (_) => _InvitePartnerSheet(title: title, body: body, icon: icon),
  );
  return result ?? InvitePromptResult.none;
}

class _InvitePartnerSheet extends StatelessWidget {
  final String title;
  final String body;
  final IconData icon;

  const _InvitePartnerSheet({
    required this.title,
    required this.body,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
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
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(title, style: AppTextStyles.headlineSmall),
            const SizedBox(height: AppSpacing.sm),
            Text(
              body,
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
            const PartnerVisibilityCard(compact: true),
            const SizedBox(height: AppSpacing.lg),
            AppPrimaryButton(
              label: AppStrings.invitePromptCta,
              icon: Icons.ios_share_rounded,
              onPressed: () => Navigator.of(context).pop(InvitePromptResult.invited),
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(InvitePromptResult.notNow),
                  child: Text(
                    AppStrings.invitePromptNotNow,
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(InvitePromptResult.dismissed),
                  child: Text(
                    AppStrings.invitePromptDismiss,
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                  ),
                ),
              ],
            ),
            Center(
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).pop(InvitePromptResult.none);
                  context.push('/accountability');
                },
                child: Text(
                  AppStrings.invitePromptManage,
                  style: AppTextStyles.labelSmall.copyWith(color: AppColors.primary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
