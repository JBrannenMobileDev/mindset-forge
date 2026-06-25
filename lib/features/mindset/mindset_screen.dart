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
import '../../models/manifestation_alignment.dart';
import '../../models/mindset_blueprint.dart';
import '../../models/user_profile.dart';
import '../../providers/auth_provider.dart';
import '../../providers/future_self_provider.dart';
import 'affirmations_tab.dart';
import 'widgets/alignment_detail_sheet.dart';

/// The Mindset hub, the Subconscious Foundation layer of the manifestation
/// pipeline. A single scrollable surface that frames identity work, the two
/// Layer-1 practices (Affirmations + Future Self), the Blueprint, and compact
/// links out to Alignment detail and the standalone Progress screen.
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
                    child:
                        CircularProgressIndicator(color: AppColors.primary))
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
    final alignment = ManifestationScoring.calculate(profile);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenPaddingH, AppSpacing.lg, AppSpacing.screenPaddingH, 100),
      children: [
        Text(AppStrings.mindset, style: AppTextStyles.headlineLarge),
        const SizedBox(height: AppSpacing.xs),
        Text(
          AppStrings.mindsetHubSubtitle,
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.lg),

        _IdentityCard(statement: profile.identityStatement)
            .animate()
            .fadeIn(duration: 350.ms),
        const SizedBox(height: AppSpacing.sectionGap),

        // ── Subconscious practices ──────────────────────────────────────
        Text(AppStrings.subconsciousPracticeTitle,
            style: AppTextStyles.headlineSmall),
        const SizedBox(height: AppSpacing.xs),
        Text(AppStrings.subconsciousPracticeSubtitle,
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: AppSpacing.md),
        _AffirmationsCard(profile: profile)
            .animate()
            .fadeIn(delay: 80.ms, duration: 350.ms),
        const SizedBox(height: AppSpacing.md),
        _FutureSelfCard(
          hasPractice: fsSetup?.hasPractice ?? false,
          completedToday: fsDoneToday,
        ).animate().fadeIn(delay: 160.ms, duration: 350.ms),
        const SizedBox(height: AppSpacing.sectionGap),

        // ── Blueprint ───────────────────────────────────────────────────
        Text(AppStrings.blueprint, style: AppTextStyles.headlineSmall),
        const SizedBox(height: AppSpacing.md),
        _BlueprintCard(profile: profile)
            .animate()
            .fadeIn(delay: 80.ms, duration: 350.ms),
        const SizedBox(height: AppSpacing.sectionGap),

        // ── Alignment + Progress ────────────────────────────────────────
        _AlignmentChip(
          alignment: alignment,
          onTap: () => showAlignmentDetailSheet(context, profile),
        ),
        const SizedBox(height: AppSpacing.md),
        _MomentumLink(onTap: () => context.push('/progress')),
      ],
    );
  }
}

// ─── Identity ─────────────────────────────────────────────────────────────────

class _IdentityCard extends ConsumerStatefulWidget {
  final String statement;

  const _IdentityCard({required this.statement});

  @override
  ConsumerState<_IdentityCard> createState() => _IdentityCardState();
}

