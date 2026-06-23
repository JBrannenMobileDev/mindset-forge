import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/app_date_utils.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../models/user_profile.dart';
import '../../../models/daily_completion.dart';
import '../../../providers/affirmations_provider.dart';
import '../../../providers/daily_completion_provider.dart';
import '../../mindset/affirmations_tab.dart';
import 'plan_day_bottom_sheet.dart';

// ── Win item descriptor ───────────────────────────────────────────────────────

class _WinItem {
  final String field;
  final String label;
  final String subtitle;
  final IconData icon;
  final bool isBonus;
  // When true: completion status is read-only (no manual checkbox tap)
  final bool sessionOnly;

  const _WinItem(
    this.field,
    this.label,
    this.subtitle,
    this.icon, {
    this.isBonus = false,
    this.sessionOnly = false,
  });
}

const _morningWins = [
  _WinItem('identityRead', 'Identity', 'Read who you\'re becoming', Icons.person_outline_rounded),
  _WinItem('affirmationsMorning', 'Affirmations', 'Start Day', Icons.wb_sunny_outlined, sessionOnly: true),
  _WinItem('futureSelfCompleted', 'Future Self', 'Practice', Icons.auto_awesome_rounded),
  _WinItem('journalCompleted', 'Journal', 'Prime Mind', Icons.edit_note_rounded),
  _WinItem('priorityActionsCompleted', 'Plan Day', 'Select Focus', Icons.check_circle_outline_rounded),
  _WinItem('gratitudeLogged', 'Gratitude', 'Something you\'re grateful for', Icons.favorite_border_rounded, isBonus: true),
];

const _eveningWins = [
  _WinItem('affirmationsEvening', 'Affirmations', 'End Day', Icons.nightlight_round, sessionOnly: true),
  _WinItem('habitsCompleted', 'Habits', 'Daily habits', Icons.repeat_rounded),
  _WinItem('chatCompleted', 'Coach Chat', 'Check In', Icons.chat_bubble_outline_rounded),
  _WinItem('evidenceLogged', 'Evidence Log', 'Act like your future self', Icons.emoji_events_outlined, isBonus: true),
];

// ── Main widget ───────────────────────────────────────────────────────────────

class DailyWinsTracker extends ConsumerStatefulWidget {
  final UserProfile profile;

  const DailyWinsTracker({super.key, required this.profile});

  @override
  ConsumerState<DailyWinsTracker> createState() => _DailyWinsTrackerState();
}

class _DailyWinsTrackerState extends ConsumerState<DailyWinsTracker> {
  late final ConfettiController _confettiCtrl;
  bool _wasPerfect = false;

  // Whether each session's progress row is expanded to show the full list
  bool _morningExpanded = false;
  bool _eveningExpanded = false;

  @override
  void initState() {
    super.initState();
    _confettiCtrl = ConfettiController(duration: const Duration(seconds: 4));
  }

  @override
  void dispose() {
    _confettiCtrl.dispose();
    super.dispose();
  }

  int get _bestStreak {
    final completions = widget.profile.dailyCompletions;
    if (completions.isEmpty) return 0;
    final sorted = [...completions]..sort((a, b) => a.date.compareTo(b.date));
    int best = 0;
    int current = 0;
    DateTime? prev;

    for (final c in sorted) {
      if (c.completedCount == 0) {
        current = 0;
        prev = null;
        continue;
      }
      final parts = c.date.split('-');
      final date = DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
      if (prev == null || date.difference(prev).inDays == 1) {
        current++;
      } else {
        current = 1;
      }
      if (current > best) best = current;
      prev = date;
    }
    return best;
  }

