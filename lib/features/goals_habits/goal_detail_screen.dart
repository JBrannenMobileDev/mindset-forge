import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/goal_templates.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/app_strings.dart';
import '../../core/services/confetti_gate.dart';
import '../../core/utils/app_date_utils.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_text_field.dart';
import '../../models/action_step.dart';
import '../../models/goal.dart';
import '../../providers/goals_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/claude_provider.dart';
import 'goal_form_modal.dart';

class GoalDetailScreen extends ConsumerStatefulWidget {
  final String goalId;

  const GoalDetailScreen({super.key, required this.goalId});

  @override
  ConsumerState<GoalDetailScreen> createState() => _GoalDetailScreenState();
}

class _GoalDetailScreenState extends ConsumerState<GoalDetailScreen> {
  late final ConfettiController _confettiCtrl;
  bool _isGeneratingBreakdown = false;
  List<Map<String, dynamic>> _breakdown = [];
  final Set<int> _savedMilestones = {};

  @override
  void initState() {
    super.initState();
    _confettiCtrl = ConfettiController(duration: const Duration(seconds: 3));
  }

  @override
  void dispose() {
    _confettiCtrl.dispose();
    super.dispose();
  }

  Future<void> _completeGoal() async {
    await ref.read(goalsProvider.notifier).completeGoal(widget.goalId);
    ConfettiGate.play(_confettiCtrl, const Duration(seconds: 3));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.goalCompletedToast)),
      );
    }
  }

  /// True when the goal already has a milestone whose label matches [title],
  /// so re-adding an AI suggestion never silently duplicates a step.
  bool _milestoneExists(Goal goal, String title) {
    final t = title.trim().toLowerCase();
    return goal.actionSteps.any((s) => s.label.trim().toLowerCase() == t);
  }

  Future<void> _addMilestoneFromBreakdown(
    int idx,
    Map<String, dynamic> milestone,
    Goal goal,
  ) async {
    final title = (milestone['title'] as String? ?? '').trim();
    if (title.isEmpty) return;

    final targetWeeks = (milestone['targetWeeks'] as num?)?.toInt();
    final step = ActionStep(
      id: const Uuid().v4(),
      title: title,
      description: milestone['description'] as String? ?? '',
      whyImportant: milestone['whyImportant'] as String? ?? '',
      targetDate: targetWeeks != null
          ? DateTime.now().add(Duration(days: targetWeeks * 7))
          : null,
    );

    try {
      await ref.read(goalsProvider.notifier).addStep(goal.id, step);
      if (mounted) {
        setState(() => _savedMilestones.add(idx));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.goalMilestoneSavedToast)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.errorGeneric)),
        );
      }
    }
  }

  Future<void> _addManualMilestone(Goal goal) async {
    final title = await showDialog<String>(
      context: context,
      builder: (_) => const _AddMilestoneDialog(),
    );
    if (title == null || title.trim().isEmpty) return;
    try {
      await ref.read(goalsProvider.notifier).addStep(
            goal.id,
            ActionStep(id: const Uuid().v4(), title: title.trim()),
          );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.errorGeneric)),
        );
      }
    }
  }

  Future<void> _generateBreakdown(Goal goal) async {
    setState(() => _isGeneratingBreakdown = true);
    try {
      final profile = ref.read(currentUserProfileProvider).valueOrNull;
      if (profile == null) return;

      final breakdown = await ref
          .read(claudeServiceProvider)
          .generateGoalBreakdown(goal, profile);
      if (!mounted) return;
      // Pre-mark any suggestion that's already in the checklist so it can't be
      // added twice.
      final preSaved = <int>{};
      for (var i = 0; i < breakdown.length; i++) {
        final title = breakdown[i]['title'] as String? ?? '';
        if (_milestoneExists(goal, title)) preSaved.add(i);
      }
      setState(() {
        _breakdown = breakdown;
        _savedMilestones
          ..clear()
          ..addAll(preSaved);
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.errorAI)),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingBreakdown = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final goals = ref.watch(goalsProvider);
    final matches = goals.where((g) => g.id == widget.goalId);
    final goal = matches.isEmpty ? null : matches.first;
    final primaryGoalId =
        ref.watch(currentUserProfileProvider).valueOrNull?.primaryGoalId ?? '';
    final isNorthStar = goal != null && goal.id == primaryGoalId;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        title:
            Text(AppStrings.goalDetailTitle, style: AppTextStyles.headlineMedium),
        actions: goal == null
            ? null
            : [
                if (goal.status == 'active')
                  IconButton(
                    tooltip: AppStrings.goalSetAsNorthStar,
                    icon: Icon(
                      isNorthStar
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: isNorthStar
                          ? AppColors.primary
                          : AppColors.textMuted,
                    ),
                    onPressed: isNorthStar
                        ? null
                        : () async {
                            await ref
                                .read(goalsProvider.notifier)
                                .setPrimaryGoal(goal.id);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text(AppStrings.goalNorthStarSetToast)),
                              );
                            }
                          },
                  ),
                IconButton(
                  icon: const Icon(Icons.edit_rounded),
                  onPressed: () =>
                      GoalFormModal.show(context, ref, existing: goal),
                ),
              ],
      ),
      body: goal == null
          ? Center(
              child: Text(
                AppStrings.goalNotFound,
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary),
              ),
            )
          : Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.screenPaddingH),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _GoalHeader(goal: goal),
                      const SizedBox(height: AppSpacing.xl),
                      if (goal.description.isNotEmpty) ...[
                        Text(AppStrings.goalDetailDescription,
                            style: AppTextStyles.labelLarge),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          goal.description,
                          style: AppTextStyles.bodyMedium
                              .copyWith(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                      if (goal.identityBecomes.isNotEmpty) ...[
                        Text(AppStrings.goalDetailIdentity,
                            style: AppTextStyles.labelLarge),
                        const SizedBox(height: AppSpacing.sm),
                        AppCard(
                          backgroundColor: AppColors.primaryContainer,
                          borderColor:
                              AppColors.primary.withValues(alpha: 0.3),
                          child: Row(
                            children: [
                              const Icon(Icons.person_rounded,
                                  color: AppColors.primary, size: 20),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  goal.identityBecomes,
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: AppColors.primary,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],

                      // Milestone checklist — the honest progress driver.
                      Row(
                        children: [
                          Text(AppStrings.goalDetailActionSteps,
                              style: AppTextStyles.labelLarge),
                          const Spacer(),
                          if (goal.status == 'active')
                            AppTextButton(
                              label: AppStrings.goalAddMilestone,
                              onPressed: () => _addManualMilestone(goal),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      ...goal.actionSteps.map(
                        (step) => _MilestoneTile(
                          step: step,
                          onToggle: () => ref
                              .read(goalsProvider.notifier)
                              .toggleActionStep(goal.id, step.id),
                          onRemove: goal.status == 'active'
                              ? () => ref
                                  .read(goalsProvider.notifier)
                                  .removeStep(goal.id, step.id)
                              : null,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      AppSecondaryButton(
                        label: goal.hasSteps
                            ? AppStrings.goalRegenerateBreakdown
                            : AppStrings.breakdownWithAI,
                        isLoading: _isGeneratingBreakdown,
                        onPressed: () => _generateBreakdown(goal),
                        icon: Icons.auto_awesome_rounded,
                      ),
                      if (_breakdown.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.lg),
                        Text(AppStrings.goalDetailBreakdown,
                            style: AppTextStyles.labelLarge),
                        const SizedBox(height: AppSpacing.sm),
                        ..._breakdown.asMap().entries.map(
                          (e) {
                            final isSaved = _savedMilestones.contains(e.key);
                            return Padding(
                              padding:
                                  const EdgeInsets.only(bottom: AppSpacing.sm),
                              child: AppCard(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: isSaved
                                                ? AppColors.primaryContainer
                                                : AppColors.surfaceHighest,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Center(
                                            child: isSaved
                                                ? const Icon(
                                                    Icons.check_rounded,
                                                    size: 16,
                                                    color: AppColors.primary)
                                                : Text(
                                                    '${e.key + 1}',
                                                    style: AppTextStyles
                                                        .labelLarge
                                                        .copyWith(
                                                            color: AppColors
                                                                .primary),
                                                  ),
                                          ),
                                        ),
                                        const SizedBox(width: AppSpacing.md),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                e.value['title'] as String? ??
                                                    '',
                                                style:
                                                    AppTextStyles.labelLarge,
                                              ),
                                              if ((e.value['description']
                                                          as String?)
                                                      ?.isNotEmpty ==
                                                  true)
                                                Text(
                                                  e.value['description']
                                                      as String,
                                                  style: AppTextStyles
                                                      .bodySmall
                                                      .copyWith(
                                                          color: AppColors
                                                              .textSecondary),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: AppSpacing.sm),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: AppTextButton(
                                        label: isSaved
                                            ? AppStrings.goalMilestoneAdded
                                            : AppStrings.goalAddAsSubGoal,
                                        color: isSaved
                                            ? AppColors.textMuted
                                            : AppColors.primary,
                                        onPressed: isSaved
                                            ? null
                                            : () => _addMilestoneFromBreakdown(
                                                e.key, e.value, goal),
                                      ),
                                    ),
                                  ],
                                ),
                              ).animate().fadeIn(
                                  delay: Duration(milliseconds: e.key * 80)),
                            );
                          },
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xl),
                      if (goal.status == 'active')
                        AppPrimaryButton(
                          label: AppStrings.goalMarkComplete,
                          onPressed: _completeGoal,
                          icon: Icons.check_circle_rounded,
                        ),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
                Align(
                  alignment: Alignment.topCenter,
                  child: ConfettiWidget(
                    confettiController: _confettiCtrl,
                    blastDirectionality: BlastDirectionality.explosive,
                    colors: const [
                      AppColors.primary,
                      AppColors.secondary,
                      AppColors.warning
                    ],
                    numberOfParticles: 30,
                  ),
                ),
              ],
            ),
    );
  }
}

