import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/app_date_utils.dart';
import '../../../core/widgets/app_card.dart';
import '../../../models/user_profile.dart';
import '../../../models/daily_completion.dart';
import '../../../providers/daily_completion_provider.dart';
import '../../../providers/priority_actions_provider.dart';
import 'daily_wins_shared.dart';
import 'plan_day_bottom_sheet.dart';

/// Quiet companion to [TodayHeroCard]: the full Morning + Evening routines as a
/// single calm checklist card that mirrors the daily habits card's visual
/// language. The active time-of-day session carries the accent; the other
/// recedes into a neutral palette.
class DailyRoutineCard extends ConsumerStatefulWidget {
  final UserProfile profile;

  const DailyRoutineCard({super.key, required this.profile});

  @override
  ConsumerState<DailyRoutineCard> createState() => _DailyRoutineCardState();
}

class _DailyRoutineCardState extends ConsumerState<DailyRoutineCard> {
  bool _morningExpanded = false;
  bool _eveningExpanded = false;

  @override
  Widget build(BuildContext context) {
    final completion = ref.watch(dailyCompletionProvider);

    // ── Journal placement based on user preference ────────────────────────
    final journalPref = widget.profile.journalPreference;
    const journalItem = WinItem(
      'journalCompleted',
      'Journal',
      'Prime Mind',
      Icons.edit_note_rounded,
    );
    final morningWithJournal = journalPref == 'morning' || journalPref == 'both';
    final eveningWithJournal = journalPref == 'evening' || journalPref == 'both';

    final todayStr = AppDateUtils.todayStringWithGracePeriod();
    final hasFocusToday = widget.profile.dailyFocusAction.isNotEmpty &&
        widget.profile.dailyFocusActionDate == todayStr;

    final planDayItem = WinItem(
      'dayPlanned',
      'Plan Day',
      hasFocusToday ? 'Focus Set' : 'Select Focus',
      Icons.check_circle_outline_rounded,
    );

    // The #1 focus completion — its own required win so the "doing" that drives
    // change is visible, not just implied by the hero. Subtitle surfaces the
    // chosen focus, or prompts to pick one when none is set yet.
    final focusItem = WinItem(
      'focusCompleted',
      AppStrings.focusWinLabel,
      hasFocusToday
          ? widget.profile.dailyFocusAction
          : AppStrings.focusWinSetPrompt,
      Icons.my_location_rounded,
    );

    final effectiveMorning = [
      ...morningWins.where(
          (w) => w.field != 'journalCompleted' && w.field != 'dayPlanned'),
      planDayItem,
      if (morningWithJournal) journalItem,
    ];
    final effectiveEvening = [
      if (eveningWithJournal) journalItem,
      ...eveningWins,
      focusItem,
    ];

    final morningRequired = effectiveMorning.where((w) => !w.isBonus).toList();
    final morningBonus = effectiveMorning.where((w) => w.isBonus).toList();
    final eveningRequired = effectiveEvening.where((w) => !w.isBonus).toList();
    final eveningBonus = effectiveEvening.where((w) => w.isBonus).toList();

    final period = AppDateUtils.sessionPeriod();
    final morningActive = period == 'morning';
    final eveningActive = period == 'evening';

    // Completing the focus must route through the priority-actions notifier so
    // the profile flag, completion win, and Action score all stay in sync (the
    // generic toggle would only flip the local win flag). When no focus is set
    // yet, send the user to Plan Day to pick one.
    void completeFocus() {
      if (hasFocusToday) {
        ref
            .read(priorityActionsProvider.notifier)
            .toggleComplete(widget.profile.dailyFocusAction);
      } else {
        showPlanDaySheet(context, ref, widget.profile);
      }
    }

    void toggle(String field, bool current) {
      if (field == 'focusCompleted') {
        completeFocus();
        return;
      }
      toggleField(ref, field, current);
    }

    VoidCallback navFor(String field) {
      if (field == 'focusCompleted') return completeFocus;
      return winNavCallback(
        context: context,
        ref: ref,
        profile: widget.profile,
        field: field,
      );
    }

    final morningSection = _SessionSection(
      title: 'Morning Routine',
      icon: Icons.wb_sunny_rounded,
      accentColor: AppColors.warning,
      requiredItems: morningRequired,
      bonusItems: morningBonus,
      completion: completion,
      onToggle: toggle,
      navForField: navFor,
      expanded: _morningExpanded,
      onToggleExpand: () =>
          setState(() => _morningExpanded = !_morningExpanded),
      isActive: morningActive,
    );
    final eveningSection = _SessionSection(
      title: 'Evening Routine',
      icon: Icons.nightlight_rounded,
      accentColor: AppColors.secondary,
      requiredItems: eveningRequired,
      bonusItems: eveningBonus,
      completion: completion,
      onToggle: toggle,
      navForField: navFor,
      expanded: _eveningExpanded,
      onToggleExpand: () =>
          setState(() => _eveningExpanded = !_eveningExpanded),
      isActive: eveningActive,
    );

    // Active session first; the other tucks behind it.
    final List<Widget> sections = switch (period) {
      'evening' => [eveningSection, morningSection],
      _ => [morningSection, eveningSection],
    };

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.cardPadding,
              AppSpacing.md,
              AppSpacing.cardPadding,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.checklist_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  AppStrings.dailyRoutine,
                  style: AppTextStyles.headlineSmall,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          for (int i = 0; i < sections.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.border),
            sections[i],
          ],
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }
}

