import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/manifestation_scoring.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/responsive_layout.dart';
import '../../core/widgets/shimmer_widget.dart';
import '../../core/utils/breakpoints.dart';
import '../../models/subconscious_hero_action.dart';
import '../../models/user_profile.dart';
import '../../providers/auth_provider.dart';
import '../../providers/future_self_provider.dart';
import '../../providers/identity_provider.dart';
import '../../providers/streak_provider.dart';
import 'affirmations_tab.dart';

/// The Mindset hub — a practice-first surface with one resolved "do this now"
/// hero, compact management rows for affirmations and future self, identity,
/// and a single entry into progress tracking.
class MindsetScreen extends ConsumerWidget {
  const MindsetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: ResponsiveLayout(
          maxWidth: 680,
          child: profileAsync.when(
            loading: () => const _HubLoading(),
            error: (_, __) =>
                const ErrorState(message: 'Failed to load mindset data.'),
            data: (profile) => profile == null
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary))
                : _HubBody(profile: profile),
          ),
        ),
      ),
    );
  }
}

class _HubLoading extends StatelessWidget {
  const _HubLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.screenPaddingH, AppSpacing.lg,
          AppSpacing.screenPaddingH, 0),
      child: ShimmerList(count: 4),
    );
  }
}

class _HubBody extends ConsumerWidget {
  final UserProfile profile;

  const _HubBody({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fsSetup = ref.watch(futureSelfProvider);
    final fsDoneToday = ref.watch(futureSelfCompletedTodayProvider);
    final streak = ref.watch(streakProvider);
    final alignment = ManifestationScoring.calculate(profile);
    final hero = resolveSubconsciousHeroAction(profile, profile.todayCompletion);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (Breakpoints.isWideWidth(constraints.maxWidth)) {
          return _DesktopHub(
            profile: profile,
            hero: hero,
            fsHasPractice: fsSetup?.hasPractice ?? false,
            fsDoneToday: fsDoneToday,
            streak: streak,
            alignmentScore: alignment.overall.round(),
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screenPaddingH,
              AppSpacing.lg, AppSpacing.screenPaddingH, 100),
          children: [
            Text(AppStrings.mindset, style: AppTextStyles.headlineLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              AppStrings.mindsetHubSubtitle,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
            _SubconsciousPracticeHero(profile: profile, hero: hero)
                .animate()
                .fadeIn(duration: 350.ms),
            const SizedBox(height: AppSpacing.md),
            _PracticeRow(
              onTap: () => context.push('/affirmations'),
              icon: Icons.format_quote_rounded,
              iconColor: AppColors.primary,
              title: AppStrings.affirmations,
              subtitle: _affirmationsStatus(profile),
            ).animate().fadeIn(delay: 80.ms, duration: 350.ms),
            const SizedBox(height: AppSpacing.sm),
            _PracticeRow(
              onTap: () => context.push('/future-self'),
              icon: Icons.visibility_rounded,
              iconColor: AppColors.futureSelfAccent,
              title: AppStrings.futureSelf,
              subtitle: _futureSelfStatus(
                hasPractice: fsSetup?.hasPractice ?? false,
                completedToday: fsDoneToday,
              ),
            ).animate().fadeIn(delay: 120.ms, duration: 350.ms),
            const SizedBox(height: AppSpacing.sectionGap),
            _IdentityRow(statement: profile.identityStatement)
                .animate()
                .fadeIn(delay: 160.ms, duration: 350.ms),
            const SizedBox(height: AppSpacing.sectionGap),
            _ProgressEntryRow(
              profile: profile,
              streak: streak,
              alignmentScore: alignment.overall.round(),
            ).animate().fadeIn(delay: 200.ms, duration: 350.ms),
          ],
        );
      },
    );
  }
}

class _DesktopHub extends StatelessWidget {
  final UserProfile profile;
  final SubconsciousHeroAction hero;
  final bool fsHasPractice;
  final bool fsDoneToday;
  final int streak;
  final int alignmentScore;

