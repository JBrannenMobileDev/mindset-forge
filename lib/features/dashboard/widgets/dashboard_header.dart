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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Zone 1: App bar row ──────────────────────────────────────────────
        // Streak lives (with more detail) in the Daily Wins tracker, so the
        // header keeps just the account entry point to stay uncluttered.
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              AppDateUtils.formatWeekdayLong(DateTime.now()).toUpperCase(),
              style: AppTextStyles.overline.copyWith(
                color: AppColors.textMuted,
                letterSpacing: 1.2,
              ),
            ).animate().fadeIn(duration: 400.ms),
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
        ),

        const SizedBox(height: AppSpacing.lg),

        // ── Zone 2: Page title ───────────────────────────────────────────────
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
    );
  }
}
