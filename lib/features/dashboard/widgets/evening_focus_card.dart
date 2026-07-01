import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../models/user_profile.dart';
import '../../../providers/priority_actions_provider.dart';

/// Evening "last call" reminder for an incomplete #1 Focus.
///
/// After 5 PM the evening routine claims the dashboard's single hero slot, which
/// would otherwise demote the day's self-chosen commitment to a faint footnote.
/// This compact purple card sits directly beneath the hero so the focus stays
/// visible and one tap from done — distinct from the cyan evening hero, but
/// deliberately quieter so the routine remains the star.
///
/// Only meaningful when it's evening, a focus is set for today, and it isn't yet
/// complete; the dashboard guards that condition before mounting this card.
class EveningFocusCard extends ConsumerStatefulWidget {
  final UserProfile profile;

  const EveningFocusCard({super.key, required this.profile});

  @override
  ConsumerState<EveningFocusCard> createState() => _EveningFocusCardState();
}

class _EveningFocusCardState extends ConsumerState<EveningFocusCard> {
  bool _completing = false;

  /// Marks Today's Focus complete by adding it to the authoritative completed
  /// list (mirrors [TodayHeroCard]). The dashboard drops this card once the
  /// profile stream reflects completion.
  Future<void> _completeFocus() async {
    setState(() => _completing = true);
    try {
      await ref.read(priorityActionsProvider.notifier).completeFocus();
      if (!mounted) return;
      setState(() => _completing = false);
    } catch (e) {
      debugPrint('EveningFocusCard._completeFocus failed: $e');
      if (!mounted) return;
      setState(() => _completing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color.alphaBlend(
          AppColors.primary.withValues(alpha: 0.18),
          AppColors.surfaceElevated,
        ),
        AppColors.surfaceElevated,
      ],
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
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
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: const Icon(
                  Icons.my_location_rounded,
                  size: 20,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusFull),
                      ),
                      child: Text(
                        AppStrings.heroFocusSessionLabel,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.primary,
                          fontSize: 9,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      widget.profile.dailyFocusAction,
                      style: AppTextStyles.labelLarge
                          .copyWith(color: AppColors.textPrimary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            AppStrings.focusStillOpenNote,
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          AppPrimaryButton(
            label: AppStrings.heroFocusButton,
            onPressed: _completing ? null : _completeFocus,
            icon: Icons.check_circle_outline_rounded,
            isLoading: _completing,
            accentColor: AppColors.primary,
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }
}