  const _DesktopHub({
    required this.profile,
    required this.hero,
    required this.fsHasPractice,
    required this.fsDoneToday,
    required this.streak,
    required this.alignmentScore,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: WebContentFrame(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            0,
            AppSpacing.lg,
            0,
            AppSpacing.xxl,
          ),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppStrings.mindset, style: AppTextStyles.headlineLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              AppStrings.mindsetHubSubtitle,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
            _SubconsciousPracticeHero(profile: profile, hero: hero),
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _PracticeRow(
                    onTap: () => context.push('/affirmations'),
                    icon: Icons.format_quote_rounded,
                    iconColor: AppColors.primary,
                    title: AppStrings.affirmations,
                    subtitle: _affirmationsStatus(profile),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _PracticeRow(
                    onTap: () => context.push('/future-self'),
                    icon: Icons.visibility_rounded,
                    iconColor: AppColors.futureSelfAccent,
                    title: AppStrings.futureSelf,
                    subtitle: _futureSelfStatus(
                      hasPractice: fsHasPractice,
                      completedToday: fsDoneToday,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sectionGap),
            _IdentityRow(statement: profile.identityStatement),
            const SizedBox(height: AppSpacing.sectionGap),
            _ProgressEntryRow(
              profile: profile,
              streak: streak,
              alignmentScore: alignmentScore,
            ),
          ],
        ),
      ),
    ),
    );
  }
}

String _affirmationsStatus(UserProfile profile) {
  final active = profile.affirmations.where((a) => a.isActive).length;
  if (active == 0) return AppStrings.mindsetAffirmationsAddPrompt;
  return AppStrings.mindsetAffirmationsActiveCount(active);
}

String _futureSelfStatus({
  required bool hasPractice,
  required bool completedToday,
}) {
  if (!hasPractice) return AppStrings.futureSelfVisualizePrompt;
  if (completedToday) return AppStrings.futureSelfCompletedTodayCard;
  return AppStrings.futureSelfReturnToScene;
}

// ─── Practice hero ────────────────────────────────────────────────────────────

class _SubconsciousPracticeHero extends ConsumerWidget {
  final UserProfile profile;
  final SubconsciousHeroAction hero;

  const _SubconsciousPracticeHero({
    required this.profile,
    required this.hero,
  });

  Color _accentFor(SubconsciousHeroKind kind) => switch (kind) {
        SubconsciousHeroKind.morning => AppColors.warning,
        SubconsciousHeroKind.evening => AppColors.secondary,
        SubconsciousHeroKind.futureSelf => AppColors.futureSelfAccent,
        SubconsciousHeroKind.onTrack => AppColors.success,
      };

  IconData _iconFor(SubconsciousHeroKind kind) => switch (kind) {
        SubconsciousHeroKind.morning => Icons.wb_sunny_outlined,
        SubconsciousHeroKind.evening => Icons.nightlight_round,
        SubconsciousHeroKind.futureSelf => Icons.auto_awesome_rounded,
        SubconsciousHeroKind.onTrack => Icons.check_circle_rounded,
      };

  IconData? _buttonIconFor(SubconsciousHeroKind kind) => switch (kind) {
        SubconsciousHeroKind.onTrack => null,
        _ => Icons.arrow_forward_rounded,
      };