  bool _getField(DailyCompletion c, String field) {
    return switch (field) {
      'habitsCompleted' => c.habitsCompleted,
      'priorityActionsCompleted' => c.priorityActionsCompleted,
      'affirmationsMorning' => c.affirmationsMorning,
      'affirmationsEvening' => c.affirmationsEvening,
      'futureSelfCompleted' => c.futureSelfCompleted,
      'journalCompleted' => c.journalCompleted,
      'chatCompleted' => c.chatCompleted,
      'identityRead' => c.identityRead,
      'gratitudeLogged' => c.gratitudeLogged,
      'evidenceLogged' => c.evidenceLogged,
      _ => false,
    };
  }

  void _toggle(String field, bool currentValue) {
    if (field == 'affirmationsMorning' || field == 'affirmationsEvening') return;
    ref.read(dailyCompletionProvider.notifier).toggle(field, !currentValue);
  }

  void _showIdentitySheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXl),
        ),
      ),
      builder: (sheetCtx) => Consumer(
        builder: (sheetCtx, sheetRef, _) {
          final completion = sheetRef.watch(dailyCompletionProvider);
          final alreadyRead = completion.identityRead;

          return DraggableScrollableSheet(
            initialChildSize: 0.65,
            maxChildSize: 0.9,
            minChildSize: 0.4,
            expand: false,
            builder: (_, scrollCtrl) => SingleChildScrollView(
              controller: scrollCtrl,
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  const Icon(
                    Icons.person_outline_rounded,
                    color: AppColors.primary,
                    size: 48,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text('Your Identity', style: AppTextStyles.headlineMedium),
                  const SizedBox(height: AppSpacing.lg),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      widget.profile.identityStatement.isNotEmpty
                          ? widget.profile.identityStatement
                          : 'No identity statement set yet.',
                      style: AppTextStyles.headlineSmall.copyWith(
                        fontStyle: FontStyle.italic,
                        height: 1.8,
                        color: AppColors.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Read this slowly. Let it sink in. This is who you are.',
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  if (!alreadyRead)
                    SizedBox(
                      width: double.infinity,
                      height: AppSpacing.buttonHeight,
                      child: ElevatedButton(
                        onPressed: () {
                          sheetRef
                              .read(dailyCompletionProvider.notifier)
                              .toggle('identityRead', true);
                          Navigator.pop(sheetCtx);
                        },
                        child: const Text('Done — I\'ve read this'),
                      ),
                    )
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          'Identity read for today',
                          style: AppTextStyles.labelLarge
                              .copyWith(color: AppColors.primary),
                        ),
                      ],
                    ),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  VoidCallback _navForField(BuildContext context, String field) {
    return switch (field) {
      'identityRead' => () => _showIdentitySheet(context),
      'affirmationsMorning' => () {
          final active = ref
              .read(affirmationsProvider)
              .where((a) => a.isActive)
              .toList();
          if (active.isEmpty) {
            context.go('/mindset?tab=1');
          } else {
            launchAffirmationSession(
              context: context,
              ref: ref,
              affirmations: active,
              sessionType: 'morning',
            );
          }
        },
      'affirmationsEvening' => () {
          final active = ref
              .read(affirmationsProvider)
              .where((a) => a.isActive)
              .toList();
          if (active.isEmpty) {
            context.go('/mindset?tab=1');
          } else {
            launchAffirmationSession(
              context: context,
              ref: ref,
              affirmations: active,
              sessionType: 'evening',
            );
          }
        },
      'futureSelfCompleted' => () => context.go('/future-self'),
      'journalCompleted' => () => context.go('/journal/new'),
      'priorityActionsCompleted' => () =>
          showPlanDaySheet(context, ref, widget.profile),
      'habitsCompleted' => () => context.go('/actions'),
      'chatCompleted' => () => context.go('/chat'),
      'gratitudeLogged' => () => context.go('/journal/new'),
      'evidenceLogged' => () => context.go('/future-self'),
      _ => () {},
    };
  }

  @override
  Widget build(BuildContext context) {
    final completion = ref.watch(dailyCompletionProvider);
    final completedCount = completion.completedCount;
    const totalCount = DailyCompletion.totalCount;
    final isPerfect = completion.isPerfectDay;

    if (isPerfect && !_wasPerfect) {
      _wasPerfect = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _confettiCtrl.play());
    } else if (!isPerfect) {
      _wasPerfect = false;
    }

    // ── Journal placement based on user preference ────────────────────────
    final journalPref = widget.profile.journalPreference;
    const journalItem = _WinItem(
      'journalCompleted',
      'Journal',
      'Prime Mind',
      Icons.edit_note_rounded,
    );
    final morningWithJournal = journalPref == 'morning' || journalPref == 'both';
    final eveningWithJournal = journalPref == 'evening' || journalPref == 'both';

    // ── Dynamic "Plan Day" tile sublabel ──────────────────────────────────
    final todayStr = () {
      final now = DateTime.now();
      return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    }();
    final hasFocusToday = widget.profile.dailyFocusAction.isNotEmpty &&
        widget.profile.dailyFocusActionDate == todayStr;
    final planDayItem = _WinItem(
      'priorityActionsCompleted',
      'Plan Day',
      hasFocusToday ? 'Focus Set' : 'Select Focus',
      Icons.check_circle_outline_rounded,
    );

    final effectiveMorning = [
      ..._morningWins
          .where((w) =>
              w.field != 'journalCompleted' &&
              w.field != 'priorityActionsCompleted')
          .map((w) => w),
      planDayItem,
      if (morningWithJournal) journalItem,
    ];
    final effectiveEvening = [
      if (eveningWithJournal) journalItem,
      ..._eveningWins,
    ];

    // ── Separate required vs bonus items for each session ─────────────────
    final morningRequired = effectiveMorning.where((w) => !w.isBonus).toList();
    final morningBonus = effectiveMorning.where((w) => w.isBonus).toList();
    final eveningRequired = effectiveEvening.where((w) => !w.isBonus).toList();
    final eveningBonus = effectiveEvening.where((w) => w.isBonus).toList();

    // ── Time-aware active session ─────────────────────────────────────────
    // Morning is exclusively active 4–11am. Evening/transition from noon on.
    final period = AppDateUtils.sessionPeriod();
    final morningActive = period == 'morning';
    final eveningActive = period == 'evening' || period == 'transition';

    // Hero card: first incomplete required item, then first incomplete bonus item.
    // When all required items are done, the hero pivots to the bonus practice
    // so gratitude (morning) and evidence log (evening) surface naturally as
    // the final ritual — the last thing the user does before closing the app.
    final activeRequired = morningActive ? morningRequired : eveningRequired;
    final activeBonus = morningActive ? morningBonus : eveningBonus;
    _WinItem? firstIncomplete;
    bool heroIsBonus = false;

    for (final w in activeRequired) {
      if (!_getField(completion, w.field)) {
        firstIncomplete = w;
        break;
      }
    }

    if (firstIncomplete == null && activeBonus.isNotEmpty) {
      for (final w in activeBonus) {
        if (!_getField(completion, w.field)) {
          firstIncomplete = w;
          heroIsBonus = true;
          break;
        }
      }
    }

    final activeSessionExpanded =
        morningActive ? _morningExpanded : _eveningExpanded;
    final showHero = firstIncomplete != null && !activeSessionExpanded;
    final heroAccentColor = morningActive ? AppColors.warning : AppColors.primary;
    final heroSessionLabel = heroIsBonus
        ? AppStrings.bonusPractice
        : (morningActive
            ? AppStrings.morningSessionHero
            : AppStrings.eveningSessionHero);

    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Tier 1: Compact header (title + badge + streaks in one row) ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(AppStrings.dailyWins, style: AppTextStyles.headlineSmall),
                const SizedBox(width: AppSpacing.sm),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: isPerfect
                        ? AppColors.primary
                        : AppColors.surfaceElevated,
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusFull),
                    border: Border.all(
                      color: isPerfect ? AppColors.primary : AppColors.border,
                    ),
                  ),
                  child: Text(
                    isPerfect
                        ? '🏆 Perfect!'
                        : '$completedCount/$totalCount',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: isPerfect ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                ),
                const Spacer(),
                const Icon(
                  Icons.local_fire_department_rounded,
                  size: 12,
                  color: AppColors.warning,
                ),
                const SizedBox(width: 3),
                Text(
                  '${widget.profile.currentStreak}d',
                  style: AppTextStyles.labelSmall
                      .copyWith(color: AppColors.textPrimary),
                ),
                const SizedBox(width: AppSpacing.sm),
                const Icon(
                  Icons.emoji_events_rounded,
                  size: 12,
                  color: AppColors.secondary,
                ),
                const SizedBox(width: 3),
                Text(
                  '${_bestStreak}d',
                  style: AppTextStyles.labelSmall
                      .copyWith(color: AppColors.textPrimary),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.md),

            // ── Tier 2: Hero card ──────────────────────────────────────────
            // Shows the active session's first incomplete item.
            // Hidden when the active session's progress row is expanded.
            if (showHero) ...[
              _NextUpCard(
                item: firstIncomplete,
                onTap: _navForField(context, firstIncomplete.field),
                accentColor: heroAccentColor,
                sessionLabel: heroSessionLabel,
              ).animate().fadeIn(duration: 300.ms),
              const SizedBox(height: AppSpacing.md),
            ],

            // ── Tier 3a: Morning session progress row ──────────────────────
            _SessionProgressRow(
              title: 'Morning Routine',
              icon: Icons.wb_sunny_rounded,
              accentColor: AppColors.warning,
              requiredItems: morningRequired,
              bonusItems: morningBonus,
              completion: completion,
              getField: _getField,
              onToggle: _toggle,
              navForField: (f) => _navForField(context, f),
              expanded: _morningExpanded,
              onToggleExpand: () =>
                  setState(() => _morningExpanded = !_morningExpanded),
              isActive: morningActive,
            ).animate().fadeIn(duration: 400.ms),

            const SizedBox(height: AppSpacing.sm),

            // ── Tier 3b: Evening session progress row ──────────────────────
            _SessionProgressRow(
              title: 'Evening Routine',
              icon: Icons.nightlight_rounded,
              accentColor: AppColors.primary,
              requiredItems: eveningRequired,
              bonusItems: eveningBonus,
              completion: completion,
              getField: _getField,
              onToggle: _toggle,
              navForField: (f) => _navForField(context, f),
              expanded: _eveningExpanded,
              onToggleExpand: () =>
                  setState(() => _eveningExpanded = !_eveningExpanded),
              isActive: eveningActive,
            ).animate().fadeIn(delay: 50.ms, duration: 400.ms),
          ],
        ),

        ConfettiWidget(
          confettiController: _confettiCtrl,
          blastDirectionality: BlastDirectionality.explosive,
          numberOfParticles: 40,
          gravity: 0.15,
          colors: const [
            AppColors.primary,
            AppColors.secondary,
            AppColors.warning,
            Colors.white,
          ],
        ),
      ],
    );
  }
}

