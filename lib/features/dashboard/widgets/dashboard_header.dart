import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/app_date_utils.dart';
import '../../../core/widgets/shimmer_widget.dart';
import '../../../models/daily_completion.dart';
import '../../../models/user_profile.dart';
import '../../../providers/daily_completion_provider.dart';
import '../../../providers/daily_wisdom_provider.dart';
import 'daily_wins_shared.dart';

class DashboardHeader extends ConsumerWidget {
  final UserProfile profile;

  const DashboardHeader({super.key, required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(dailyWisdomProvider.notifier).loadForProfile(profile);
    });

    final wisdomState = ref.watch(dailyWisdomProvider);
    final completion = ref.watch(dailyCompletionProvider);

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
          const ShimmerBox(
              width: 200, height: 14, borderRadius: AppSpacing.radiusSm)
        else
          Text(
            '"${wisdomState.wisdom!}"',
            style: AppTextStyles.bodyMedium.copyWith(
              fontStyle: FontStyle.italic,
              color: AppColors.textSecondary,
            ),
          ).animate().fadeIn(duration: 600.ms),

        // ── Zone 3: Momentum strip (streak, best, today's progress) ──────────
        const SizedBox(height: AppSpacing.md),
        _MomentumStrip(
          currentStreak: profile.currentStreak,
          bestStreak: bestStreak(profile.dailyCompletions),
          completedCount: completion.completedCount,
          totalCount: DailyCompletion.totalCount,
          isPerfect: completion.isPerfectDay,
          onTodayTap: () => showDailyWinsInfoSheet(context, completion),
        ).animate().fadeIn(delay: 200.ms, duration: 500.ms),
      ],
    );
  }
}

/// Slim, card-less momentum row under the greeting: current streak, best
/// streak, and today's win progress. Always visible so momentum is felt the
/// moment the dashboard opens.
class _MomentumStrip extends StatelessWidget {
  final int currentStreak;
  final int bestStreak;
  final int completedCount;
  final int totalCount;
  final bool isPerfect;
  final VoidCallback onTodayTap;

  const _MomentumStrip({
    required this.currentStreak,
    required this.bestStreak,
    required this.completedCount,
    required this.totalCount,
    required this.isPerfect,
    required this.onTodayTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _MomentumItem(
          icon: Icons.local_fire_department_rounded,
          color: AppColors.warning,
          value: '$currentStreak',
          label: currentStreak == 1 ? 'day streak' : 'days streak',
        ),
        const _MomentumDivider(),
        _MomentumItem(
          icon: Icons.emoji_events_rounded,
          color: AppColors.secondary,
          value: '$bestStreak',
          label: 'best',
        ),
        const _MomentumDivider(),
        GestureDetector(
          onTap: onTodayTap,
          behavior: HitTestBehavior.opaque,
          child: _MomentumItem(
            icon: isPerfect
                ? Icons.workspace_premium_rounded
                : Icons.check_circle_outline_rounded,
            color: isPerfect ? AppColors.primary : AppColors.textSecondary,
            value: isPerfect ? 'Perfect' : '$completedCount/$totalCount',
            label: 'today',
            trailingIcon: Icons.info_outline_rounded,
          ),
        ),
      ],
    );
  }
}

class _MomentumItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;
  final IconData? trailingIcon;

  const _MomentumItem({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
    this.trailingIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 5),
        Text(
          value,
          style: AppTextStyles.labelLarge.copyWith(color: AppColors.textPrimary),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(color: AppColors.textMuted),
        ),
        if (trailingIcon != null) ...[
          const SizedBox(width: 4),
          Icon(trailingIcon, size: 13, color: AppColors.textMuted),
        ],
      ],
    );
  }
}

class _MomentumDivider extends StatelessWidget {
  const _MomentumDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 14,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      color: AppColors.border,
    );
  }
}
