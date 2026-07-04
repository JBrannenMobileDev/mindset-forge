import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../models/action_step.dart';
import '../../models/affirmation.dart';
import '../../models/goal.dart';
import '../../models/habit.dart';
import '../../providers/affirmations_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/claude_provider.dart';
import '../../providers/goals_provider.dart';
import '../../providers/habits_provider.dart';
import 'widgets/sheet_handle.dart';

/// Post-creation "build your plan" sheet. Auto-generates milestone sub-goals for
/// a newly created long-horizon goal and offers one-tap wiring to a supporting
/// habit and affirmation. Visualization is intentionally NOT offered here — it
/// lives exclusively in the Future Self Practice.
class GoalSetupSheet {
  static Future<void> show(BuildContext context, WidgetRef ref, Goal goal) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
      ),
      builder: (_) => ProviderScope(
        parent: ProviderScope.containerOf(context),
        child: _GoalSetupSheet(goal: goal),
      ),
    );
  }
}

class _GoalSetupSheet extends ConsumerStatefulWidget {
  final Goal goal;

  const _GoalSetupSheet({required this.goal});

  @override
  ConsumerState<_GoalSetupSheet> createState() => _GoalSetupSheetState();
}

class _GoalSetupSheetState extends ConsumerState<_GoalSetupSheet> {
  bool _loadingMilestones = true;
  List<Map<String, dynamic>> _milestones = [];
  final Set<int> _savedMilestones = {};

  bool _loadingHabit = false;
  Map<String, String>? _habit;
  bool _habitAdded = false;

  bool _loadingAffirmation = false;
  String? _affirmation;
  bool _affirmationAdded = false;

  @override
  void initState() {
    super.initState();
    _loadMilestones();
  }

  Future<void> _loadMilestones() async {
    final profile = ref.read(currentUserProfileProvider).valueOrNull;
    if (profile == null) {
      if (mounted) setState(() => _loadingMilestones = false);
      return;
    }
    final milestones = await ref
        .read(claudeServiceProvider)
        .generateGoalBreakdown(widget.goal, profile);
    if (!mounted) return;
    setState(() {
      _milestones = milestones;
      _loadingMilestones = false;
    });
  }

