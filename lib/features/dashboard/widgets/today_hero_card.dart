import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/app_date_utils.dart';
import '../../../core/widgets/app_button.dart';
import '../../../models/user_profile.dart';
import '../../../models/daily_completion.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/daily_completion_provider.dart';
import 'daily_wins_shared.dart';
import 'plan_day_bottom_sheet.dart';

/// The dashboard's single "right now" hero. Resolves one time-aware action
/// (next morning step / next evening step / Today's Focus / set focus / on
/// track) and renders it as the screen's visual star — a soft accent gradient
/// card with a glow, no internal dividers.
class TodayHeroCard extends ConsumerStatefulWidget {
  final UserProfile profile;

  const TodayHeroCard({super.key, required this.profile});

  @override
  ConsumerState<TodayHeroCard> createState() => _TodayHeroCardState();
}

class _TodayHeroCardState extends ConsumerState<TodayHeroCard> {
  late final ConfettiController _confettiCtrl;
  bool _wasPerfect = false;
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

  /// Marks Today's Focus complete: persists the profile flag and the matching
  /// daily-completion flag, then celebrates.
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
      debugPrint('TodayHeroCard._completeFocus failed: $e');
      if (!mounted) return;
      setState(() => _focusCompleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final completion = ref.watch(dailyCompletionProvider);
    final isPerfect = completion.isPerfectDay;

    if (isPerfect && !_wasPerfect) {
      _wasPerfect = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _confettiCtrl.play());
    } else if (!isPerfect) {
      _wasPerfect = false;
    }

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

    // ── Focus state for today ─────────────────────────────────────────────
    final todayStr = AppDateUtils.todayString();
    final hasFocusToday = widget.profile.dailyFocusAction.isNotEmpty &&
        widget.profile.dailyFocusActionDate == todayStr;
    final focusComplete = widget.profile.dailyFocusActionCompleted;

    final planDayItem = WinItem(
      'dayPlanned',
      'Plan Day',
      hasFocusToday ? 'Focus Set' : 'Select Focus',
      Icons.check_circle_outline_rounded,
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
    ];

    final morningRequired = effectiveMorning.where((w) => !w.isBonus).toList();
    final eveningRequired = effectiveEvening.where((w) => !w.isBonus).toList();

    // ── Time-aware phase ──────────────────────────────────────────────────
    final period = AppDateUtils.sessionPeriod();
    final eveningActive = period == 'evening';

    final morningDone =
        morningRequired.every((w) => getCompletionField(completion, w.field));
    final eveningDone =
        eveningRequired.every((w) => getCompletionField(completion, w.field));

