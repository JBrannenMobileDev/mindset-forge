import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/app_button.dart';
import '../../../models/user_profile.dart';
import '../../../models/hero_action.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/daily_completion_provider.dart';
import '../../../providers/future_self_provider.dart';
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
      final dc = ref.read(dailyCompletionProvider.notifier);
      // The #1 focus is the streak-counting win; completing it also satisfies
      // the scoring-only "any priority action done" signal.
      await dc.toggle('focusCompleted', true);
      await dc.toggle('priorityActionsCompleted', true);
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

    // Resolve the single "right now" action via the shared resolver (the same
    // one the home-screen widget uses) so the hero and widget never drift.
    final trait = ref.watch(embodimentTraitTodayProvider);
    final hero =
        _mapHeroAction(resolveHeroAction(widget.profile, completion), trait);

    return Stack(
      alignment: Alignment.topCenter,
      children: [
        _HeroCard(data: hero).animate().fadeIn(duration: 400.ms),
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

  // ── Map the shared HeroAction onto this card's visual model ──────────────
  _HeroData _mapHeroAction(HeroAction a, String? trait) {
    final accent = switch (a.kind) {
      HeroActionKind.morning => AppColors.warning,
      HeroActionKind.evening => AppColors.secondary,
      HeroActionKind.focus => AppColors.primary,
      HeroActionKind.setFocus => AppColors.primary,
      HeroActionKind.onTrack => AppColors.success,
    };

    switch (a.kind) {
      case HeroActionKind.morning:
      case HeroActionKind.evening:
        return _HeroData(
          icon: _iconForField(a.field),
          accent: accent,
          sessionLabel: a.sessionLabel,
          title: a.title,
          subtitle: a.subtitle,
          buttonLabel: a.isSessionOnly ? 'Start Session' : 'Begin',
          buttonIcon: Icons.arrow_forward_rounded,
          onPressed: winNavCallback(
            context: context,
            ref: ref,
            profile: widget.profile,
            field: a.field,
          ),
        );
      case HeroActionKind.focus:
        return _HeroData(
          icon: Icons.my_location_rounded,
          accent: accent,
          sessionLabel: a.sessionLabel,
          title: a.title,
          subtitle: a.subtitle,
          buttonLabel: AppStrings.heroFocusButton,
          buttonIcon: Icons.check_circle_outline_rounded,
          isLoading: _focusCompleting,
          onPressed: _focusCompleting ? null : _completeFocus,
          isFocus: true,
        );
      case HeroActionKind.setFocus:
        return _HeroData(
          icon: Icons.my_location_rounded,
          accent: accent,
          sessionLabel: a.sessionLabel,
          title: a.title,
          subtitle: a.subtitle,
          buttonLabel: AppStrings.heroSetFocusButton,
          buttonIcon: Icons.add_rounded,
          onPressed: () => showPlanDaySheet(context, ref, widget.profile),
          isFocus: true,
        );
      case HeroActionKind.onTrack:
        final hasTrait = trait != null && trait.isNotEmpty;
        return _HeroData(
          icon: Icons.check_circle_rounded,
          accent: accent,
          sessionLabel: a.sessionLabel,
          title: a.title,
          subtitle: a.subtitle,
          traitLine: hasTrait
              ? AppStrings.heroOnTrackTrait.replaceFirst('{trait}', trait)
              : null,
          onTraitTap: hasTrait
              ? () => showEvidenceLogSheet(context, widget.profile)
              : null,
        );
    }
  }

  IconData _iconForField(String field) => switch (field) {
        'identityRead' => Icons.person_outline_rounded,
        'affirmationsMorning' => Icons.wb_sunny_outlined,
        'affirmationsEvening' => Icons.nightlight_round,
        'futureSelfCompleted' => Icons.auto_awesome_rounded,
        'journalCompleted' => Icons.edit_note_rounded,
        'dayPlanned' => Icons.check_circle_outline_rounded,
        'chatCompleted' => Icons.chat_bubble_outline_rounded,
        'gratitudeLogged' => Icons.favorite_border_rounded,
        'evidenceLogged' => Icons.emoji_events_outlined,
        _ => Icons.bolt_rounded,
      };
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

  /// Optional Future Self embodiment lens shown on the on-track state ("Now
  /// move like someone who is ..."), tappable via [onTraitTap] to log evidence.
  final String? traitLine;
  final VoidCallback? onTraitTap;

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
    this.traitLine,
    this.onTraitTap,
  });
}

// ── Hero card (gradient surface, glow, no dividers) ───────────────────────────

class _HeroCard extends StatefulWidget {
  final _HeroData data;

  const _HeroCard({required this.data});

  @override
  State<_HeroCard> createState() => _HeroCardState();
}

class _HeroCardState extends State<_HeroCard>
    with SingleTickerProviderStateMixin {
  // Drives the comet that traverses the morning/evening card border. One full
  // 0→1 sweep maps to one lap around the border via GradientRotation.
  late final AnimationController _borderCtrl;

  @override
  void initState() {
    super.initState();
    _borderCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _borderCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final accent = data.accent;
    final isFocus = data.isFocus;

    final content = Column(
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
        if (data.traitLine != null) ...[
          const SizedBox(height: AppSpacing.md),
          GestureDetector(
            onTap: data.onTraitTap,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: AppColors.futureSelfAccent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(
                  color: AppColors.futureSelfAccent.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome_rounded,
                      size: 16, color: AppColors.futureSelfAccent),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      data.traitLine!,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.futureSelfAccent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (data.onTraitTap != null)
                    const Icon(Icons.arrow_forward_ios_rounded,
                        size: 12, color: AppColors.futureSelfAccent),
                ],
              ),
            ),
          ),
        ],
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
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.alphaBlend(
                accent.withValues(alpha: 0.28),
                AppColors.surfaceElevated,
              ),
              Color.alphaBlend(
                accent.withValues(alpha: 0.10),
                AppColors.surfaceElevated,
              ),
              AppColors.surfaceElevated,
            ],
            stops: const [0.0, 0.5, 1.0],
          );

    // Focus keeps its existing static treatment (flat border + purple glow).
    if (isFocus) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(color: AppColors.border, width: 1),
          boxShadow: const [
            BoxShadow(color: AppColors.primaryGlow, blurRadius: 28),
          ],
        ),
        child: content,
      );
    }

    // Morning / evening: a thin vibrant accent ring with a "comet" highlight
    // that continuously laps the border. The static card is passed as the
    // AnimatedBuilder child so only the ring repaints each frame.
    const borderWidth = 1.5;
    const innerRadius = AppSpacing.radiusLg - borderWidth;

    final card = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(innerRadius),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.18),
            blurRadius: 28,
          ),
        ],
      ),
      child: content,
    );

    return AnimatedBuilder(
      animation: _borderCtrl,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(borderWidth),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            gradient: SweepGradient(
              transform: GradientRotation(_borderCtrl.value * 2 * math.pi),
              colors: [
                accent.withValues(alpha: 0.15),
                accent.withValues(alpha: 0.15),
                accent.withValues(alpha: 0.45),
                accent,
                accent.withValues(alpha: 0.15),
                accent.withValues(alpha: 0.15),
              ],
              stops: const [0.0, 0.78, 0.85, 0.88, 0.94, 1.0],
            ),
          ),
          child: child,
        );
      },
      child: card,
    );
  }
}
