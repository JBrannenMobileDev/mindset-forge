import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/app_strings.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../models/goal.dart';
import '../../providers/goals_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/claude_provider.dart';
import 'goal_form_modal.dart';

class GoalDetailScreen extends ConsumerStatefulWidget {
  final Goal goal;

  const GoalDetailScreen({super.key, required this.goal});

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
    await ref.read(goalsProvider.notifier).completeGoal(widget.goal.id);
    _confettiCtrl.play();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Goal completed! You\'re unstoppable.')),
      );
    }
  }

  Future<void> _saveMilestoneAsGoal(int idx, Map<String, dynamic> milestone) async {
    final title = milestone['title'] as String? ?? '';
    if (title.isEmpty) return;

    final newGoal = Goal(
      id: const Uuid().v4(),
      title: title,
      description: milestone['description'] as String? ?? '',
      category: widget.goal.category,
      targetDate: DateTime.now().add(const Duration(days: 30)),
      parentGoalId: widget.goal.id,
      createdAt: DateTime.now(),
    );

    try {
      await ref.read(goalsProvider.notifier).addGoal(newGoal);
      if (mounted) {
        setState(() => _savedMilestones.add(idx));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Milestone saved as a sub-goal!')),
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

  Future<void> _generateBreakdown() async {
    setState(() => _isGeneratingBreakdown = true);
    try {
      final profile = ref.read(currentUserProfileProvider).valueOrNull;
      if (profile == null) return;

      final breakdown = await ref
          .read(claudeServiceProvider)
          .generateGoalBreakdown(widget.goal.title, profile);
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
    final goal = goals.firstWhere(
      (g) => g.id == widget.goal.id,
      orElse: () => widget.goal,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                backgroundColor: AppColors.background,
                pinned: true,
                expandedHeight: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.edit_rounded),
                    onPressed: () => GoalFormModal.show(context, ref, existing: goal),
                  ),
                ],
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.screenPaddingH),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _GoalHeader(goal: goal),
                      const SizedBox(height: AppSpacing.xl),
                      if (goal.description.isNotEmpty) ...[
                        Text('Description', style: AppTextStyles.labelLarge),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          goal.description,
                          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                      if (goal.identityBecomes.isNotEmpty) ...[
                        Text('Identity', style: AppTextStyles.labelLarge),
                        const SizedBox(height: AppSpacing.sm),
                        AppCard(
                          backgroundColor: AppColors.primaryContainer,
                          borderColor: AppColors.primary.withValues(alpha: 0.3),
                          child: Row(
                            children: [
                              const Icon(Icons.person_rounded, color: AppColors.primary, size: 20),
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
                        Text('Action Steps', style: AppTextStyles.labelLarge),
                        const SizedBox(height: AppSpacing.sm),
                        ...goal.actionSteps.map((step) => Padding(
                              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                              child: Row(
                                children: [
                                  Icon(
                                    step.isCompleted
                                        ? Icons.check_circle_rounded
                                        : Icons.circle_outlined,
                                    color: step.isCompleted
                                        ? AppColors.primary
                                        : AppColors.textMuted,
                                    size: 20,
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: Text(
                                      step.description,
                                      style: AppTextStyles.bodyMedium.copyWith(
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
                            )),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                      AppSecondaryButton(
                        label: AppStrings.breakdownWithAI,
                        isLoading: _isGeneratingBreakdown,
                        onPressed: _generateBreakdown,
                        icon: Icons.auto_awesome_rounded,
                      ),
                      if (_breakdown.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.lg),
                        Text('Breakdown', style: AppTextStyles.labelLarge),
                        const SizedBox(height: AppSpacing.sm),
                        ..._breakdown.asMap().entries.map(
                          (e) {
                            final isSaved = _savedMilestones.contains(e.key);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                              child: AppCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
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
                                                ? const Icon(Icons.check_rounded,
                                                    size: 16,
                                                    color: AppColors.primary)
                                                : Text(
                                                    '${e.key + 1}',
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
                                              Text(
                                                e.value['title'] as String? ?? '',
                                                style: AppTextStyles.labelLarge,
                                              ),
                                              if ((e.value['description'] as String?)
                                                      ?.isNotEmpty ==
                                                  true)
                                                Text(
                                                  e.value['description'] as String,
                                                  style: AppTextStyles.bodySmall
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
                                      child: TextButton.icon(
                                        onPressed: isSaved
                                            ? null
                                            : () => _saveMilestoneAsGoal(
                                                e.key, e.value),
                                        icon: Icon(
                                          isSaved
                                              ? Icons.check_rounded
                                              : Icons.add_rounded,
                                          size: 14,
                                          color: isSaved
                                              ? AppColors.textMuted
                                              : AppColors.primary,
                                        ),
                                        label: Text(
                                          isSaved ? 'Added' : 'Add as Sub-Goal',
                                          style: AppTextStyles.labelSmall
                                              .copyWith(
                                                  color: isSaved
                                                      ? AppColors.textMuted
                                                      : AppColors.primary),
                                        ),
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: AppSpacing.sm,
                                              vertical: 2),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ).animate().fadeIn(
                                  delay: Duration(
                                      milliseconds: e.key * 80)),
                            );
                          },
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xl),
                      if (goal.status == 'active')
                        AppPrimaryButton(
                          label: 'Mark as Complete',
                          onPressed: _completeGoal,
                          icon: Icons.check_circle_rounded,
                        ),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiCtrl,
              blastDirectionality: BlastDirectionality.explosive,
              colors: [AppColors.primary, AppColors.secondary, AppColors.warning],
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
        Row(
          children: [
            Text(
              '${goal.progressPercent.toStringAsFixed(0)}%',
              style: AppTextStyles.headlineSmall.copyWith(color: _color),
            ),
            const Spacer(),
            Text(
              'Target: ${goal.targetDate.month}/${goal.targetDate.day}/${goal.targetDate.year}',
              style: AppTextStyles.labelSmall,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: goal.progressPercent / 100,
            backgroundColor: AppColors.border,
            valueColor: AlwaysStoppedAnimation(_color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}
