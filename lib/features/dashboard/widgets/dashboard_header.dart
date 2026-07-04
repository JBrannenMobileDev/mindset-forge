import 'dart:async';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/confetti_gate.dart';
import '../../../core/services/streak_celebration_store.dart';
import '../../../core/utils/app_date_utils.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/shimmer_widget.dart';
import '../../../core/widgets/week_streak_chain.dart';
import '../../../models/daily_completion.dart';
import '../../../models/user_profile.dart';
import '../../../providers/daily_completion_provider.dart';
import '../../../providers/daily_wisdom_provider.dart';
import 'daily_wins_shared.dart';

class DashboardHeader extends ConsumerWidget {
  final UserProfile profile;

  /// Desktop hides the settings avatar (the sidebar already has Settings) and
  /// lifts the streak into a standalone [StreakMomentumCard] in the header band.
  final bool showAvatar;
  final bool showStreak;

  const DashboardHeader({
    super.key,
    required this.profile,
    this.showAvatar = true,
    this.showStreak = true,
  });

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
            Row(
              children: [
                const _TimeOfDayBadge(),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  AppDateUtils.formatWeekdayLong(DateTime.now()).toUpperCase(),
                  style: AppTextStyles.overline.copyWith(
                    color: AppColors.textMuted,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ).animate().fadeIn(duration: 400.ms),
            if (showAvatar)
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

        // ── Zone 3: Streak strip (7-day chain + best + today's progress) ─────
        if (showStreak) ...[
          const SizedBox(height: AppSpacing.md),
          StreakMomentum(profile: profile)
              .animate()
              .fadeIn(delay: 200.ms, duration: 500.ms),
        ],
      ],
    );
  }
}

/// Streak/momentum content configured from a [UserProfile] and the live daily
/// completion. Rendered inline in the mobile header and inside a bounded
/// [StreakMomentumCard] in the desktop header band.
class StreakMomentum extends ConsumerWidget {
  final UserProfile profile;

  const StreakMomentum({super.key, required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completion = ref.watch(dailyCompletionProvider);
    return _StreakStrip(
      currentStreak: profile.currentStreak,
      perfectStreak: profile.perfectStreak,
      bestStreak: bestStreak(profile.dailyCompletions),
      completion: completion,
      dailyCompletions: profile.dailyCompletions,
      onTap: () => showDailyWinsInfoSheet(context, completion),
    );
  }
}

/// [StreakMomentum] wrapped in a bounded card for the desktop header band.
class StreakMomentumCard extends StatelessWidget {
  final UserProfile profile;

  const StreakMomentumCard({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: StreakMomentum(profile: profile),
    ).animate().fadeIn(delay: 200.ms, duration: 500.ms);
  }
}

/// Small rounded badge with a time-of-day icon (sunrise / sun / moon), tinted
/// with the matching session accent. A refined visual accent beside the date —
/// keeps the date for orientation while adding warmth.
class _TimeOfDayBadge extends StatelessWidget {
  const _TimeOfDayBadge();

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color accent) = switch (AppDateUtils.timeOfDayKey()) {
      'morning' => (Icons.wb_twilight_rounded, AppColors.warning),
      'afternoon' => (Icons.wb_sunny_rounded, AppColors.warning),
      _ => (Icons.bedtime_rounded, AppColors.secondary),
    };

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Icon(icon, size: 16, color: accent),
    );
  }
}

/// Streak-forward momentum block under the greeting: a 7-day chain of daily
/// wins (Duolingo-style) with today highlighted as the next link to complete,
/// a prominent streak count, a motivating subtitle, and the best/today stats.
/// Tapping anywhere opens the daily-wins explainer.
class _StreakStrip extends StatefulWidget {
  final int currentStreak;
  final int perfectStreak;
  final int bestStreak;
  final DailyCompletion completion;
  final List<DailyCompletion> dailyCompletions;
  final VoidCallback onTap;

  const _StreakStrip({
    required this.currentStreak,
    required this.perfectStreak,
    required this.bestStreak,
    required this.completion,
    required this.dailyCompletions,
    required this.onTap,
  });

  @override
  State<_StreakStrip> createState() => _StreakStripState();
}

class _StreakStripState extends State<_StreakStrip> {
  // A full week (7 consecutive days) fills the chart and unlocks the glow.
  static const int _weekThreshold = 7;

  late final ConfettiController _flawlessConfetti;

