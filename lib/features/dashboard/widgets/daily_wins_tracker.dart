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
import '../../../providers/auth_provider.dart';
import '../../../providers/daily_completion_provider.dart';
import '../../mindset/affirmations_tab.dart';
import 'evidence_log_widget.dart';
import 'gratitude_log_widget.dart';
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
  _WinItem('dayPlanned', 'Plan Day', 'Select Focus', Icons.check_circle_outline_rounded),
  _WinItem('gratitudeLogged', 'Gratitude', 'Something you\'re grateful for', Icons.favorite_border_rounded, isBonus: true),
];

const _eveningWins = [
  _WinItem('affirmationsEvening', 'Affirmations', 'End Day', Icons.nightlight_round, sessionOnly: true),
  // Habits live in their own DailyHabitsCard below the tracker. The
  // `habitsCompleted` flag is auto-derived in HabitsNotifier and still counts
  // toward the streak / perfect day.
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

  // Today's Focus mark-complete state (folded in from the old FocusModeBanner)
  bool _focusCompleting = false;

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
      'dayPlanned' => c.dayPlanned,
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

  _WinItem? _firstIncomplete(DailyCompletion c, List<_WinItem> items) {
    for (final w in items) {
      if (!_getField(c, w.field)) return w;
    }
    return null;
  }

  void _toggle(String field, bool currentValue) {
    if (field == 'affirmationsMorning' || field == 'affirmationsEvening') return;
    ref.read(dailyCompletionProvider.notifier).toggle(field, !currentValue);
  }

  /// Marks Today's Focus complete. Mirrors the old FocusModeBanner: persists the
  /// profile flag and the matching daily-completion flag, then celebrates.
  Future<void> _completeFocus() async {
    setState(() => _focusCompleting = true);
    try {
      final uid = ref.read(authStateProvider).valueOrNull?.uid;
      if (uid != null) {
        await ref.read(firestoreServiceProvider).updateUserField(uid, {
          'dailyFocusActionCompleted': true,
        });
      }
      await ref
          .read(dailyCompletionProvider.notifier)
          .toggle('priorityActionsCompleted', true);
      if (!mounted) return;
      setState(() => _focusCompleting = false);
      _confettiCtrl.play();
    } catch (e) {
      debugPrint('DailyWinsTracker._completeFocus failed: $e');
      if (!mounted) return;
      setState(() => _focusCompleting = false);
    }
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
            context.push('/affirmations');
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
            context.push('/affirmations');
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
      'dayPlanned' => () => showPlanDaySheet(context, ref, widget.profile),
      'habitsCompleted' => () => context.go('/actions?tab=habits'),
      'chatCompleted' => () => context.go('/chat'),
      'gratitudeLogged' => () => showModalBottomSheet(
            context: context,
            backgroundColor: AppColors.surface,
            isScrollControlled: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppSpacing.radiusXl),
              ),
            ),
            builder: (_) => GratitudeLogWidget(profile: widget.profile),
          ),
      'evidenceLogged' => () => showModalBottomSheet(
            context: context,
            backgroundColor: AppColors.surface,
            isScrollControlled: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppSpacing.radiusXl),
              ),
            ),
            builder: (_) => EvidenceLogWidget(profile: widget.profile),
          ),
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

    // ── Focus state for today ─────────────────────────────────────────────
    final todayStr = AppDateUtils.todayString();
    final hasFocusToday = widget.profile.dailyFocusAction.isNotEmpty &&
        widget.profile.dailyFocusActionDate == todayStr;
    final focusComplete = widget.profile.dailyFocusActionCompleted;

    final planDayItem = _WinItem(
      'dayPlanned',
      'Plan Day',
      hasFocusToday ? 'Focus Set' : 'Select Focus',
      Icons.check_circle_outline_rounded,
    );

    final effectiveMorning = [
      ..._morningWins.where((w) =>
          w.field != 'journalCompleted' && w.field != 'dayPlanned'),
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

    // ── Time-aware phase ──────────────────────────────────────────────────
    // morning (4–12) → morning routine is the priority
    // transition (12–17) → Today's Focus is the priority (daytime)
    // evening (17–4) → evening routine is the priority
    final period = AppDateUtils.sessionPeriod();
    final morningActive = period == 'morning';
    final eveningActive = period == 'evening';

    final morningDone =
        morningRequired.every((w) => _getField(completion, w.field));
    final eveningDone =
        eveningRequired.every((w) => _getField(completion, w.field));

    final phaseAccent = switch (period) {
      'morning' => AppColors.warning,
      'transition' => AppColors.primary,
      _ => AppColors.secondary,
    };
    final phaseLabel = switch (period) {
      'morning' => AppStrings.phaseMorning,
      'transition' => AppStrings.phaseDaytime,
      _ => AppStrings.phaseEvening,
    };

    // ── Single-hero resolution (one CTA on the whole screen) ──────────────
    final hero = _resolveHero(
      context: context,
      completion: completion,
      period: period,
      morningRequired: morningRequired,
      eveningRequired: eveningRequired,
      morningDone: morningDone,
      eveningDone: eveningDone,
      hasFocusToday: hasFocusToday,
      focusComplete: focusComplete,
    );

    // Evening edge: focus left open at the end of the day — surface a gentle,
    // non-hero nudge so the evening routine still owns the hero slot.
    final showFocusOpenNote =
        eveningActive && hasFocusToday && !focusComplete;

    // ── Routine sections (active first, the other tucked behind it) ───────
    final morningSection = _SessionSection(
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
    );
    final eveningSection = _SessionSection(
      title: 'Evening Routine',
      icon: Icons.nightlight_rounded,
      accentColor: AppColors.secondary,
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
    );

    final List<Widget> sections = switch (period) {
      'morning' => [morningSection, eveningSection],
      'evening' => [eveningSection, morningSection],
      _ => [morningSection, eveningSection],
    };

    return Stack(
      alignment: Alignment.topCenter,
      children: [
        AppGlowCard(
          glowColor: phaseAccent.withValues(alpha: 0.12),
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header: phase chip + progress + streaks ──────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.cardPadding,
                  AppSpacing.md,
                  AppSpacing.cardPadding,
                  AppSpacing.md,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _PhaseChip(label: phaseLabel, accent: phaseAccent),
                    const SizedBox(width: AppSpacing.sm),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: isPerfect
                            ? AppColors.primary
                            : AppColors.surfaceElevated,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusFull),
                        border: Border.all(
                          color: isPerfect
                              ? AppColors.primary
                              : AppColors.border,
                        ),
                      ),
                      child: Text(
                        isPerfect
                            ? '🏆 Perfect!'
                            : '$completedCount/$totalCount',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: isPerfect
                              ? Colors.white
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.local_fire_department_rounded,
                      size: 12,
                      color: AppColors.textMuted,
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
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${_bestStreak}d',
                      style: AppTextStyles.labelSmall
                          .copyWith(color: AppColors.textPrimary),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: AppColors.border),

              // ── Evening focus-open nudge (non-hero) ──────────────────────
              if (showFocusOpenNote) _FocusOpenNote(onComplete: _completeFocus),

              // ── The single hero ─────────────────────────────────────────
              hero,

              const Divider(height: 1, color: AppColors.border),

              // ── Routine sections ─────────────────────────────────────────
              for (int i = 0; i < sections.length; i++) ...[
                if (i > 0) const Divider(height: 1, color: AppColors.border),
                sections[i],
              ],
            ],
          ),
        ).animate().fadeIn(duration: 400.ms),

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

  // ── Hero resolution ──────────────────────────────────────────────────────
  Widget _resolveHero({
    required BuildContext context,
    required DailyCompletion completion,
    required String period,
    required List<_WinItem> morningRequired,
    required List<_WinItem> eveningRequired,
    required bool morningDone,
    required bool eveningDone,
    required bool hasFocusToday,
    required bool focusComplete,
  }) {
    // Morning phase, routine unfinished → next morning item.
    if (period == 'morning' && !morningDone) {
      final item = _firstIncomplete(completion, morningRequired)!;
      return _HeroRegion(
        icon: item.icon,
        accent: AppColors.warning,
        sessionLabel: AppStrings.morningSessionHero,
        title: item.label,
        subtitle: item.subtitle,
        buttonLabel: item.sessionOnly ? 'Start Session' : 'Begin',
        buttonIcon: Icons.arrow_forward_rounded,
        onPressed: _navForField(context, item.field),
      );
    }

    // Evening phase, routine unfinished → next evening item.
    if (period == 'evening' && !eveningDone) {
      final item = _firstIncomplete(completion, eveningRequired)!;
      return _HeroRegion(
        icon: item.icon,
        accent: AppColors.secondary,
        sessionLabel: AppStrings.eveningSessionHero,
        title: item.label,
        subtitle: item.subtitle,
        buttonLabel: item.sessionOnly ? 'Start Session' : 'Begin',
        buttonIcon: Icons.arrow_forward_rounded,
        onPressed: _navForField(context, item.field),
      );
    }

    // Otherwise the day belongs to Today's Focus.
    if (hasFocusToday && !focusComplete) {
      return _HeroRegion(
        icon: Icons.my_location_rounded,
        accent: AppColors.primary,
        sessionLabel: AppStrings.heroFocusSessionLabel,
        title: AppStrings.focusCardTitle,
        subtitle: widget.profile.dailyFocusAction,
        buttonLabel: AppStrings.heroFocusButton,
        buttonIcon: Icons.check_circle_outline_rounded,
        isLoading: _focusCompleting,
        onPressed: _focusCompleting ? null : _completeFocus,
      );
    }

    if (!hasFocusToday) {
      return _HeroRegion(
        icon: Icons.my_location_rounded,
        accent: AppColors.primary,
        sessionLabel: AppStrings.heroFocusSessionLabel,
        title: AppStrings.heroSetFocusLabel,
        subtitle: AppStrings.heroSetFocusSubtitle,
        buttonLabel: AppStrings.heroSetFocusButton,
        buttonIcon: Icons.add_rounded,
        onPressed: () => showPlanDaySheet(context, ref, widget.profile),
      );
    }

    // Focus complete → calm "on track" / evening wrap-up state (no CTA).
    final calmTitle = (period == 'evening' && eveningDone)
        ? AppStrings.eveningRoutineComplete
        : AppStrings.heroOnTrackLabel;
    return _HeroRegion(
      icon: Icons.check_circle_rounded,
      accent: AppColors.success,
      sessionLabel: AppStrings.heroFocusSessionLabel,
      title: calmTitle,
      subtitle: AppStrings.heroOnTrackSubtitle,
    );
  }
}