// ── Session section (collapsible routine checklist) ───────────────────────────

class _SessionSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accentColor;
  final List<WinItem> requiredItems;
  final List<WinItem> bonusItems;
  final DailyCompletion completion;
  final void Function(String, bool) onToggle;
  final VoidCallback Function(String) navForField;
  final bool expanded;
  final VoidCallback onToggleExpand;
  final bool isActive;

  const _SessionSection({
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.requiredItems,
    required this.bonusItems,
    required this.completion,
    required this.onToggle,
    required this.navForField,
    required this.expanded,
    required this.onToggleExpand,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final doneCount = requiredItems
        .where((w) => getCompletionField(completion, w.field))
        .length;
    final bonusDoneCount = bonusItems
        .where((w) => getCompletionField(completion, w.field))
        .length;
    final displayTotal = requiredItems.length + bonusItems.length;
    final displayDone = doneCount + bonusDoneCount;
    final allDone = doneCount == requiredItems.length;
    // Teaser: inactive session with no progress yet
    final isTeaser = !isActive && doneCount == 0;

    // Only the active time-of-day session carries the accent color. The
    // inactive routine renders in a neutral palette regardless of progress so
    // a single color owns attention.
    final rowIcon = allDone
        ? Icons.check_circle_rounded
        : (isTeaser ? Icons.lock_outline_rounded : icon);
    final iconColor = !isActive
        ? AppColors.textMuted
        : (allDone ? AppColors.success : accentColor);
    final titleColor = !isActive
        ? AppColors.textMuted
        : (allDone ? AppColors.success : AppColors.textSecondary);
    final dotColor = !isActive
        ? AppColors.textMuted
        : (allDone ? AppColors.success : accentColor);

    return Opacity(
      opacity: isTeaser ? 0.55 : 1.0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row (always visible) ─────────────────────────────
          InkWell(
            onTap: onToggleExpand,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm + 2,
              ),
              child: Row(
                children: [
                  Icon(rowIcon, size: 16, color: iconColor),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    title,
                    style: AppTextStyles.bodySmall.copyWith(color: titleColor),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  // Progress dots
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ...requiredItems.map(
                        (w) => _ProgressDot(
                          filled: getCompletionField(completion, w.field),
                          color: dotColor,
                        ),
                      ),
                      ...bonusItems.map(
                        (w) => _ProgressDot(
                          filled: getCompletionField(completion, w.field),
                          color: !isActive
                              ? AppColors.textMuted
                              : AppColors.warning,
                          isBonus: true,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    '$displayDone/$displayTotal',
                    style: AppTextStyles.labelSmall
                        .copyWith(color: AppColors.textMuted),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
            ),
          ),

          // ── Inline expansion ─────────────────────────────────────────
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(height: 1, color: AppColors.border),
                for (int i = 0; i < requiredItems.length; i++) ...[
                  if (i > 0)
                    const Divider(
                      height: 1,
                      indent: 56,
                      endIndent: 0,
                      color: AppColors.border,
                    ),
                  _WinRow(
                    item: requiredItems[i],
                    done: getCompletionField(completion, requiredItems[i].field),
                    onTap: navForField(requiredItems[i].field),
                    onToggle: () => onToggle(
                      requiredItems[i].field,
                      getCompletionField(completion, requiredItems[i].field),
                    ),
                    accentColor: accentColor,
                  ),
                ],
                // Bonus items shown in expanded state
                if (bonusItems.isNotEmpty) ...[
                  const Divider(height: 1, color: AppColors.border),
                  for (final item in bonusItems)
                    _WinRow(
                      item: item,
                      done: getCompletionField(completion, item.field),
                      onTap: navForField(item.field),
                      onToggle: () => onToggle(
                        item.field,
                        getCompletionField(completion, item.field),
                      ),
                      accentColor: accentColor,
                      showBonusChip: true,
                    ),
                ],
              ],
            ),
            crossFadeState:
                expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
            sizeCurve: Curves.easeOut,
          ),
        ],
      ),
    );
  }
}