/// A single milestone row: tap the circle/label to toggle completion; optional
/// trailing delete for active goals.
class _MilestoneTile extends StatelessWidget {
  final ActionStep step;
  final VoidCallback onToggle;
  final VoidCallback? onRemove;

  const _MilestoneTile({
    required this.step,
    required this.onToggle,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onToggle,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                step.isCompleted
                    ? Icons.check_circle_rounded
                    : Icons.circle_outlined,
                key: ValueKey(step.isCompleted),
                color:
                    step.isCompleted ? AppColors.primary : AppColors.textMuted,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onToggle,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.label,
                    style: AppTextStyles.bodyMedium.copyWith(
                      decoration: step.isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                      color: step.isCompleted
                          ? AppColors.textMuted
                          : AppColors.textPrimary,
                    ),
                  ),
                  if (step.description.isNotEmpty && !step.isCompleted)
                    Text(
                      step.description,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textSecondary),
                    ),
                ],
              ),
            ),
          ),
          if (onRemove != null)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onRemove,
              child: const Padding(
                padding: EdgeInsets.only(left: AppSpacing.sm),
                child: Icon(Icons.close_rounded,
                    size: 16, color: AppColors.textMuted),
              ),
            ),
        ],
      ),
    );
  }
}

class _AddMilestoneDialog extends StatefulWidget {
  const _AddMilestoneDialog();

