import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';

/// Visual state of a single day in a [WeekStreakChain].
enum StreakDayState {
  /// All daily wins done (9/9) — gradient + glow.
  perfect,

  /// Streak-qualifying day (5–8/9) — flat amber flame.
  qualifying,

  /// Today, not yet qualifying — the actionable target (hollow primary ring).
  pending,

  /// A past day that did not qualify — visible gap (loss aversion).
  missed,
}

/// Milestone glow wrapped around the whole chain when the streak fills a week.
enum WeekGlow {
  /// No glow — the everyday state.
  none,

  /// 7+ qualifying days in a row — a calm primary edge glow.
  perfect,

  /// 7+ perfect (9/9) days in a row — a richer multi-hue edge glow.
  flawless,
}

/// One day's worth of data for [WeekStreakChain].
class StreakDayData {
  /// Single-char weekday label (e.g. "M").
  final String letter;
  final StreakDayState state;
  final bool isToday;

  /// Optional tap handler (e.g. open a day recap). When null the cell is inert.
  final VoidCallback? onTap;

  const StreakDayData({
    required this.letter,
    required this.state,
    this.isToday = false,
    this.onTap,
  });
}

/// A Duolingo-style 7-day streak chain: weekday letters above status dots.
/// Shared by the user's dashboard and the accountability partner view so the
/// chain reads identically in both places.
///
/// When [weekGlow] becomes non-[WeekGlow.none] the completed circles get a
/// richer, permanent "reward" treatment (brighter gradient + soft glow ring +
/// tinted labels) and play a one-time left-to-right "ignite" flare — the only
/// motion, and only on the achievement transition (never on relaunch).
class WeekStreakChain extends StatefulWidget {
  final List<StreakDayData> days;

  /// Milestone tier. Defaults to [WeekGlow.none] so the partner view (and any
  /// other caller) is unaffected and renders the plain everyday chain.
  final WeekGlow weekGlow;

  const WeekStreakChain({
    super.key,
    required this.days,
    this.weekGlow = WeekGlow.none,
  });

  @override
  State<WeekStreakChain> createState() => _WeekStreakChainState();
}