  // Loaded from persistence so the one-time burst fires exactly once per
  // milestone — not again the next day and not again on relaunch. Null until
  // loaded; celebration checks wait for a non-null value.
  bool? _flawlessCelebrated;

  // Debounces a genuine active/inactive edge briefly so a rapid
  // cache-then-server double-emission of the profile stream can't be read as
  // two separate crossings — only whichever value is still current once the
  // window elapses actually fires or re-arms.
  Timer? _celebrationDebounce;

  @override
  void initState() {
    super.initState();
    _flawlessConfetti =
        ConfettiController(duration: const Duration(seconds: 4));
    _loadCelebrationFlag();
  }

  Future<void> _loadCelebrationFlag() async {
    final flawless = await StreakCelebrationStore.flawlessCelebrated();
    if (!mounted) return;
    setState(() => _flawlessCelebrated = flawless);
    // Covers the case where the milestone is already active the first time
    // this loads (e.g. cold app open with an existing flawless streak).
    _scheduleCelebrationCheck(widget.perfectStreak >= _weekThreshold);
  }

  @override
  void didUpdateWidget(_StreakStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wasActive = oldWidget.perfectStreak >= _weekThreshold;
    final isActive = widget.perfectStreak >= _weekThreshold;
    // Only react to a genuine edge between consecutive widget updates — never
    // re-evaluated on rebuilds that don't actually change perfectStreak.
    if (wasActive != isActive) _scheduleCelebrationCheck(isActive);
  }

  @override
  void dispose() {
    _celebrationDebounce?.cancel();
    _flawlessConfetti.dispose();
    super.dispose();
  }

  /// The last 7 days ending on the grace-aware "today" so the final cell lines
  /// up with the stored daily-completion record even in the midnight–4 AM window.
  List<DateTime> _last7Days() {
    final now = DateTime.now();
    final base = DateTime(now.year, now.month, now.day);
    final graceToday =
        now.hour < 4 ? base.subtract(const Duration(days: 1)) : base;
    return List.generate(7, (i) => graceToday.subtract(Duration(days: 6 - i)));
  }

  String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Fires the one-time flawless-week celebration on a newly-reached edge, or
  /// re-arms the flag once the streak actually lapses — but only once the edge
  /// has held for the whole debounce window, so a same-session snapshot
  /// hiccup can't flip it twice.
  void _scheduleCelebrationCheck(bool isActive) {
    _celebrationDebounce?.cancel();
    _celebrationDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted || _flawlessCelebrated == null) return;
      final stillActive = widget.perfectStreak >= _weekThreshold;
      // The value moved again before the window elapsed — bail and let the
      // most recent call (which reset this timer) settle it instead.
      if (stillActive != isActive) return;