  void _onPressed(BuildContext context, WidgetRef ref) {
    switch (hero.kind) {
      case SubconsciousHeroKind.morning:
      case SubconsciousHeroKind.evening:
        final active =
            profile.affirmations.where((a) => a.isActive).toList();
        if (active.isEmpty) {
          context.push('/affirmations');
          return;
        }
        launchAffirmationSession(
          context: context,
          ref: ref,
          affirmations: active,
          sessionType:
              hero.kind == SubconsciousHeroKind.morning ? 'morning' : 'evening',
          completedSessionCount: affirmationSessionsCompletedCount(profile),
        );
      case SubconsciousHeroKind.futureSelf:
        context.push('/future-self');
      case SubconsciousHeroKind.onTrack:
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = _accentFor(hero.kind);
    final gradient = LinearGradient(
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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.18),
            blurRadius: 28,
          ),
        ],
      ),
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
                child: Icon(_iconFor(hero.kind),
                    size: AppSpacing.iconXl, color: accent),
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
                        hero.sessionLabel,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: accent,
                          fontSize: 9,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(hero.title, style: AppTextStyles.headlineSmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            hero.subtitle,
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondary, height: 1.5),
          ),
          if (hero.buttonLabel != null) ...[
            const SizedBox(height: AppSpacing.md),
            AppPrimaryButton(
              label: hero.buttonLabel!,
              onPressed: () => _onPressed(context, ref),
              icon: _buttonIconFor(hero.kind),
              accentColor: accent,
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Compact practice row ─────────────────────────────────────────────────────

class _PracticeRow extends StatelessWidget {
  final VoidCallback onTap;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  const _PracticeRow({
    required this.onTap,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.labelLarge),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

// ─── Identity (demoted) ───────────────────────────────────────────────────────

class _IdentityRow extends ConsumerStatefulWidget {
  final String statement;

  const _IdentityRow({required this.statement});

  @override
  ConsumerState<_IdentityRow> createState() => _IdentityRowState();
}

class _IdentityRowState extends ConsumerState<_IdentityRow> {
  late final TextEditingController _ctrl;
  bool _editing = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.statement);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(identityProvider.notifier)
          .updateStatement(_ctrl.text.trim());
      if (!mounted) return;
      setState(() {
        _saving = false;
        _editing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(AppStrings.errorGeneric),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasStatement = widget.statement.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.fingerprint_rounded,
                  color: AppColors.textSecondary, size: 16),
              const SizedBox(width: AppSpacing.sm),
              Text(
                AppStrings.identityStatementLabel,
                style: AppTextStyles.labelSmall
                    .copyWith(color: AppColors.textMuted),
              ),
              const Spacer(),
              if (!_editing)
                GestureDetector(
                  onTap: () => setState(() => _editing = true),
                  child: Icon(
                    hasStatement ? Icons.edit_rounded : Icons.add_rounded,
                    color: AppColors.textSecondary,
                    size: 18,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (_editing) ...[
            TextField(
              controller: _ctrl,
              autofocus: true,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              style: AppTextStyles.bodyMedium,
              cursorColor: AppColors.primary,
              decoration: InputDecoration(
                hintText: AppStrings.identityStatementHint,
                hintStyle: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textMuted),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AppTextButton(
                  label: AppStrings.cancel,
                  color: AppColors.textSecondary,
                  onPressed: _saving
                      ? null
                      : () => setState(() {
                            _ctrl.text = widget.statement;
                            _editing = false;
                          }),
                ),
                const SizedBox(width: AppSpacing.sm),
                AppTextButton(
                  label: _saving ? AppStrings.saving : AppStrings.save,
                  onPressed: _saving ? null : _save,
                ),
              ],
            ),
          ] else
            Text(
              hasStatement
                  ? widget.statement
                  : AppStrings.identityStatementEmpty,
              style: AppTextStyles.bodyMedium.copyWith(
                color: hasStatement
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
                fontStyle: hasStatement ? FontStyle.normal : FontStyle.italic,
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Progress entry ───────────────────────────────────────────────────────────

class _ProgressEntryRow extends StatelessWidget {
  final UserProfile profile;
  final int streak;
  final int alignmentScore;

  const _ProgressEntryRow({
    required this.profile,
    required this.streak,
    required this.alignmentScore,
  });

  @override
  Widget build(BuildContext context) {
    final blueprintIncomplete = !profile.blueprintCompleted;
    final subtitle = blueprintIncomplete
        ? AppStrings.mindsetCompleteBlueprintSubtitle
        : AppStrings.mindsetProgressEntryStatus(alignmentScore, streak);

    return GestureDetector(
      onTap: () => context.push(
        blueprintIncomplete ? '/blueprint-setup' : '/progress',
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.textMuted.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: const Icon(Icons.insights_rounded,
                  size: 18, color: AppColors.textSecondary),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppStrings.mindsetProgressEntryTitle,
                      style: AppTextStyles.labelLarge),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