// ── Next Up hero card ─────────────────────────────────────────────────────────

class _NextUpCard extends StatelessWidget {
  final _WinItem item;
  final VoidCallback onTap;
  final Color accentColor;
  // Session-aware label: 'MORNING SESSION' or 'EVENING SESSION'
  final String sessionLabel;

  const _NextUpCard({
    required this.item,
    required this.onTap,
    required this.accentColor,
    required this.sessionLabel,
  });

  @override
  Widget build(BuildContext context) {
    return AppGlowCard(
      glowColor: accentColor.withValues(alpha: 0.2),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon badge
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Icon(item.icon, size: AppSpacing.iconXl, color: accentColor),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Session label pill — reinforces the psychological framing
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                      ),
                      child: Text(
                        sessionLabel,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: accentColor,
                          fontSize: 9,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(item.label, style: AppTextStyles.headlineSmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            item.subtitle,
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          AppPrimaryButton(
            label: item.sessionOnly ? 'Start Session' : 'Begin',
            onPressed: onTap,
            icon: Icons.arrow_forward_rounded,
          ),
        ],
      ),
    );
  }
}

// ── Session progress row ──────────────────────────────────────────────────────

class _SessionProgressRow extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accentColor;
  final List<_WinItem> requiredItems;
  final List<_WinItem> bonusItems;
  final DailyCompletion completion;
  final bool Function(DailyCompletion, String) getField;
  final void Function(String, bool) onToggle;
  final VoidCallback Function(String) navForField;
  final bool expanded;
  final VoidCallback onToggleExpand;
  final bool isActive;

  const _SessionProgressRow({
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.requiredItems,
    required this.bonusItems,
    required this.completion,
    required this.getField,
    required this.onToggle,
    required this.navForField,
    required this.expanded,
    required this.onToggleExpand,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final doneCount =
        requiredItems.where((w) => getField(completion, w.field)).length;
    final allDone = doneCount == requiredItems.length;
    // Teaser: inactive session with no progress yet
    final isTeaser = !isActive && doneCount == 0;

    final rowIcon = allDone
        ? Icons.check_circle_rounded
        : (isTeaser ? Icons.lock_outline_rounded : icon);
    final iconColor = allDone
        ? AppColors.success
        : (isTeaser ? AppColors.textMuted : accentColor);
    final titleColor = allDone
        ? AppColors.success
        : (isTeaser ? AppColors.textMuted : AppColors.textSecondary);

    return Opacity(
      opacity: isTeaser ? 0.5 : 1.0,
      child: AppCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row (always visible) ─────────────────────────────
            InkWell(
              onTap: onToggleExpand,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
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
                      children: requiredItems
                          .map((w) => _ProgressDot(
                                filled: getField(completion, w.field),
                                color: allDone ? AppColors.success : accentColor,
                              ))
                          .toList(),
                    ),
                    const Spacer(),
                    Text(
                      '$doneCount/${requiredItems.length}',
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
                      done: getField(completion, requiredItems[i].field),
                      onTap: navForField(requiredItems[i].field),
                      onToggle: () => onToggle(
                        requiredItems[i].field,
                        getField(completion, requiredItems[i].field),
                      ),
                    ),
                  ],
                  // Bonus items shown in expanded state
                  if (bonusItems.isNotEmpty) ...[
                    const Divider(height: 1, color: AppColors.border),
                    for (final item in bonusItems)
                      _WinRow(
                        item: item,
                        done: getField(completion, item.field),
                        onTap: navForField(item.field),
                        onToggle: () => onToggle(
                          item.field,
                          getField(completion, item.field),
                        ),
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
      ),
    );
  }
}

// ── Progress dot ──────────────────────────────────────────────────────────────

class _ProgressDot extends StatelessWidget {
  final bool filled;
  final Color color;

  const _ProgressDot({required this.filled, required this.color});

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
  final _WinItem item;
  final bool done;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final bool showBonusChip;

  const _WinRow({
    required this.item,
    required this.done,
    required this.onTap,
    required this.onToggle,
    this.showBonusChip = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
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
                    ? AppColors.primaryContainer
                    : AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Icon(
                item.icon,
                size: 18,
                color: done ? AppColors.primary : AppColors.textMuted,
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
                            borderRadius: BorderRadius.circular(
                                AppSpacing.radiusFull),
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
                    color: done ? AppColors.primary : Colors.transparent,
                    border: Border.all(
                      color: done ? AppColors.primary : AppColors.border,
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
                      color: done ? AppColors.primary : Colors.transparent,
                      border: Border.all(
                        color: done ? AppColors.primary : AppColors.border,
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
