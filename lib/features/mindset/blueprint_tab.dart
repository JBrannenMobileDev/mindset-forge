import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/app_date_utils.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/section_header.dart';
import '../../models/blueprint_snapshot.dart';
import '../../models/user_profile.dart';
import '../../models/mindset_blueprint.dart';
import '../../providers/auth_provider.dart';

class BlueprintTab extends ConsumerWidget {
  final UserProfile profile;

  const BlueprintTab({super.key, required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blueprint = profile.mindsetBlueprint;
    final baseline = profile.originalMindsetBaseline;
    final hasSnapshot = profile.mindsetBlueprintSnapshotAt != null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPaddingH,
        AppSpacing.lg,
        AppSpacing.screenPaddingH,
        100,
      ),
      children: [
        Text(AppStrings.blueprint, style: AppTextStyles.headlineSmall),
        const SizedBox(height: AppSpacing.md),
        if (!profile.blueprintCompleted) ...[
          _BlueprintSetupCta(),
          const SizedBox(height: AppSpacing.md),
        ],
        if (profile.blueprintCompleted && !hasSnapshot) ...[
          _SnapshotPromptCard(),
          const SizedBox(height: AppSpacing.md),
        ],
        AppCard(
          child: Column(
            children: [
              SizedBox(
                height: 240,
                child: _BlueprintRadarChart(
                  blueprint: blueprint,
                  baseline: baseline,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const _ChartLegend(),
            ],
          ),
        ).animate().fadeIn(duration: 400.ms),
        if (hasSnapshot) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            AppStrings.blueprintLastSnapshot(
              AppDateUtils.formatRelative(
                DateTime.parse(profile.mindsetBlueprintSnapshotAt!),
              ),
            ),
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        _TraitList(blueprint: blueprint, baseline: baseline),
        if (profile.blueprintCompleted) ...[
          const SizedBox(height: AppSpacing.lg),
          AppPrimaryButton(
            label: AppStrings.blueprintSnapshotCta,
            onPressed: () => context.push('/blueprint-snapshot'),
            icon: Icons.camera_alt_rounded,
          ),
        ],
        if (profile.blueprintSnapshotHistory.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          SectionHeader(title: AppStrings.blueprintPastSnapshots),
          const SizedBox(height: AppSpacing.md),
          ...profile.blueprintSnapshotHistory.asMap().entries.map((e) {
            final snapshot = e.value;
            final parsed = DateTime.tryParse(snapshot.createdAt);
            final label = parsed != null
                ? AppDateUtils.formatDate(parsed)
                : snapshot.createdAt;
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _PastSnapshotTile(
                label: label,
                onTap: () => _showPastSnapshotSheet(
                  context,
                  snapshot: snapshot,
                  baseline: baseline,
                ),
              ).animate().fadeIn(
                    delay: Duration(milliseconds: e.key * 40),
                  ),
            );
          }),
        ],
        const SizedBox(height: AppSpacing.xl),
        Row(
          children: [
            Text(AppStrings.limitingBeliefs, style: AppTextStyles.headlineSmall),
            const Spacer(),
            AppTextButton(
              label: '+ Add',
              onPressed: () => _showAddBelief(context, ref, profile),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: profile.limitingBeliefs
              .map(
                (b) => _BeliefChip(
                  belief: b,
                  onRemove: () => _removeBelief(ref, profile, b),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: AppSpacing.xl),
        _FearsSection(profile: profile),
      ],
    );
  }

  void _showPastSnapshotSheet(
    BuildContext context, {
    required BlueprintSnapshot snapshot,
    required MindsetBlueprint baseline,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXl),
        ),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        maxChildSize: 0.85,
        minChildSize: 0.4,
        expand: false,
        builder: (_, ctrl) => SingleChildScrollView(
          controller: ctrl,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.xxxl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                DateTime.tryParse(snapshot.createdAt) != null
                    ? AppDateUtils.formatDate(
                        DateTime.parse(snapshot.createdAt),
                      )
                    : snapshot.createdAt,
                style: AppTextStyles.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.md),
              AppCard(
                child: SizedBox(
                  height: 220,
                  child: _BlueprintRadarChart(
                    blueprint: snapshot.blueprint,
                    baseline: baseline,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _TraitList(
                blueprint: snapshot.blueprint,
                baseline: baseline,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _removeBelief(
    WidgetRef ref,
    UserProfile profile,
    String belief,
  ) async {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;
    final updated =
        profile.limitingBeliefs.where((b) => b != belief).toList();
    await ref.read(firestoreServiceProvider).updateUserField(uid, {
      'limitingBeliefs': updated,
    });
  }

  Future<void> _addBelief(
    WidgetRef ref,
    UserProfile profile,
    String belief,
  ) async {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;
    final updated = [...profile.limitingBeliefs, belief.trim()];
    await ref.read(firestoreServiceProvider).updateUserField(uid, {
      'limitingBeliefs': updated,
    });
  }

  void _showAddBelief(
    BuildContext context,
    WidgetRef ref,
    UserProfile profile,
  ) {
    final ctrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Add Limiting Belief'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          style: AppTextStyles.bodyLarge,
          decoration: const InputDecoration(hintText: 'I am not...'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                _addBelief(ref, profile, ctrl.text);
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class _SnapshotPromptCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.secondaryContainer,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: const Icon(
              Icons.trending_up_rounded,
              color: AppColors.secondary,
              size: 18,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              AppStrings.blueprintSnapshotPrompt,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _LegendDot(color: AppColors.primary, label: AppStrings.blueprintChartCurrent),
        const SizedBox(width: AppSpacing.lg),
        _LegendDot(color: AppColors.textMuted, label: AppStrings.blueprintChartBaseline),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(color: AppColors.textMuted),
        ),
      ],
    );
  }
}

class _PastSnapshotTile extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PastSnapshotTile({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceElevated,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.secondaryContainer,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: const Icon(
                  Icons.architecture_rounded,
                  color: AppColors.secondary,
                  size: 18,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(label, style: AppTextStyles.labelLarge),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BlueprintSetupCta extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AppGlowCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text('Calibrate your blueprint',
                    style: AppTextStyles.labelLarge),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Rate your five core traits, mental toughness, and biggest fears so your coach can personalize everything to you.',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppPrimaryButton(
            label: 'Complete My Blueprint',
            onPressed: () => context.push('/blueprint-setup'),
            icon: Icons.arrow_forward_rounded,
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }
}

class _BlueprintRadarChart extends StatelessWidget {
  final MindsetBlueprint blueprint;
  final MindsetBlueprint baseline;

  const _BlueprintRadarChart({required this.blueprint, required this.baseline});

  @override
  Widget build(BuildContext context) {
    return RadarChart(
      RadarChartData(
        radarShape: RadarShape.polygon,
        dataSets: [
          RadarDataSet(
            dataEntries: [
              RadarEntry(value: blueprint.confidence),
              RadarEntry(value: blueprint.discipline),
              RadarEntry(value: blueprint.abundanceThinking),
              RadarEntry(value: blueprint.resilience),
              RadarEntry(value: blueprint.decisiveness),
            ],
            fillColor: AppColors.primary.withValues(alpha: 0.2),
            borderColor: AppColors.primary,
            borderWidth: 2,
            entryRadius: 4,
          ),
          RadarDataSet(
            dataEntries: [
              RadarEntry(value: baseline.confidence),
              RadarEntry(value: baseline.discipline),
              RadarEntry(value: baseline.abundanceThinking),
              RadarEntry(value: baseline.resilience),
              RadarEntry(value: baseline.decisiveness),
            ],
            fillColor: AppColors.border.withValues(alpha: 0.1),
            borderColor: AppColors.textMuted,
            borderWidth: 1,
            entryRadius: 2,
          ),
        ],
        radarBorderData: const BorderSide(color: AppColors.border),
        gridBorderData: const BorderSide(color: AppColors.border, width: 0.5),
        tickBorderData: const BorderSide(color: Colors.transparent),
        tickCount: 5,
        ticksTextStyle: const TextStyle(fontSize: 0),
        titleTextStyle: AppTextStyles.labelSmall,
        getTitle: (index, _) {
          const titles = [
            'Confidence',
            'Discipline',
            'Abundance',
            'Resilience',
            'Decisiveness',
          ];
          return RadarChartTitle(text: titles[index]);
        },
      ),
    );
  }
}

class _TraitList extends StatelessWidget {
  final MindsetBlueprint blueprint;
  final MindsetBlueprint baseline;

  const _TraitList({required this.blueprint, required this.baseline});

  @override
  Widget build(BuildContext context) {
    final traits = [
      (AppStrings.traitConfidence, blueprint.confidence, baseline.confidence),
      (AppStrings.traitDiscipline, blueprint.discipline, baseline.discipline),
      (
        AppStrings.traitAbundance,
        blueprint.abundanceThinking,
        baseline.abundanceThinking,
      ),
      (AppStrings.traitResilience, blueprint.resilience, baseline.resilience),
      (
        AppStrings.traitDecisiveness,
        blueprint.decisiveness,
        baseline.decisiveness,
      ),
    ];

    return Column(
      children: traits.map((t) {
        final delta = t.$2 - t.$3;
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Row(
            children: [
              SizedBox(
                width: 100,
                child: Text(
                  t.$1,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary),
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: t.$2 / 10,
                    backgroundColor: AppColors.border,
                    valueColor:
                        const AlwaysStoppedAnimation(AppColors.primary),
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                t.$2.toStringAsFixed(0),
                style: AppTextStyles.labelMedium
                    .copyWith(color: AppColors.primary),
              ),
              const SizedBox(width: AppSpacing.xs),
              if (delta != 0)
                Text(
                  delta > 0
                      ? '+${delta.toStringAsFixed(0)}'
                      : delta.toStringAsFixed(0),
                  style: AppTextStyles.labelSmall.copyWith(
                    color: delta > 0 ? AppColors.success : AppColors.error,
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ─── Fears to Outwit section ──────────────────────────────────────────────────

class _FearsSection extends StatelessWidget {
  final UserProfile profile;

  const _FearsSection({required this.profile});

  static const _fearDescriptions = <String, String>{
    'Fear of Failure':
        'You avoid action because the possibility of failing feels worse than not trying. Napoleon Hill called this "the sixth basic fear." Outwit it by reframing failure as data.',
    'Fear of Judgment':
        'The opinions of others weigh heavily on your decisions. You edit yourself to avoid criticism. Outwit it by recognizing that most people are too focused on themselves to notice your moves.',
    'Fear of Success':
        'Deep down, you fear the demands success would place on you. The new responsibilities, the higher expectations, the version of yourself you\'d have to become. Outwit it by pre-living your future self daily.',
    'Fear of Rejection':
        'Asking or putting yourself forward feels risky because you anticipate being turned down. Outwit it by detaching your worth from any single person\'s response.',
    'Fear of Uncertainty':
        'You need to see the full picture before acting. The unknown paralyzes rather than excites you. Outwit it by taking one small definite action every day.',
    'Imposter Syndrome':
        'You believe others will eventually discover you\'re not as capable as they think. You self-select out before being "found out." Outwit it by cataloguing your wins as evidence.',
    'Perfectionism':
        'Standards so high they prevent starting. You mistake perfect for good, and miss the reps that build real competence. Outwit it by shipping before you\'re ready.',
  };

  @override
  Widget build(BuildContext context) {
    final fears = profile.fearsDrift;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.remove_red_eye_rounded,
                color: AppColors.error, size: 18),
            const SizedBox(width: AppSpacing.sm),
            Text('Fears to Outwit', style: AppTextStyles.headlineSmall),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Inspired by Outwitting the Devil. These are the patterns keeping you stuck.',
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.md),
        if (fears.isEmpty)
          AppCard(
            child: Column(
              children: [
                const Icon(Icons.psychology_alt_rounded,
                    color: AppColors.textMuted, size: 32),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Take the fear quiz to unlock your fear profile.',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.md),
                AppSecondaryButton(
                  label: 'Take the Fear Quiz',
                  onPressed: () => context.push('/blueprint-setup'),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms)
        else
          Column(
            children: fears.asMap().entries.map((e) {
              final fear = e.value;
              final isPrimary = e.key == 0;
              final badgeColor = isPrimary ? AppColors.error : AppColors.warning;
              final badge = isPrimary ? 'Primary Fear' : 'Secondary Fear';
              final description = _fearDescriptions[fear] ??
                  'An identified drift pattern holding you back from your definite major purpose.';

              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: badgeColor.withValues(alpha: 0.12),
                              borderRadius:
                                  BorderRadius.circular(AppSpacing.radiusFull),
                              border: Border.all(
                                color: badgeColor.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              badge,
                              style: AppTextStyles.labelSmall
                                  .copyWith(color: badgeColor),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(fear, style: AppTextStyles.labelLarge),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        description,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(
                      delay: Duration(milliseconds: e.key * 100),
                      duration: 400.ms,
                    ),
              );
            }).toList(),
          ),
      ],
    );
  }
}

class _BeliefChip extends StatelessWidget {
  final String belief;
  final VoidCallback onRemove;

  const _BeliefChip({required this.belief, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            belief,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(width: AppSpacing.xs),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close_rounded,
                size: 14, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

/// Returns the trait name and formatted delta for the largest shift vs baseline.
(String trait, String delta) blueprintLargestShift(
  MindsetBlueprint current,
  MindsetBlueprint baseline,
) {
  final traits = [
    (AppStrings.traitDiscipline, current.discipline - baseline.discipline),
    (AppStrings.traitConfidence, current.confidence - baseline.confidence),
    (
      AppStrings.traitResilience,
      current.resilience - baseline.resilience,
    ),
    (
      AppStrings.traitDecisiveness,
      current.decisiveness - baseline.decisiveness,
    ),
    (
      AppStrings.traitAbundance,
      current.abundanceThinking - baseline.abundanceThinking,
    ),
  ];

  traits.sort((a, b) => b.$2.abs().compareTo(a.$2.abs()));
  final top = traits.first;
  final formatted = top.$2 >= 0
      ? '+${top.$2.toStringAsFixed(1)}'
      : top.$2.toStringAsFixed(1);
  return (top.$1, formatted);
}
