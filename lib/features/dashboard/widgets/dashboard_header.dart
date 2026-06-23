import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/app_date_utils.dart';
import '../../../core/widgets/shimmer_widget.dart';
import '../../../models/user_profile.dart';
import '../../../providers/daily_wisdom_provider.dart';

class DashboardHeader extends ConsumerWidget {
  final UserProfile profile;

  const DashboardHeader({super.key, required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(dailyWisdomProvider.notifier).loadForProfile(profile);
    });

    final wisdomState = ref.watch(dailyWisdomProvider);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Greeting + wisdom ────────────────────────────────────────────────
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${AppDateUtils.greetingForTime()}, ${profile.firstName}!',
                style: AppTextStyles.headlineLarge,
              ).animate().fadeIn(duration: 400.ms),
              const SizedBox(height: AppSpacing.sm),
              if (wisdomState.isLoading || wisdomState.wisdom == null)
                ShimmerBox(width: 200, height: 14, borderRadius: AppSpacing.radiusSm)
              else
                Text(
                  '"${wisdomState.wisdom!}"',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontStyle: FontStyle.italic,
                    color: AppColors.textSecondary,
                  ),
                ).animate().fadeIn(duration: 600.ms),
            ],
          ),
        ),

        const SizedBox(width: AppSpacing.md),

        // ── Streak + avatar ──────────────────────────────────────────────────
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.local_fire_department_rounded,
                  color: AppColors.warning,
                  size: 20,
                ),
                const SizedBox(width: 4),
                Text(
                  '${profile.currentStreak}',
                  style: AppTextStyles.headlineSmall.copyWith(
                    color: AppColors.warning,
                  ),
                ),
              ],
            ),
            Text('day streak', style: AppTextStyles.labelSmall),
          ],
        ).animate().fadeIn(delay: 200.ms),

        const SizedBox(width: 12),

        GestureDetector(
          onTap: () => context.push('/settings'),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(
              Icons.person_rounded,
              color: AppColors.textSecondary,
              size: 20,
            ),
          ),
        ).animate().fadeIn(delay: 300.ms),
      ],
    );
  }
}