// ── Phase chip ────────────────────────────────────────────────────────────────

class _PhaseChip extends StatelessWidget {
  final String label;
  final Color accent;

  const _PhaseChip({required this.label, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 3),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: Text(
        label.toUpperCase(),
        style: AppTextStyles.labelSmall.copyWith(
          color: accent,
          fontSize: 10,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// ── Hero region (single primary action, lives inside the Today card) ──────────

class _HeroRegion extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String sessionLabel;
  final String title;
  final String subtitle;
  final String? buttonLabel;
  final IconData? buttonIcon;
  final VoidCallback? onPressed;
  final bool isLoading;

  const _HeroRegion({
    required this.icon,
    required this.accent,
    required this.sessionLabel,
    required this.title,
    required this.subtitle,
    this.buttonLabel,
    this.buttonIcon,
    this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      color: accent.withValues(alpha: 0.05),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Icon(icon, size: AppSpacing.iconXl, color: accent),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusFull),
                      ),
                      child: Text(
                        sessionLabel,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: accent,
                          fontSize: 9,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(title, style: AppTextStyles.headlineSmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            subtitle,
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondary, height: 1.5),
          ),
          if (buttonLabel != null) ...[
            const SizedBox(height: AppSpacing.md),
            AppPrimaryButton(
              label: buttonLabel!,
              onPressed: onPressed,
              icon: buttonIcon,
              isLoading: isLoading,
              accentColor: accent,
            ),
          ],
        ],
      ),
    );
  }
}

// ── Evening focus-open note (non-hero nudge) ──────────────────────────────────

class _FocusOpenNote extends StatelessWidget {
  final VoidCallback onComplete;

  const _FocusOpenNote({required this.onComplete});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm + 2,
      ),
      child: Row(
        children: [
          const Icon(Icons.flag_outlined,
              size: 16, color: AppColors.textMuted),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              AppStrings.focusStillOpenNote,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          GestureDetector(
            onTap: onComplete,
            behavior: HitTestBehavior.opaque,
            child: Text(
              'Mark done',
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Session section (collapsible routine checklist, no own card) ──────────────

class _SessionSection extends StatelessWidget {
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

  const _SessionSection({
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
                    children: requiredItems
                        .map((w) => _ProgressDot(
                              filled: getField(completion, w.field),
                              color: dotColor,
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
                    accentColor: accentColor,
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