  @override
  State<_AddMilestoneDialog> createState() => _AddMilestoneDialogState();
}

class _AddMilestoneDialogState extends State<_AddMilestoneDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() => Navigator.pop(context, _ctrl.text.trim());

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppStrings.goalMilestoneDialogTitle,
                style: AppTextStyles.headlineSmall),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _ctrl,
              hint: AppStrings.goalAddMilestoneHint,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppPrimaryButton(
              label: AppStrings.add,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalHeader extends StatelessWidget {
  final Goal goal;

  const _GoalHeader({required this.goal});

  Color get _color => goalCategoryColor(goal.category);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          goal.category.replaceAll('_', ' ').toUpperCase(),
          style: AppTextStyles.overline.copyWith(color: _color),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(goal.title, style: AppTextStyles.headlineLarge),
        const SizedBox(height: AppSpacing.md),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '${AppStrings.goalTargetPrefix} ${AppDateUtils.formatDate(goal.targetDate)}',
            style: AppTextStyles.labelSmall,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        // Milestone-backed goals show honest derived progress; step-less goals
        // keep the manual slider as the only sensible input.
        if (goal.hasSteps)
          _DerivedProgress(goal: goal, color: _color)
        else
          _ProgressSlider(goal: goal, color: _color),
      ],
    );
  }
}

/// Read-only progress for goals whose progress comes from the milestone
/// checklist. Shows the percentage and an "X of Y milestones" caption.
class _DerivedProgress extends StatelessWidget {
  final Goal goal;
  final Color color;

  const _DerivedProgress({required this.goal, required this.color});

  @override
  Widget build(BuildContext context) {
    final pct = goal.derivedProgress;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '${pct.toStringAsFixed(0)}%',
              style: AppTextStyles.headlineSmall.copyWith(color: color),
            ),
            const Spacer(),
            Text(
              AppStrings.goalMilestoneProgress(
                  goal.completedStepCount, goal.actionSteps.length),
              style: AppTextStyles.labelSmall,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct / 100,
            backgroundColor: AppColors.border,
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}

/// Draggable progress control for step-less goals. Updates optimistically on
/// release rather than on every drag tick to avoid spamming Firestore.
class _ProgressSlider extends ConsumerStatefulWidget {
  final Goal goal;
  final Color color;

  const _ProgressSlider({required this.goal, required this.color});

  @override
  ConsumerState<_ProgressSlider> createState() => _ProgressSliderState();
}

class _ProgressSliderState extends ConsumerState<_ProgressSlider> {
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final current =
        (_dragValue ?? widget.goal.progressPercent).clamp(0.0, 100.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '${current.toStringAsFixed(0)}%',
              style: AppTextStyles.headlineSmall.copyWith(color: widget.color),
            ),
            const Spacer(),
            Text(AppStrings.goalProgressDrag, style: AppTextStyles.labelSmall),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 8,
            activeTrackColor: widget.color,
            inactiveTrackColor: AppColors.border,
            thumbColor: widget.color,
            overlayColor: widget.color.withValues(alpha: 0.15),
            trackShape: const RoundedRectSliderTrackShape(),
          ),
          child: Slider(
            value: current.toDouble(),
            min: 0,
            max: 100,
            divisions: 20,
            label: '${current.toStringAsFixed(0)}%',
            onChanged: (v) => setState(() => _dragValue = v),
            onChangeEnd: (v) {
              ref.read(goalsProvider.notifier).setProgress(widget.goal.id, v);
              setState(() => _dragValue = null);
            },
          ),
        ),
      ],
    );
  }
}
