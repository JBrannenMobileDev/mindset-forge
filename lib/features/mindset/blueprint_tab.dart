import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/app_strings.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_button.dart';
import '../../models/user_profile.dart';
import '../../models/mindset_blueprint.dart';
import '../../providers/auth_provider.dart';
import '../../providers/claude_provider.dart';

class BlueprintTab extends ConsumerStatefulWidget {
  final UserProfile profile;

  const BlueprintTab({super.key, required this.profile});

  @override
  ConsumerState<BlueprintTab> createState() => _BlueprintTabState();
}

class _BlueprintTabState extends ConsumerState<BlueprintTab> {
  bool _isGeneratingSummary = false;
  String? _summary;

  @override
  void initState() {
    super.initState();
    _summary = null;
  }

  Future<void> _generateSummary() async {
    setState(() => _isGeneratingSummary = true);
    try {
      final result = await ref.read(claudeServiceProvider).generateMindsetSummary(widget.profile);
      if (!mounted) return;
      setState(() => _summary = result);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.errorAI)),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingSummary = false);
    }
  }

  Future<void> _removeBelief(String belief) async {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;
    final updated = widget.profile.limitingBeliefs.where((b) => b != belief).toList();
    await ref.read(firestoreServiceProvider).updateUserField(uid, {'limitingBeliefs': updated});
  }

  Future<void> _addBelief(String belief) async {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;
    final updated = [...widget.profile.limitingBeliefs, belief.trim()];
    await ref.read(firestoreServiceProvider).updateUserField(uid, {'limitingBeliefs': updated});
  }

  @override
  Widget build(BuildContext context) {
    final blueprint = widget.profile.mindsetBlueprint;
    final baseline = widget.profile.originalMindsetBaseline;

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
        AppCard(
          child: SizedBox(
            height: 240,
            child: _BlueprintRadarChart(blueprint: blueprint, baseline: baseline),
          ),
        ).animate().fadeIn(duration: 400.ms),
        const SizedBox(height: AppSpacing.md),
        _TraitList(blueprint: blueprint, baseline: baseline),
        const SizedBox(height: AppSpacing.lg),
        AppSecondaryButton(
          label: 'Generate Analysis',
          isLoading: _isGeneratingSummary,
          onPressed: _generateSummary,
          icon: Icons.auto_awesome_rounded,
        ),
        if (_summary != null) ...[
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Text(
              _summary!,
              style: AppTextStyles.bodyMedium.copyWith(height: 1.7),
            ),
          ).animate().fadeIn(duration: 500.ms),
        ],
        const SizedBox(height: AppSpacing.xl),
        Row(
          children: [
            Text(AppStrings.limitingBeliefs, style: AppTextStyles.headlineSmall),
            const Spacer(),
            AppTextButton(
              label: '+ Add',
              onPressed: () => _showAddBelief(context),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: widget.profile.limitingBeliefs.map((b) => _BeliefChip(
                belief: b,
                onRemove: () => _removeBelief(b),
              )).toList(),
        ),

        const SizedBox(height: AppSpacing.xl),
        _FearsSection(profile: widget.profile),
      ],
    );
  }

  void _showAddBelief(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Add Limiting Belief'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
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
                _addBelief(ctrl.text);
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
          final titles = ['Confidence', 'Discipline', 'Abundance', 'Resilience', 'Decisiveness'];
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
      (AppStrings.traitAbundance, blueprint.abundanceThinking, baseline.abundanceThinking),
      (AppStrings.traitResilience, blueprint.resilience, baseline.resilience),
      (AppStrings.traitDecisiveness, blueprint.decisiveness, baseline.decisiveness),
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
                child: Text(t.$1, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: t.$2 / 10,
                    backgroundColor: AppColors.border,
                    valueColor: AlwaysStoppedAnimation(AppColors.primary),
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                t.$2.toStringAsFixed(0),
                style: AppTextStyles.labelMedium.copyWith(color: AppColors.primary),
              ),
              const SizedBox(width: AppSpacing.xs),
              if (delta != 0)
                Text(
                  delta > 0 ? '+${delta.toStringAsFixed(0)}' : delta.toStringAsFixed(0),
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
        'Deep down, you fear what succeeding would demand of you — new responsibilities, expectations, or a changed identity. Outwit it by pre-living your future self daily.',
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
            const Icon(Icons.remove_red_eye_rounded, color: AppColors.error, size: 18),
            const SizedBox(width: AppSpacing.sm),
            Text('Fears to Outwit', style: AppTextStyles.headlineSmall),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'From Outwitting the Devil — your drift patterns made visible.',
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
                  'Complete the onboarding fear quiz to unlock your fear profile.',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                  textAlign: TextAlign.center,
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
                              borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                              border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              badge,
                              style: AppTextStyles.labelSmall.copyWith(color: badgeColor),
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
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(belief, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
          const SizedBox(width: AppSpacing.xs),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close_rounded, size: 14, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