// ── Progress dot ──────────────────────────────────────────────────────────────

class _ProgressDot extends StatelessWidget {
  final bool filled;
  final Color color;
  final bool isBonus;

  const _ProgressDot({
    required this.filled,
    required this.color,
    this.isBonus = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 9,
      height: 9,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? color : Colors.transparent,
        border: Border.all(
          color: filled ? color : AppColors.border,
          width: 1.5,
        ),
      ),
    );
  }
}

// ── Win row ───────────────────────────────────────────────────────────────────

class _WinRow extends StatelessWidget {
  final WinItem item;
  final bool done;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final bool showBonusChip;
  final Color accentColor;

  const _WinRow({
    required this.item,
    required this.done,
    required this.onTap,
    required this.onToggle,
    required this.accentColor,
    this.showBonusChip = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + 2,
        ),
        child: Row(
          children: [
            // Icon badge
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: done
                    ? accentColor.withValues(alpha: 0.1)
                    : AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Icon(
                item.icon,
                size: 18,
                color: done ? accentColor : AppColors.textMuted,
              ),
            ),

            const SizedBox(width: AppSpacing.md),

            // Label + subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        item.label,
                        style: AppTextStyles.labelLarge.copyWith(
                          color: done
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                        ),
                      ),
                      if (showBonusChip) ...[
                        const SizedBox(width: AppSpacing.xs),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.warningContainer,
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusFull),
                          ),
                          child: Text(
                            'BONUS',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.warning,
                              fontSize: 9,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(item.subtitle, style: AppTextStyles.bodySmall),
                ],
              ),
            ),

            // Completion indicator
            if (item.sessionOnly)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.xs),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done ? accentColor : Colors.transparent,
                    border: Border.all(
                      color: done ? accentColor : AppColors.border,
                      width: 2,
                    ),
                  ),
                  child: done
                      ? const Icon(Icons.check_rounded,
                          size: 14, color: Colors.white)
                      : null,
                ),
              )
            else
              GestureDetector(
                onTap: onToggle,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: done ? accentColor : Colors.transparent,
                      border: Border.all(
                        color: done ? accentColor : AppColors.border,
                        width: 2,
                      ),
                    ),
                    child: done
                        ? const Icon(Icons.check_rounded,
                            size: 14, color: Colors.white)
                        : null,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