class _WeekStreakChainState extends State<WeekStreakChain>
    with SingleTickerProviderStateMixin {
  // One-shot sweep that lights the flames left-to-right when the week is first
  // completed. Idle otherwise (sits at 0), so completed circles just render
  // their static reward look with no motion.
  late final AnimationController _igniteCtrl;

  @override
  void initState() {
    super.initState();
    _igniteCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void didUpdateWidget(covariant WeekStreakChain oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Fire the ignite only when the milestone is newly reached this session.
    if (oldWidget.weekGlow == WeekGlow.none &&
        widget.weekGlow != WeekGlow.none) {
      _igniteCtrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _igniteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final days = widget.days;
    final n = days.length;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(n, (i) {
        // Stagger each cell's flare so the sweep travels across the row.
        final start = (n <= 1 ? 0.0 : (i / n) * 0.6).clamp(0.0, 0.6);
        final flare = CurvedAnimation(
          parent: _igniteCtrl,
          curve: Interval(start, (start + 0.4).clamp(0.0, 1.0),
              curve: Curves.easeOut),
        );
        return _StreakDayCell(
          data: days[i],
          weekGlow: widget.weekGlow,
          flare: flare,
        );
      }),
    );
  }
}

class _StreakDayCell extends StatelessWidget {
  final StreakDayData data;

  /// Milestone tier for the whole chain. When not [WeekGlow.none], completed
  /// cells get the static reward upgrade.
  final WeekGlow weekGlow;

  /// This cell's slice of the one-time ignite sweep. At rest (value 0 or 1) it
  /// contributes no motion; it only flares mid-sweep.
  final Animation<double> flare;

  const _StreakDayCell({
    required this.data,
    required this.weekGlow,
    required this.flare,
  });

  bool get _isCompleted =>
      data.state == StreakDayState.perfect ||
      data.state == StreakDayState.qualifying;

  bool get _isPerfect => data.state == StreakDayState.perfect;

  @override
  Widget build(BuildContext context) {
    const double size = 32;
    final isToday = data.isToday;
    final reward = weekGlow != WeekGlow.none;
    final flawless = weekGlow == WeekGlow.flawless;

    // Completed cells in a reward week read as "the prize": richer flames + a
    // soft, permanent glow ring so the chain clearly stands apart from a normal
    // good week.
    final rewardCompleted = reward && _isCompleted;

    Widget dot;
    switch (data.state) {
      case StreakDayState.perfect:
        // Perfect day (9/9) — gradient + glow so it stands out from the crowd.
        dot = Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: flawless
                  ? const [
                      AppColors.warning,
                      AppColors.primary,
                      AppColors.secondary,
                    ]
                  : const [AppColors.warning, AppColors.primary],
            ),
            shape: BoxShape.circle,
            border:
                isToday ? Border.all(color: AppColors.primary, width: 2) : null,
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryGlow,
                blurRadius: rewardCompleted ? 16 : 12,
              ),
            ],
          ),
          child: const Icon(Icons.local_fire_department_rounded,
              size: 16, color: Colors.white),
        );
      case StreakDayState.qualifying:
        // Streak day (5–8/9) — flat amber fire; today also gets a primary ring.
        // During a reward week it gains a soft glow ring so the whole completed
        // row reads as "lit", while staying clearly below a perfect day (which
        // adds a gradient + star badge).
        dot = Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppColors.warning,
            shape: BoxShape.circle,
            border:
                isToday ? Border.all(color: AppColors.primary, width: 2) : null,
            boxShadow: rewardCompleted
                ? [
                    BoxShadow(
                      color: flawless
                          ? AppColors.warning.withValues(alpha: 0.45)
                          : AppColors.primaryGlow,
                      blurRadius: 10,
                    ),
                  ]
                : null,
          ),
          child: const Icon(Icons.local_fire_department_rounded,
              size: 16, color: Colors.white),
        );
      case StreakDayState.pending:
        // The actionable target — hollow primary ring with a faint flame.
        // Stays untouched by the reward so it still reads as "finish today".
        dot = Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppColors.primaryContainer,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primary, width: 2),
          ),
          child: const Icon(Icons.local_fire_department_rounded,
              size: 16, color: AppColors.primary),
        );
      case StreakDayState.missed:
        dot = Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppColors.surfaceHighest,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.borderSubtle),
          ),
        );
    }

    // A fully-complete (9/9) day earns an always-on corner badge so it clearly
    // outranks a merely-qualifying day in any week. Wrapped before the flare so
    // it scales/pops with the flame during the ignite sweep.
    if (_isPerfect) {
      dot = Stack(
        clipBehavior: Clip.none,
        children: [
          dot,
          Positioned(
            top: -2,
            right: -2,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: AppColors.secondary,
                shape: BoxShape.circle,
                // Dark ring separates the badge from the flame beneath it.
                border: Border.all(color: AppColors.background, width: 1.5),
              ),
              child:
                  const Icon(Icons.star_rounded, size: 8, color: Colors.white),
            ),
          ),
        ],
      );
    }

    // Transient ignite flare: a quick scale pop + extra glow that peaks
    // mid-sweep and resolves to nothing (sin is 0 at both ends), so the cell
    // settles into its static reward look without lingering motion.
    if (rewardCompleted) {
      dot = AnimatedBuilder(
        animation: flare,
        child: dot,
        builder: (context, child) {
          final bump = math.sin(math.pi * flare.value);
          return Transform.scale(
            scale: 1 + 0.28 * bump,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: bump <= 0
                    ? null
                    : [
                        BoxShadow(
                          color:
                              (flawless ? AppColors.warning : AppColors.primary)
                                  .withValues(alpha: 0.6 * bump),
                          blurRadius: 18 * bump,
                          spreadRadius: 2 * bump,
                        ),
                      ],
              ),
              child: child,
            ),
          );
        },
      );
    }

    final labelColor = rewardCompleted
        ? (flawless ? AppColors.warning : AppColors.primary)
        : (isToday ? AppColors.primary : AppColors.textMuted);

    final column = Column(
      children: [
        Text(
          data.letter,
          style: AppTextStyles.labelSmall.copyWith(color: labelColor),
        ),
        const SizedBox(height: 6),
        dot,
      ],
    );

    if (data.onTap == null) return column;
    return GestureDetector(
      onTap: data.onTap,
      behavior: HitTestBehavior.opaque,
      child: column,
    );
  }
}
