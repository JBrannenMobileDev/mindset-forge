import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../models/user_profile.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/daily_completion_provider.dart';

class FocusModeBanner extends ConsumerStatefulWidget {
  final UserProfile profile;

  const FocusModeBanner({super.key, required this.profile});

  @override
  ConsumerState<FocusModeBanner> createState() => _FocusModeBannerState();
}

class _FocusModeBannerState extends ConsumerState<FocusModeBanner> {
  bool _isCompleting = false;

  String get _todayStr {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  bool get _shouldShow {
    final p = widget.profile;
    return p.dailyFocusAction.isNotEmpty &&
        p.dailyFocusActionDate == _todayStr &&
        !p.dailyFocusActionCompleted;
  }

  Future<void> _markComplete() async {
    setState(() => _isCompleting = true);
    try {
      final uid = ref.read(authStateProvider).valueOrNull?.uid;
      if (uid != null) {
        await ref.read(firestoreServiceProvider).updateUserField(uid, {
          'dailyFocusActionCompleted': true,
        });
      }
      await ref
          .read(dailyCompletionProvider.notifier)
          .toggle('priorityActionsCompleted', true);
    } finally {
      if (mounted) setState(() => _isCompleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_shouldShow) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.screenPaddingH,
        AppSpacing.sectionGap,
        AppSpacing.screenPaddingH,
        0,
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.18),
            AppColors.secondary.withValues(alpha: 0.10),
          ],
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── "Current Focus" chip ──────────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.my_location_rounded,
                        color: AppColors.primary, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      'CURRENT FOCUS',
                      style: AppTextStyles.overline
                          .copyWith(color: AppColors.primary),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // ── Focus action text ─────────────────────────────────────
          Text(
            widget.profile.dailyFocusAction,
            style: AppTextStyles.bodyLarge.copyWith(
              height: 1.5,
              color: AppColors.textPrimary,
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // ── Mark Complete button ──────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isCompleting ? null : _markComplete,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
              ),
              icon: _isCompleting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.check_circle_outline_rounded, size: 18),
              label: Text(
                _isCompleting ? 'Saving…' : 'Mark Complete',
                style: AppTextStyles.labelLarge.copyWith(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.05, end: 0);
  }
}
