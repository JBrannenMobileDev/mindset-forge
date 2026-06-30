import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
class WeekStreakChain extends StatelessWidget {
  final List<StreakDayData> days;

  /// Whether the [StreakDayState.pending] (today) cell should pulse. Enabled on
  /// the user's own dashboard (a "complete me" nudge); off for the partner view.
  final bool pulseToday;

  const WeekStreakChain({
    super.key,
    required this.days,
    this.pulseToday = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: days.map((d) => _StreakDayCell(data: d, pulse: pulseToday)).toList(),
    );
  }
}

class _StreakDayCell extends StatelessWidget {
  final StreakDayData data;
  final bool pulse;

  const _StreakDayCell({required this.data, required this.pulse});

  @override
  Widget build(BuildContext context) {
    const double size = 32;
    final isToday = data.isToday;

    Widget dot;
    switch (data.state) {
      case StreakDayState.perfect:
        // Perfect day (9/9) — gradient + glow so it stands out from the crowd.
        dot = Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.warning, AppColors.primary],
            ),
            shape: BoxShape.circle,
            border:
                isToday ? Border.all(color: AppColors.primary, width: 2) : null,
            boxShadow: const [
              BoxShadow(color: AppColors.primaryGlow, blurRadius: 12),
            ],
          ),
          child: const Icon(Icons.local_fire_department_rounded,
              size: 16, color: Colors.white),
        );
      case StreakDayState.qualifying:
        // Streak day (5–8/9) — flat amber fire; today also gets a primary ring.
        dot = Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppColors.warning,
            shape: BoxShape.circle,
            border:
                isToday ? Border.all(color: AppColors.primary, width: 2) : null,
          ),
          child: const Icon(Icons.local_fire_department_rounded,
              size: 16, color: Colors.white),
        );
      case StreakDayState.pending:
        // The actionable target — hollow primary ring with a faint flame.
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
        if (pulse) {
          dot = dot
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .fadeIn()
              .scaleXY(begin: 0.92, end: 1.0, duration: 900.ms);
        }
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

    final column = Column(
      children: [
        Text(
          data.letter,
          style: AppTextStyles.labelSmall.copyWith(
            color: isToday ? AppColors.primary : AppColors.textMuted,
          ),
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