      if (stillActive && !_flawlessCelebrated!) {
        _flawlessCelebrated = true;
        StreakCelebrationStore.setFlawlessCelebrated(true);
        ConfettiGate.play(_flawlessConfetti, const Duration(seconds: 4));
      } else if (!stillActive && _flawlessCelebrated!) {
        _flawlessCelebrated = false;
        StreakCelebrationStore.setFlawlessCelebrated(false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final days = _last7Days();
    final todayKey = _key(days.last);
    final completion = widget.completion;
    final currentStreak = widget.currentStreak;

    // Per-day records: live today's record for the last cell, history lookups
    // for the prior six. Kept as full records so a tap can recap the day.
    final dayCompletions = days.map((d) {
      final key = _key(d);
      if (key == todayKey) return completion;
      return widget.dailyCompletions.firstWhere(
        (x) => x.date == key,
        orElse: () => DailyCompletion(date: key),
      );
    }).toList();
    final qualifying = dayCompletions.map((c) => c.countsForStreak).toList();

    final todayDone = completion.countsForStreak;

    // Milestone tiers are streak-driven (not the visible cells) so the glow
    // persists through an in-progress day and only clears when the streak
    // actually breaks.
    final perfectActive = currentStreak >= _weekThreshold;
    final flawlessActive = widget.perfectStreak >= _weekThreshold;
    final weekGlow = flawlessActive
        ? WeekGlow.flawless
        : perfectActive
            ? WeekGlow.perfect
            : WeekGlow.none;

    final (String subtitle, Color subtitleColor) = switch ((
      currentStreak,
      todayDone,
      flawlessActive,
      perfectActive,
    )) {
      (_, _, true, _) => (AppStrings.streakFlawlessWeek, AppColors.success),
      (_, _, _, true) => (AppStrings.streakPerfectWeek, AppColors.success),
      (0, false, _, _) => (
          AppStrings.streakStartToday,
          AppColors.textSecondary
        ),
      (_, true, _, _) => (AppStrings.streakLockedIn, AppColors.success),
      _ => (AppStrings.streakKeepGoing, AppColors.warning),
    };

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Headline: prominent streak count + tappable hint.
                Row(
                  children: [
                    const Icon(Icons.local_fire_department_rounded,
                        size: 22, color: AppColors.warning),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      '$currentStreak',
                      style: AppTextStyles.headlineLarge,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(
                        currentStreak == 1
                            ? AppStrings.streakDayStreak
                            : AppStrings.streakDaysStreak,
                        style: AppTextStyles.labelLarge
                            .copyWith(color: AppColors.textMuted),
                      ),
                    ),
                    if (weekGlow != WeekGlow.none) ...[
                      const SizedBox(width: AppSpacing.sm),
                      _WeekBadge(flawless: weekGlow == WeekGlow.flawless),
                    ],
                    const Spacer(),
                    const Icon(Icons.info_outline_rounded,
                        size: 16, color: AppColors.textMuted),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  subtitle,
                  style: AppTextStyles.bodySmall.copyWith(color: subtitleColor),
                ),
                const SizedBox(height: AppSpacing.md),
                // 7-day chain.
                WeekStreakChain(
                  weekGlow: weekGlow,
                  days: List.generate(days.length, (i) {
                    final isToday = i == days.length - 1;
                    final c = dayCompletions[i];
                    final StreakDayState state;
                    if (c.isPerfectDay) {
                      state = StreakDayState.perfect;
                    } else if (qualifying[i]) {
                      state = StreakDayState.qualifying;
                    } else if (isToday) {
                      state = StreakDayState.pending;
                    } else {
                      state = StreakDayState.missed;
                    }
                    return StreakDayData(
                      letter:
                          AppDateUtils.weekdayShort(days[i]).substring(0, 1),
                      state: state,
                      isToday: isToday,
                      onTap: () => showDayRecapSheet(context, days[i], c),
                    );
                  }),
                ),
                const SizedBox(height: AppSpacing.md),
                // Best + today's progress preserved as a compact secondary row.
                Row(
                  children: [
                    _MomentumItem(
                      icon: Icons.emoji_events_rounded,
                      color: AppColors.secondary,
                      value: '${widget.bestStreak}',
                      label: AppStrings.streakBest,
                    ),
                    const _MomentumDivider(),
                    _MomentumItem(
                      icon: completion.isPerfectDay
                          ? Icons.workspace_premium_rounded
                          : Icons.check_circle_outline_rounded,
                      color: completion.isPerfectDay
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      value: completion.isPerfectDay
                          ? 'Perfect'
                          : '${completion.completedCount}/${DailyCompletion.totalCount}',
                      label: AppStrings.streakToday,
                    ),
                  ],
                ),
              ],
            ),
            // One-time flawless-week celebration burst (top-center).
            ConfettiWidget(
              confettiController: _flawlessConfetti,
              blastDirectionality: BlastDirectionality.explosive,
              numberOfParticles: 90,
              gravity: 0.2,
              colors: const [
                AppColors.primary,
                AppColors.secondary,
                AppColors.warning,
                Colors.white,
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A small scale-in pill shown beside the streak count while a full-week
/// milestone glow is active. Flawless (all 9/9) reads warmer than perfect.
class _WeekBadge extends StatelessWidget {
  final bool flawless;

  const _WeekBadge({required this.flawless});

  @override
  Widget build(BuildContext context) {
    final color = flawless ? AppColors.warning : AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            flawless
                ? Icons.workspace_premium_rounded
                : Icons.local_fire_department_rounded,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            flawless
                ? AppStrings.streakFlawlessWeekBadge
                : AppStrings.streakPerfectWeekBadge,
            style: AppTextStyles.labelSmall.copyWith(
              color: color,
              fontSize: 9,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    )
        .animate()
        .scale(
          begin: const Offset(0.6, 0.6),
          end: const Offset(1.0, 1.0),
          duration: 500.ms,
          curve: Curves.elasticOut,
        )
        .fadeIn(duration: 250.ms);
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
          style:
              AppTextStyles.labelLarge.copyWith(color: AppColors.textPrimary),
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