class _IdentityCardState extends ConsumerState<_IdentityCard> {
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
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;
    setState(() => _saving = true);
    await ref.read(firestoreServiceProvider).updateUserField(uid, {
      'identityStatement': _ctrl.text.trim(),
    });
    if (!mounted) return;
    setState(() {
      _saving = false;
      _editing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasStatement = widget.statement.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryContainer, AppColors.surfaceElevated],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.fingerprint_rounded,
                  color: AppColors.primary, size: 18),
              const SizedBox(width: AppSpacing.sm),
              Text(AppStrings.identityStatementLabel,
                  style: AppTextStyles.labelSmall
                      .copyWith(color: AppColors.primary)),
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
              style: AppTextStyles.bodyLarge,
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
                  label: 'Cancel',
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
                  label: _saving ? 'Saving…' : 'Save',
                  onPressed: _saving ? null : _save,
                ),
              ],
            ),
          ] else
            Text(
              hasStatement
                  ? widget.statement
                  : AppStrings.identityStatementEmpty,
              style: AppTextStyles.bodyLarge.copyWith(
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

// ─── Affirmations ───────────────────────────────────────────────────────────

class _AffirmationsCard extends ConsumerWidget {
  final UserProfile profile;

  const _AffirmationsCard({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = profile.affirmations.where((a) => a.isActive).toList();
    final today = profile.todayCompletion;

    return _HubCard(
      onTap: () => context.push('/affirmations'),
      icon: Icons.format_quote_rounded,
      iconColor: AppColors.primary,
      title: AppStrings.affirmations,
      subtitle: active.isEmpty
          ? 'Add affirmations to start your daily reprogramming'
          : '${active.length} active for morning and evening',
      footer: active.isEmpty
          ? null
          : Row(
              children: [
                Expanded(
                  child: _SessionButton(
                    label: AppStrings.morningSession,
                    icon: Icons.wb_sunny_rounded,
                    color: AppColors.warning,
                    done: today.affirmationsMorning,
                    onTap: () => launchAffirmationSession(
                      context: context,
                      ref: ref,
                      affirmations: active,
                      sessionType: 'morning',
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _SessionButton(
                    label: AppStrings.eveningSession,
                    icon: Icons.nightlight_round,
                    color: AppColors.secondary,
                    done: today.affirmationsEvening,
                    onTap: () => launchAffirmationSession(
                      context: context,
                      ref: ref,
                      affirmations: active,
                      sessionType: 'evening',
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _SessionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool done;
  final VoidCallback onTap;

  const _SessionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.done,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm + 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: done ? 0.18 : 0.10),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: color.withValues(alpha: done ? 0.5 : 0.25)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(done ? Icons.check_circle_rounded : icon,
                color: color, size: 16),
            const SizedBox(width: AppSpacing.xs + 2),
            Text(label,
                style: AppTextStyles.labelSmall.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}

// ─── Future Self ────────────────────────────────────────────────────────────

class _FutureSelfCard extends StatelessWidget {
  final bool hasPractice;
  final bool completedToday;

  const _FutureSelfCard({
    required this.hasPractice,
    required this.completedToday,
  });

  @override
  Widget build(BuildContext context) {
    return _HubCard(
      onTap: () => context.push('/future-self'),
      icon: Icons.visibility_rounded,
      iconColor: AppColors.futureSelfAccent,
      title: AppStrings.futureSelf,
      subtitle: !hasPractice
          ? 'Visualize the person you are becoming'
          : completedToday
              ? 'Completed today, you returned to the scene'
              : 'Return to your scene for today',
      trailing: !hasPractice
          ? const _MiniPill(label: AppStrings.futureSelfCreate)
          : completedToday
              ? const Icon(Icons.check_circle_rounded,
                  color: AppColors.success, size: 22)
              : const _MiniPill(
                  label: 'Start',
                  color: AppColors.futureSelfAccent,
                ),
    );
  }
}

// ─── Blueprint ──────────────────────────────────────────────────────────────

class _BlueprintCard extends StatelessWidget {
  final UserProfile profile;

  const _BlueprintCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    if (!profile.blueprintCompleted) {
      return _HubCard(
        onTap: () => context.push('/blueprint-setup'),
        icon: Icons.architecture_rounded,
        iconColor: AppColors.secondary,
        title: 'Complete your Blueprint',
        subtitle: 'Map your mindset traits to personalize everything',
        trailing: const _MiniPill(label: 'Start', color: AppColors.secondary),
      );
    }

    final bp = profile.mindsetBlueprint;
    final baseline = profile.originalMindsetBaseline;
    final delta = _avg(bp) - _avg(baseline);
    final strongest = _strongest(bp);

    return _HubCard(
      onTap: () => context.push('/blueprint'),
      icon: Icons.architecture_rounded,
      iconColor: AppColors.secondary,
      title: AppStrings.blueprint,
      subtitle: 'Strongest trait $strongest',
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            delta >= 0
                ? '+${delta.toStringAsFixed(1)}'
                : delta.toStringAsFixed(1),
            style: AppTextStyles.headlineSmall.copyWith(
              color: delta >= 0 ? AppColors.success : AppColors.warning,
            ),
          ),
          Text('since start', style: AppTextStyles.labelSmall),
        ],
      ),
    );
  }

  double _avg(MindsetBlueprint b) =>
      (b.confidence +
          b.discipline +
          b.abundanceThinking +
          b.resilience +
          b.decisiveness) /
      5;

  String _strongest(MindsetBlueprint b) {
    final traits = {
      'Confidence': b.confidence,
      'Discipline': b.discipline,
      'Abundance': b.abundanceThinking,
      'Resilience': b.resilience,
      'Decisiveness': b.decisiveness,
    };
    return (traits.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .first
        .key;
  }
}

// ─── Alignment chip + Progress link ───────────────────────────────────────────

class _AlignmentChip extends StatelessWidget {
  final ManifestationAlignment alignment;
  final VoidCallback onTap;

  const _AlignmentChip({required this.alignment, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: AppColors.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  alignment.overall.toStringAsFixed(0),
                  style: AppTextStyles.labelLarge
                      .copyWith(color: AppColors.primary),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Manifestation Alignment',
                      style: AppTextStyles.labelLarge),
                  Text('${alignment.masteryLevel}, tap for breakdown',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textSecondary)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _MomentumLink extends StatelessWidget {
  final VoidCallback onTap;

  const _MomentumLink({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: AppColors.warningContainer,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.local_fire_department_rounded,
                  color: AppColors.warning, size: 22),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Momentum & Progress',
                      style: AppTextStyles.labelLarge),
                  Text('Streaks, perfect days, and your activity heatmap',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textSecondary)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

// ─── Shared hub card ──────────────────────────────────────────────────────────

class _HubCard extends StatelessWidget {
  final VoidCallback onTap;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final Widget? footer;

  const _HubCard({
    required this.onTap,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Row(
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
                      Text(subtitle,
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                trailing ??
                    const Icon(Icons.chevron_right_rounded,
                        color: AppColors.textMuted),
              ],
            ),
            if (footer != null) ...[
              const SizedBox(height: AppSpacing.md),
              footer!,
            ],
          ],
        ),
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  final String label;
  final Color color;

  const _MiniPill({required this.label, this.color = AppColors.primary});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs + 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label,
          style: AppTextStyles.labelSmall.copyWith(color: color)),
    );
  }
}