    final hero = _resolveHero(
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
    final showFocusOpenNote = eveningActive && hasFocusToday && !focusComplete;

    return Stack(
      alignment: Alignment.topCenter,
      children: [
        _HeroCard(
          data: hero,
          focusOpenNote:
              showFocusOpenNote ? _FocusOpenNote(onComplete: _completeFocus) : null,
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
  _HeroData _resolveHero({
    required DailyCompletion completion,
    required String period,
    required List<WinItem> morningRequired,
    required List<WinItem> eveningRequired,
    required bool morningDone,
    required bool eveningDone,
    required bool hasFocusToday,
    required bool focusComplete,
  }) {
    // Morning phase, routine unfinished → next morning item.
    if (period == 'morning' && !morningDone) {
      final item = firstIncomplete(completion, morningRequired)!;
      return _HeroData(
        icon: item.icon,
        accent: AppColors.warning,
        sessionLabel: AppStrings.morningSessionHero,
        title: item.label,
        subtitle: item.subtitle,
        buttonLabel: item.sessionOnly ? 'Start Session' : 'Begin',
        buttonIcon: Icons.arrow_forward_rounded,
        onPressed: winNavCallback(
          context: context,
          ref: ref,
          profile: widget.profile,
          field: item.field,
        ),
      );
    }

    // Evening phase, routine unfinished → next evening item.
    if (period == 'evening' && !eveningDone) {
      final item = firstIncomplete(completion, eveningRequired)!;
      return _HeroData(
        icon: item.icon,
        accent: AppColors.secondary,
        sessionLabel: AppStrings.eveningSessionHero,
        title: item.label,
        subtitle: item.subtitle,
        buttonLabel: item.sessionOnly ? 'Start Session' : 'Begin',
        buttonIcon: Icons.arrow_forward_rounded,
        onPressed: winNavCallback(
          context: context,
          ref: ref,
          profile: widget.profile,
          field: item.field,
        ),
      );
    }

    // Otherwise the day belongs to Today's Focus.
    if (hasFocusToday && !focusComplete) {
      return _HeroData(
        icon: Icons.my_location_rounded,
        accent: AppColors.primary,
        sessionLabel: AppStrings.heroFocusSessionLabel,
        title: AppStrings.focusCardTitle,
        subtitle: widget.profile.dailyFocusAction,
        buttonLabel: AppStrings.heroFocusButton,
        buttonIcon: Icons.check_circle_outline_rounded,
        isLoading: _focusCompleting,
        onPressed: _focusCompleting ? null : _completeFocus,
        isFocus: true,
      );
    }

    if (!hasFocusToday) {
      return _HeroData(
        icon: Icons.my_location_rounded,
        accent: AppColors.primary,
        sessionLabel: AppStrings.heroFocusSessionLabel,
        title: AppStrings.heroSetFocusLabel,
        subtitle: AppStrings.heroSetFocusSubtitle,
        buttonLabel: AppStrings.heroSetFocusButton,
        buttonIcon: Icons.add_rounded,
        onPressed: () => showPlanDaySheet(context, ref, widget.profile),
        isFocus: true,
      );
    }

    // Focus complete → calm "on track" / evening wrap-up state (no CTA).
    final calmTitle = (period == 'evening' && eveningDone)
        ? AppStrings.eveningRoutineComplete
        : AppStrings.heroOnTrackLabel;
    return _HeroData(
      icon: Icons.check_circle_rounded,
      accent: AppColors.success,
      sessionLabel: AppStrings.heroFocusSessionLabel,
      title: calmTitle,
      subtitle: AppStrings.heroOnTrackSubtitle,
    );
  }
}

// ── Hero data ─────────────────────────────────────────────────────────────────

class _HeroData {
  final IconData icon;
  final Color accent;
  final String sessionLabel;
  final String title;
  final String subtitle;
  final String? buttonLabel;
  final IconData? buttonIcon;
  final VoidCallback? onPressed;
  final bool isLoading;

  /// When true, the hero is the Today's Focus state and renders the signature
  /// purple-cyan nebula background (with a dark scrim for readability).
  final bool isFocus;

  const _HeroData({
    required this.icon,
    required this.accent,
    required this.sessionLabel,
    required this.title,
    required this.subtitle,
    this.buttonLabel,
    this.buttonIcon,
    this.onPressed,
    this.isLoading = false,
    this.isFocus = false,
  });
}

// ── Hero card (gradient surface, glow, no dividers) ───────────────────────────

class _HeroCard extends StatelessWidget {
  final _HeroData data;
  final Widget? focusOpenNote;

  const _HeroCard({required this.data, this.focusOpenNote});

  @override
  Widget build(BuildContext context) {
    final accent = data.accent;
    final isFocus = data.isFocus;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (focusOpenNote != null) ...[
          focusOpenNote!,
          const SizedBox(height: AppSpacing.md),
        ],
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
              child: Icon(data.icon, size: AppSpacing.iconXl, color: accent),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                    ),
                    child: Text(
                      data.sessionLabel,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: accent,
                        fontSize: 9,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(data.title, style: AppTextStyles.headlineSmall),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          data.subtitle,
          style: AppTextStyles.bodyMedium
              .copyWith(color: AppColors.textSecondary, height: 1.5),
        ),
        if (data.buttonLabel != null) ...[
          const SizedBox(height: AppSpacing.md),
          AppPrimaryButton(
            label: data.buttonLabel!,
            onPressed: data.onPressed,
            icon: data.buttonIcon,
            isLoading: data.isLoading,
            accentColor: accent,
          ),
        ],
      ],
    );

    // Focus state gets a purple-to-blue gradient (purple-dominant so it keeps
    // its identity) with a slightly stronger glow; other phases use their
    // single-accent tint.
    //
    // Each stop is pre-composited over surfaceElevated with Color.alphaBlend so
    // the gradient interpolates between fully opaque colors. Mixing translucent
    // stops with an opaque one (as before) makes the alpha jump mid-gradient,
    // which reads as a hard line instead of a smooth blend.
    final gradient = isFocus
        ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.alphaBlend(
                AppColors.primary.withValues(alpha: 0.30),
                AppColors.surfaceElevated,
              ),
              Color.alphaBlend(
                AppColors.primary.withValues(alpha: 0.12),
                AppColors.surfaceElevated,
              ),
              Color.alphaBlend(
                AppColors.secondary.withValues(alpha: 0.06),
                AppColors.surfaceElevated,
              ),
              AppColors.surfaceElevated,
            ],
            stops: const [0.0, 0.4, 0.7, 1.0],
          )
        : LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              accent.withValues(alpha: 0.12),
              AppColors.surfaceElevated,
            ],
          );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color:
                isFocus ? AppColors.primaryGlow : accent.withValues(alpha: 0.12),
            blurRadius: isFocus ? 28 : 24,
          ),
        ],
      ),
      child: content,
    );
  }
}

// ── Evening focus-open note (non-hero nudge) ──────────────────────────────────

class _FocusOpenNote extends StatelessWidget {
  final VoidCallback onComplete;

  const _FocusOpenNote({required this.onComplete});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.flag_outlined, size: 16, color: AppColors.textMuted),
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
    );
  }
}
