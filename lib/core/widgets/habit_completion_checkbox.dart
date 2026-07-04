import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Circular "mark done" control shared by every habit check-in surface
/// (Habits tab card, per-habit detail screen, dashboard's Daily Habits card)
/// so the tap target, fill animation, and disabled styling for an
/// already-done/paused habit stay identical everywhere instead of being
/// re-implemented per screen.
class HabitCompletionCheckbox extends StatelessWidget {
  final bool isDone;
  final VoidCallback onTap;
  final bool enabled;
  final double size;
  final double? iconSize;

  const HabitCompletionCheckbox({
    super.key,
    required this.isDone,
    required this.onTap,
    this.enabled = true,
    this.size = 32,
    this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    final tappable = enabled && !isDone;
    return MouseRegion(
      cursor: tappable ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: tappable ? onTap : null,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: isDone ? AppColors.primary : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(
              color: isDone ? AppColors.primary : AppColors.border,
              width: 2,
            ),
          ),
          child: isDone
              ? Icon(Icons.check_rounded,
                  size: iconSize ?? size * 0.5625, color: Colors.white)
              : null,
        ),
      ),
    );
  }
}