  Future<void> _addMilestone(int idx, Map<String, dynamic> milestone) async {
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
      await ref.read(goalsProvider.notifier).addStep(widget.goal.id, step);
      if (mounted) setState(() => _savedMilestones.add(idx));
    } catch (_) {
      _showError();
    }
  }

  Future<void> _suggestHabit() async {
    final profile = ref.read(currentUserProfileProvider).valueOrNull;
    if (profile == null) return;
    setState(() => _loadingHabit = true);
    final habit = await ref
        .read(claudeServiceProvider)
        .generateHabitForGoal(widget.goal, profile);
    if (!mounted) return;
    setState(() {
      _habit = habit.isEmpty || (habit['name'] ?? '').isEmpty ? null : habit;
      _loadingHabit = false;
    });
    if (_habit == null) _showError();
  }

  Future<void> _addHabit() async {
    final habit = _habit;
    if (habit == null) return;
    final newHabit = Habit(
      id: const Uuid().v4(),
      name: habit['name'] ?? '',
      trigger: habit['trigger'] ?? '',
      identityReinforces: habit['identityReinforces'] ?? '',
      createdAt: DateTime.now(),
    );
    try {
      await ref.read(habitsProvider.notifier).addHabit(newHabit);
      if (mounted) {
        setState(() => _habitAdded = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.goalHabitAddedToast)),
        );
      }
    } catch (_) {
      _showError();
    }
  }

  Future<void> _suggestAffirmation() async {
    final profile = ref.read(currentUserProfileProvider).valueOrNull;
    if (profile == null) return;
    setState(() => _loadingAffirmation = true);
    final text = await ref
        .read(claudeServiceProvider)
        .generateAffirmationForGoal(widget.goal, profile);
    if (!mounted) return;
    setState(() {
      _affirmation = text.isEmpty ? null : text;
      _loadingAffirmation = false;
    });
    if (_affirmation == null) _showError();
  }

  Future<void> _addAffirmation() async {
    final text = _affirmation;
    if (text == null) return;
    final affirmation = Affirmation(
      id: const Uuid().v4(),
      text: text,
      source: 'ai',
      category: widget.goal.category,
      createdAt: DateTime.now(),
    );
    try {
      await ref.read(affirmationsProvider.notifier).addAffirmation(affirmation);
      if (mounted) {
        setState(() => _affirmationAdded = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.goalAffirmationAddedToast)),
        );
      }
    } catch (_) {
      _showError();
    }
  }

  void _showError() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(AppStrings.errorAI)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.9;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.sm,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SheetHandle(),
            const SizedBox(height: AppSpacing.md),
            Text(AppStrings.goalSetupTitle, style: AppTextStyles.headlineMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              AppStrings.goalSetupSubtitle,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
            _MilestonesSection(
              loading: _loadingMilestones,
              milestones: _milestones,
              savedMilestones: _savedMilestones,
              onAdd: _addMilestone,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(AppStrings.goalSetupReinforce, style: AppTextStyles.labelLarge),
            const SizedBox(height: AppSpacing.sm),
            _HabitCard(
              loading: _loadingHabit,
              habit: _habit,
              added: _habitAdded,
              onSuggest: _suggestHabit,
              onAdd: _addHabit,
            ),
            const SizedBox(height: AppSpacing.sm),
            _AffirmationCard(
              loading: _loadingAffirmation,
              affirmation: _affirmation,
              added: _affirmationAdded,
              onSuggest: _suggestAffirmation,
              onAdd: _addAffirmation,
            ),
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.secondaryContainer,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Row(
                children: [
                  const Icon(Icons.visibility_rounded,
                      color: AppColors.secondary, size: 18),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      AppStrings.goalSetupFutureSelfNote,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.secondary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppPrimaryButton(
              label: AppStrings.goalSetupDone,
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}

class _MilestonesSection extends StatelessWidget {
  final bool loading;
  final List<Map<String, dynamic>> milestones;
  final Set<int> savedMilestones;
  final void Function(int, Map<String, dynamic>) onAdd;

  const _MilestonesSection({
    required this.loading,
    required this.milestones,
    required this.savedMilestones,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppColors.primary),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            AppStrings.goalSetupMilestonesLoading,
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondary),
          ),
        ],
      );
    }

    if (milestones.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(AppStrings.goalSetupMilestones, style: AppTextStyles.labelLarge),
        const SizedBox(height: AppSpacing.sm),
        ...milestones.asMap().entries.map((e) {
          final isSaved = savedMilestones.contains(e.key);
          final why = e.value['whyImportant'] as String? ?? '';
          final desc = e.value['description'] as String? ?? '';
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
                                  size: 16, color: AppColors.primary)
                              : Text('${e.key + 1}',
                                  style: AppTextStyles.labelLarge
                                      .copyWith(color: AppColors.primary)),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(e.value['title'] as String? ?? '',
                                style: AppTextStyles.labelLarge),
                            if (desc.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(desc,
                                    style: AppTextStyles.bodySmall.copyWith(
                                        color: AppColors.textSecondary)),
                              ),
                            if (why.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text('- $why',
                                    style: AppTextStyles.bodySmall.copyWith(
                                        color: AppColors.textMuted,
                                        fontStyle: FontStyle.italic)),
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
                          : AppStrings.goalSetupAddMilestone,
                      color: isSaved ? AppColors.textMuted : AppColors.primary,
                      onPressed: isSaved ? null : () => onAdd(e.key, e.value),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: Duration(milliseconds: e.key * 80)),
          );
        }),
      ],
    );
  }
}

class _HabitCard extends StatelessWidget {
  final bool loading;
  final Map<String, String>? habit;
  final bool added;
  final VoidCallback onSuggest;
  final VoidCallback onAdd;

  const _HabitCard({
    required this.loading,
    required this.habit,
    required this.added,
    required this.onSuggest,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    if (habit == null) {
      return AppSecondaryButton(
        label: AppStrings.goalSetupSuggestHabit,
        icon: Icons.repeat_rounded,
        isLoading: loading,
        onPressed: onSuggest,
      );
    }
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: const Icon(Icons.repeat_rounded,
                    size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(habit?['name'] ?? '', style: AppTextStyles.labelLarge),
                    if ((habit?['trigger'] ?? '').isNotEmpty)
                      Text(habit?['trigger'] ?? '',
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerRight,
            child: AppTextButton(
              label: added
                  ? AppStrings.goalSetupHabitAdded
                  : AppStrings.goalSetupAddHabit,
              color: added ? AppColors.textMuted : AppColors.primary,
              onPressed: added ? null : onAdd,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

class _AffirmationCard extends StatelessWidget {
  final bool loading;
  final String? affirmation;
  final bool added;
  final VoidCallback onSuggest;
  final VoidCallback onAdd;

  const _AffirmationCard({
    required this.loading,
    required this.affirmation,
    required this.added,
    required this.onSuggest,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    if (affirmation == null) {
      return AppSecondaryButton(
        label: AppStrings.goalSetupSuggestAffirmation,
        icon: Icons.auto_awesome_rounded,
        isLoading: loading,
        onPressed: onSuggest,
      );
    }
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.format_quote_rounded,
                  size: 20, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  affirmation ?? '',
                  style: AppTextStyles.bodyMedium
                      .copyWith(fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerRight,
            child: AppTextButton(
              label: added
                  ? AppStrings.goalSetupAffirmationAdded
                  : AppStrings.goalSetupAddAffirmation,
              color: added ? AppColors.textMuted : AppColors.primary,
              onPressed: added ? null : onAdd,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}
