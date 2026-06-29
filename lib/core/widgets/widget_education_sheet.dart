import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';
import '../constants/app_strings.dart';
import '../constants/app_text_styles.dart';
import 'app_button.dart';

/// Shows the home screen widget education prompt. Tapping "Got it" records
/// [UserProfile.widgetPromptSeen] so the Getting Started checklist item is
/// marked done and post-onboarding stops nudging.
Future<void> showWidgetEducationSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius:
          BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
    ),
    builder: (_) => const _WidgetEducationSheet(),
  );
}

class _WidgetEducationSheet extends ConsumerWidget {
  const _WidgetEducationSheet();

  Future<void> _markSeen(WidgetRef ref) async {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;
    try {
      await ref
          .read(firestoreServiceProvider)
          .updateUserField(uid, {'widgetPromptSeen': true});
    } catch (e) {
      debugPrint('WidgetEducationSheet._markSeen failed: $e');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final steps =
        Platform.isIOS ? AppStrings.widgetSheetStepsIos : AppStrings.widgetSheetStepsAndroid;

    return SafeArea(
      child: SingleChildScrollView(
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
              const Center(child: _WidgetPreview()),
              const SizedBox(height: AppSpacing.lg),
              Text(AppStrings.widgetSheetTitle, style: AppTextStyles.headlineSmall),
              const SizedBox(height: AppSpacing.sm),
              Text(
                AppStrings.widgetSheetBody,
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.lg),
              ...steps.asMap().entries.map(
                    (e) => _StepRow(index: e.key + 1, text: e.value),
                  ),
              const SizedBox(height: AppSpacing.lg),
              AppPrimaryButton(
                label: AppStrings.widgetSheetCta,
                icon: Icons.check_rounded,
                onPressed: () async {
                  await _markSeen(ref);
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
              const SizedBox(height: AppSpacing.xs),
              Center(
                child: AppTextButton(
                  label: AppStrings.widgetSheetLater,
                  color: AppColors.textMuted,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small static mock of the "Today's Focus" home screen widget so users
/// recognize what they are adding.
class _WidgetPreview extends StatelessWidget {
  const _WidgetPreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      height: 160,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.surfaceElevated, AppColors.surfaceHighest],
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(color: AppColors.primaryGlow, blurRadius: 24, spreadRadius: 1),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: const Icon(Icons.bolt_rounded,
                    size: 14, color: AppColors.primary),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                "TODAY'S FOCUS",
                style: AppTextStyles.labelSmall
                    .copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
          const Spacer(),
          Text(
            'Ship the first draft',
            style: AppTextStyles.labelLarge.copyWith(color: AppColors.textPrimary),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              const Icon(Icons.local_fire_department_rounded,
                  size: 14, color: AppColors.warning),
              const SizedBox(width: 4),
              Text(
                '7 day streak',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final int index;
  final String text;

  const _StepRow({required this.index, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$index',
              style: AppTextStyles.labelSmall.copyWith(color: AppColors.primary),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                text,
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textPrimary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
