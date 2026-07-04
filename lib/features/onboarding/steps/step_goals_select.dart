import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/goal_meta.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/hoverable.dart';
import '../../../models/goal.dart';
import 'goals_shared.dart';

/// Onboarding goals — step 1 of 2: pick what you want.
///
/// Template cards toggle selection in place; **Continue** commits selections
/// (no separate "Add" button). Custom goals are added via the inline form and
/// join the committed list immediately.
class StepGoalsSelect extends StatefulWidget {
  final List<Goal> initial;
  final void Function(List<Goal> goals) onNext;
  final VoidCallback onBack;

  const StepGoalsSelect({
    super.key,
    required this.initial,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<StepGoalsSelect> createState() => _StepGoalsSelectState();
}

class _StepGoalsSelectState extends State<StepGoalsSelect> {
  /// Goals already committed (from restore, custom adds, or prior Continue).
  late List<Goal> _committedGoals;

  /// Template ids toggled on the grid but not yet committed until Continue.
  final Set<String> _selectedTemplateIds = {};

  bool _showCustomForm = false;

  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _customCategory = 'personal_growth';
  String _customGoalType = kGoalTypeLongTerm;
  DateTime _customTargetDate =
      DateTime.now().add(const Duration(days: 365 * 3));

  @override
  void initState() {
    super.initState();
    _committedGoals = List.from(widget.initial);
    _titleCtrl.addListener(_onTitleChanged);
  }

  @override
  void dispose() {
    _titleCtrl.removeListener(_onTitleChanged);
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _onTitleChanged() => setState(() {});

  bool _isTemplateCommitted(GoalTemplate t) =>
      _committedGoals.any((g) => g.title == t.title);

  /// Custom goals are any committed goal whose title is not a template.
  List<Goal> get _customGoals =>
      _committedGoals.where((g) => !isTemplateGoalTitle(g.title)).toList();

  bool get _canContinue =>
      _selectedTemplateIds.isNotEmpty || _committedGoals.isNotEmpty;

  void _toggleTemplate(String id) {
    setState(() {
      if (_selectedTemplateIds.contains(id)) {
        _selectedTemplateIds.remove(id);
      } else {
        _selectedTemplateIds.add(id);
      }
    });
  }

  void _removeCustomGoal(Goal goal) {
    setState(() {
      _committedGoals = _committedGoals.where((g) => g.id != goal.id).toList();
    });
  }

  void _selectCustomTimeframe(String value) {
    setState(() {
      _customGoalType = value;
      final days =
          kGoalTypeOptions.firstWhere((o) => o.value == value).defaultDays;
      _customTargetDate = DateTime.now().add(Duration(days: days));
    });
  }

  void _addCustomGoal() {
    if (_titleCtrl.text.trim().isEmpty) return;
    final goal = Goal(
      id: const Uuid().v4(),
      title: _titleCtrl.text.trim(),
      category: _customCategory,
      goalType: _customGoalType,
      description: _descCtrl.text.trim(),
      targetDate: _customTargetDate,
      createdAt: DateTime.now(),
    );
    setState(() {
      _committedGoals = [..._committedGoals, goal];
      _titleCtrl.clear();
      _descCtrl.clear();
      _customCategory = 'personal_growth';
      _customGoalType = kGoalTypeLongTerm;
      _customTargetDate = DateTime.now().add(const Duration(days: 365 * 3));
      _showCustomForm = false;
    });
  }

  void _continue() {
    if (!_canContinue) return;
    final pending = goalsFromTemplateIds(_selectedTemplateIds);
    // Avoid duplicate titles if user re-selected a template already committed.
    final existingTitles = _committedGoals.map((g) => g.title).toSet();
    final fresh = pending.where((g) => !existingTitles.contains(g.title)).toList();
    widget.onNext([..._committedGoals, ...fresh]);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final scrollBottomPadding =
        bottomInset + AppSpacing.buttonHeight + AppSpacing.lg;

    return Stack(
      fit: StackFit.expand,
      children: [
        SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.screenPaddingH,
            AppSpacing.md,
            AppSpacing.screenPaddingH,
            scrollBottomPadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.onboardingGoalsSelectTitle,
                style: AppTextStyles.headlineMedium,
              ).animate().fadeIn(duration: 400.ms),
              const SizedBox(height: AppSpacing.xs),
              Text(
                AppStrings.onboardingGoalsSelectSubtitle,
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary),
              ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
              const SizedBox(height: AppSpacing.xl),

              if (_customGoals.isNotEmpty) ...[
                Text(
                  AppStrings.onboardingGoalsCustomAdded,
                  style: AppTextStyles.labelSmall
                      .copyWith(color: AppColors.textMuted),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: _customGoals
                      .map(
                        (g) => _CustomGoalChip(
                          label: g.title,
                          onRemove: () => _removeCustomGoal(g),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],

              if (!_showCustomForm)
                _TemplateGrid(
                  selectedTemplateIds: _selectedTemplateIds,
                  isCommitted: _isTemplateCommitted,
                  onToggle: _toggleTemplate,
                  onOpenCustom: () => setState(() => _showCustomForm = true),
                )
              else
                _CustomGoalForm(
                  titleCtrl: _titleCtrl,
                  descCtrl: _descCtrl,
                  category: _customCategory,
                  goalType: _customGoalType,
                  onCategoryChanged: (v) =>
                      setState(() => _customCategory = v),
                  onTimeframeSelected: _selectCustomTimeframe,
                  onCancel: () => setState(() => _showCustomForm = false),
                  onAdd: _addCustomGoal,
                  canAdd: _titleCtrl.text.trim().isNotEmpty,
                ),

              if (!_canContinue) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  AppStrings.onboardingGoalsSelectEmptyHint,
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
        OnboardingGoalsFooter(
          onBack: widget.onBack,
          onContinue: _canContinue ? _continue : null,
        ),
      ],
    );
  }
}

class _TemplateGrid extends StatelessWidget {
  final Set<String> selectedTemplateIds;
  final bool Function(GoalTemplate) isCommitted;
  final void Function(String id) onToggle;
  final VoidCallback onOpenCustom;

  const _TemplateGrid({
    required this.selectedTemplateIds,
    required this.isCommitted,
    required this.onToggle,
    required this.onOpenCustom,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: AppSpacing.sm,
      mainAxisSpacing: AppSpacing.sm,
      childAspectRatio: 1.0,
      children: [
        ...kGoalTemplates.asMap().entries.map((e) {
          final t = e.value;
          final selected = selectedTemplateIds.contains(t.id);
          final committed = isCommitted(t);
          return _TemplateCard(
            template: t,
            index: e.key,
            selected: selected,
            committed: committed,
            onTap: committed ? null : () => onToggle(t.id),
          );
        }),
        _SomethingElseTile(
          index: kGoalTemplates.length,
          onTap: onOpenCustom,
        ),
      ],
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final GoalTemplate template;
  final int index;
  final bool selected;
  final bool committed;
  final VoidCallback? onTap;

  const _TemplateCard({
    required this.template,
    required this.index,
    required this.selected,
    required this.committed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = goalCategoryColor(template.category);
    return Hoverable(
      cursor: committed ? SystemMouseCursors.basic : SystemMouseCursors.click,
      onTap: onTap,
      builder: (context, hovered) => AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: committed
              ? AppColors.surfaceElevated.withValues(alpha: 0.4)
              : selected
                  ? color.withValues(alpha: 0.12)
                  : hovered
                      ? color.withValues(alpha: 0.06)
                      : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(
            color: committed
                ? AppColors.border.withValues(alpha: 0.5)
                : selected
                    ? color.withValues(alpha: 0.7)
                    : hovered
                        ? color.withValues(alpha: 0.5)
                        : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
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
                    color: committed
                        ? AppColors.textMuted.withValues(alpha: 0.12)
                        : color.withValues(alpha: selected ? 0.25 : 0.15),
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  child: Icon(
                    template.icon,
                    size: 26,
                    color: committed
                        ? AppColors.textMuted
                        : selected
                            ? color
                            : color.withValues(alpha: 0.85),
                  ),
                ),
                const Spacer(),
                if (selected)
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 13,
                    ),
                  )
                else if (committed)
                  const Icon(Icons.check_rounded,
                      color: AppColors.textMuted, size: 16)
                else
                  Text(
                    goalHorizonLabel(template.months),
                    style: AppTextStyles.labelSmall
                        .copyWith(color: AppColors.textMuted),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              template.title,
              style: AppTextStyles.labelLarge.copyWith(
                color: committed
                    ? AppColors.textMuted
                    : selected
                        ? color
                        : AppColors.textPrimary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Text(
              template.description,
              style: AppTextStyles.bodySmall.copyWith(
                color: committed
                    ? AppColors.textDisabled
                    : AppColors.textMuted,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    ).animate().fadeIn(
          delay: Duration(milliseconds: index * 40),
          duration: 300.ms,
        );
  }
}

class _SomethingElseTile extends StatelessWidget {
  final int index;
  final VoidCallback onTap;

  const _SomethingElseTile({required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Hoverable(
      onTap: onTap,
      builder: (context, hovered) => AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.fromBorderSide(
            BorderSide(
              color: hovered
                  ? AppColors.textSecondary.withValues(alpha: 0.5)
                  : AppColors.border,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.textMuted.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: const Icon(
                Icons.edit_rounded,
                size: 24,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              AppStrings.onboardingGoalsSomethingElse,
              style: AppTextStyles.labelLarge
                  .copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 3),
            Text(
              AppStrings.onboardingGoalsSomethingElseHint,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMuted,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(
          delay: Duration(milliseconds: index * 40),
          duration: 300.ms,
        );
  }
}

class _CustomGoalChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const _CustomGoalChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary),
          ),
          const SizedBox(width: AppSpacing.xs),
          Hoverable(
            onTap: onRemove,
            builder: (context, _) => const Icon(
              Icons.close_rounded,
              size: 14,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomGoalForm extends StatelessWidget {
  final TextEditingController titleCtrl;
  final TextEditingController descCtrl;
  final String category;
  final String goalType;
  final void Function(String) onCategoryChanged;
  final void Function(String) onTimeframeSelected;
  final VoidCallback onCancel;
  final VoidCallback onAdd;
  final bool canAdd;

  const _CustomGoalForm({
    required this.titleCtrl,
    required this.descCtrl,
    required this.category,
    required this.goalType,
    required this.onCategoryChanged,
    required this.onTimeframeSelected,
    required this.onCancel,
    required this.onAdd,
    required this.canAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(AppStrings.onboardingGoalsCustomTitle,
            style: AppTextStyles.headlineSmall),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: titleCtrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          style: AppTextStyles.bodyLarge,
          cursorColor: AppColors.primary,
          decoration: InputDecoration(
            hintText: AppStrings.onboardingGoalsCustomTitleHint,
            hintStyle:
                AppTextStyles.bodyLarge.copyWith(color: AppColors.textMuted),
            filled: true,
            fillColor: AppColors.surfaceElevated,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              borderSide: const BorderSide(color: AppColors.border),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        DropdownButtonFormField<String>(
          initialValue: category,
          decoration: InputDecoration(
            labelText: AppStrings.onboardingGoalsCategoryLabel,
            filled: true,
            fillColor: AppColors.surfaceElevated,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              borderSide: const BorderSide(color: AppColors.border),
            ),
          ),
          items: kGoalCategories
              .map(
                (c) => DropdownMenuItem(
                  value: c,
                  child: Text(goalCategoryLabel(c)),
                ),
              )
              .toList(),
          onChanged: (v) {
            if (v != null) onCategoryChanged(v);
          },
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: descCtrl,
          style: AppTextStyles.bodyLarge,
          cursorColor: AppColors.primary,
          maxLines: 2,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: AppStrings.goalWhyMattersHint,
            hintStyle:
                AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
            filled: true,
            fillColor: AppColors.surfaceElevated,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              borderSide: const BorderSide(color: AppColors.border),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(AppStrings.goalTimeframe, style: AppTextStyles.labelMedium),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: kGoalTypeOptions.map((opt) {
            final selected = opt.value == goalType;
            return GestureDetector(
              onTap: () => onTimeframeSelected(opt.value),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primaryContainer
                      : AppColors.surfaceElevated,
                  border: Border.all(
                    color: selected ? AppColors.primary : AppColors.border,
                  ),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                ),
                child: Text(
                  '${opt.label} · ${opt.subtitle}',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: selected
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            AppSecondaryButton(label: 'Cancel', width: 100, onPressed: onCancel),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: AppPrimaryButton(
                label: AppStrings.onboardingGoalsAddCustom,
                onPressed: canAdd ? onAdd : null,
                icon: Icons.add_rounded,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
