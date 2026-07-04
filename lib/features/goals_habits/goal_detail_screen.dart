import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/app_strings.dart';
import '../../core/services/confetti_gate.dart';
import '../../core/utils/app_date_utils.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
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

  Future<void> _saveMilestoneAsGoal(
    int idx,
    Map<String, dynamic> milestone,
    Goal goal,
  ) async {
    final title = milestone['title'] as String? ?? '';
    if (title.isEmpty) return;

    final targetWeeks = (milestone['targetWeeks'] as num?)?.toInt() ?? 4;

    final newGoal = Goal(
      id: const Uuid().v4(),
      title: title,
      description: milestone['description'] as String? ?? '',
      category: goal.category,
      goalType: kGoalTypeShortTerm,
      targetDate: DateTime.now().add(Duration(days: targetWeeks * 7)),
      parentGoalId: goal.id,
      createdAt: DateTime.now(),
    );

    try {
      await ref.read(goalsProvider.notifier).addGoal(newGoal);
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

  Future<void> _generateBreakdown(Goal goal) async {
    setState(() => _isGeneratingBreakdown = true);
    try {
      final profile = ref.read(currentUserProfileProvider).valueOrNull;
      if (profile == null) return;

      final breakdown = await ref
          .read(claudeServiceProvider)
          .generateGoalBreakdown(goal, profile);
      if (!mounted) return;
      setState(() => _breakdown = breakdown);
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

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(AppStrings.goalDetailTitle, style: AppTextStyles.headlineMedium),
        actions: goal == null
            ? null
            : [
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
                      if (goal.actionSteps.isNotEmpty) ...[
                        Text(AppStrings.goalDetailActionSteps,
                            style: AppTextStyles.labelLarge),
                        const SizedBox(height: AppSpacing.sm),
                        ...goal.actionSteps.map(
                          (step) => GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => ref
                                .read(goalsProvider.notifier)
                                .toggleActionStep(goal.id, step.id),
                            child: Padding(
                              padding:
                                  const EdgeInsets.only(bottom: AppSpacing.sm),
                              child: Row(
                                children: [
                                  AnimatedSwitcher(
                                    duration:
                                        const Duration(milliseconds: 200),
                                    child: Icon(
                                      step.isCompleted
                                          ? Icons.check_circle_rounded
                                          : Icons.circle_outlined,
                                      key: ValueKey(step.isCompleted),
                                      color: step.isCompleted
                                          ? AppColors.primary
                                          : AppColors.textMuted,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: Text(
                                      step.description,
                                      style:
                                          AppTextStyles.bodyMedium.copyWith(
                                        decoration: step.isCompleted
                                            ? TextDecoration.lineThrough
                                            : null,
                                        color: step.isCompleted
                                            ? AppColors.textMuted
                                            : AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                      AppSecondaryButton(
                        label: AppStrings.breakdownWithAI,
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
                                            : () => _saveMilestoneAsGoal(
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

class _GoalHeader extends StatelessWidget {
  final Goal goal;

  const _GoalHeader({required this.goal});

  Color get _color {
    return switch (goal.category) {
      'career' => AppColors.categoryCareer,
      'health' => AppColors.categoryHealth,
      'relationships' => AppColors.categoryRelationships,
      'finances' => AppColors.categoryFinances,
      _ => AppColors.categoryPersonalGrowth,
    };
  }

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
        _ProgressSlider(goal: goal, color: _color),
      ],
    );
  }
}

/// Draggable progress control. Updates optimistically on release rather than on
/// every drag tick to avoid spamming Firestore.
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
