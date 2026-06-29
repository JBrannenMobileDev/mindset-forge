import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/goal_meta.dart';
import '../../../core/utils/app_date_utils.dart';
import '../../../core/widgets/app_button.dart';
import '../../../models/goal.dart';

Color _categoryColor(String category) =>
    const <String, Color>{
      'career': AppColors.categoryCareer,
      'health': AppColors.categoryHealth,
      'relationships': AppColors.categoryRelationships,
      'finances': AppColors.categoryFinances,
      'personal_growth': AppColors.categoryPersonalGrowth,
    }[category] ??
    AppColors.primary;

class StepGoals extends StatefulWidget {
  final List<Goal> initial;
  final void Function(List<Goal>) onNext;
  final VoidCallback onBack;

  const StepGoals({
    super.key,
    required this.initial,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<StepGoals> createState() => _StepGoalsState();
}

class _StepGoalsState extends State<StepGoals> {
  late List<Goal> _goals;
  bool _showCustomForm = false;
  final Set<String> _selectedTemplateIds = {};

  // Custom form state
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _customCategory = 'personal_growth';
  String _customGoalType = kGoalTypeLongTerm;
  DateTime _customTargetDate =
      DateTime.now().add(const Duration(days: 365 * 3));
  bool _customTargetDateTouched = false;

  static const _templates = [
    _GoalTemplate(
        'launch_business',
        'Launch a Business',
        'Build your own company or startup',
        Icons.rocket_launch_rounded,
        'career',
        12),
    _GoalTemplate(
        'get_in_shape',
        'Get in Shape',
        'Transform your health and fitness',
        Icons.fitness_center_rounded,
        'health',
        6),
    _GoalTemplate(
        'build_wealth',
        'Build Wealth',
        'Grow your financial independence',
        Icons.savings_rounded,
        'finances',
        24),
    _GoalTemplate(
        'side_hustle',
        'Start a Side Hustle',
        'Create additional income streams',
        Icons.trending_up_rounded,
        'career',
        9),
    _GoalTemplate(
        'find_purpose',
        'Find My Purpose',
        'Discover your definite major purpose',
        Icons.explore_rounded,
        'personal_growth',
        6),
    _GoalTemplate(
        'relationships',
        'Improve Relationships',
        'Deepen connections that matter',
        Icons.favorite_rounded,
        'relationships',
        6),
    _GoalTemplate(
        'quit_habit',
        'Break a Bad Habit',
        'Replace negative patterns with empowering ones',
        Icons.block_rounded,
        'personal_growth',
        3),
    _GoalTemplate('write_book', 'Write a Book', 'Share your story or expertise',
        Icons.menu_book_rounded, 'career', 12),
    _GoalTemplate(
        'learn_skill',
        'Master a New Skill',
        'Level up your capabilities',
        Icons.school_rounded,
        'personal_growth',
        6),
    _GoalTemplate(
        'mental_health',
        'Improve Mental Health',
        'Build emotional resilience and peace',
        Icons.self_improvement_rounded,
        'health',
        6),
    _GoalTemplate(
        'travel',
        'Travel the World',
        'Experience life beyond your comfort zone',
        Icons.flight_rounded,
        'personal_growth',
        12),
    _GoalTemplate('buy_home', 'Buy a Home', 'Secure your foundation',
        Icons.home_rounded, 'finances', 24),
  ];

  static const _categories = [
    'career',
    'health',
    'relationships',
    'finances',
    'personal_growth'
  ];

  @override
  void initState() {
    super.initState();
    _goals = List.from(widget.initial);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _addTemplateGoals() {
    final now = DateTime.now();
    final newGoals = _templates
        .where((t) => _selectedTemplateIds.contains(t.id))
        .map((t) => Goal(
              id: const Uuid().v4(),
              title: t.title,
              category: t.category,
              goalType: goalTypeFromMonths(t.months),
              description: t.description,
              targetDate: now.add(Duration(days: t.months * 30)),
              createdAt: now,
            ))
        .toList();

    setState(() {
      _goals = [..._goals, ...newGoals];
      _selectedTemplateIds.clear();
      _showCustomForm = false;
    });
  }

  void _selectCustomTimeframe(String value) {
    setState(() {
      _customGoalType = value;
      if (!_customTargetDateTouched) {
        final days =
            kGoalTypeOptions.firstWhere((o) => o.value == value).defaultDays;
        _customTargetDate = DateTime.now().add(Duration(days: days));
      }
    });
  }

  Future<void> _pickCustomDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _customTargetDate,
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 25)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _customTargetDate = picked;
        _customTargetDateTouched = true;
      });
    }
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
      _goals = [..._goals, goal];
      _titleCtrl.clear();
      _descCtrl.clear();
      _customCategory = 'personal_growth';
      _customGoalType = kGoalTypeLongTerm;
      _customTargetDate = DateTime.now().add(const Duration(days: 365 * 3));
      _customTargetDateTouched = false;
      _showCustomForm = false;
    });
  }

  void _removeGoal(int index) => setState(() => _goals.removeAt(index));

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final keyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
    // Footer height = gradient(xl) + button + bottom padding.
    // Scroll content needs extra padding so the last item isn't hidden behind it.
    final scrollBottomPadding = bottomInset + AppSpacing.buttonHeight + AppSpacing.lg;

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
                Text('What do you want to achieve?',
                        style: AppTextStyles.headlineMedium)
                    .animate()
                    .fadeIn(duration: 400.ms),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Choose from common goals or create your own. You can add multiple.',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary),
                ).animate().fadeIn(delay: 100.ms, duration: 400.ms),

                const SizedBox(height: AppSpacing.xl),

                // Added goals chips
                if (_goals.isNotEmpty) ...[
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: _goals
                        .asMap()
                        .entries
                        .map((e) => _GoalChip(
                              label: e.value.title,
                              onRemove: () => _removeGoal(e.key),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const Divider(color: AppColors.border),
                  const SizedBox(height: AppSpacing.lg),
                ],

                if (!_showCustomForm) ...[
                  // Template grid + "Something else" tile
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: AppSpacing.sm,
                    mainAxisSpacing: AppSpacing.sm,
                    childAspectRatio: 1.0,
                    children: [
                      ..._templates.asMap().entries.map((e) {
                        final t = e.value;
                        final selected = _selectedTemplateIds.contains(t.id);
                        final alreadyAdded =
                            _goals.any((g) => g.title == t.title);
                        final color = _categoryColor(t.category);
                        return GestureDetector(
                          onTap: alreadyAdded
                              ? null
                              : () => setState(() {
                                    if (selected) {
                                      _selectedTemplateIds.remove(t.id);
                                    } else {
                                      _selectedTemplateIds.add(t.id);
                                    }
                                  }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: alreadyAdded
                                  ? AppColors.surfaceElevated
                                      .withValues(alpha: 0.4)
                                  : selected
                                      ? color.withValues(alpha: 0.12)
                                      : AppColors.surfaceElevated,
                              borderRadius:
                                  BorderRadius.circular(AppSpacing.radiusMd),
                              border: Border.all(
                                color: alreadyAdded
                                    ? AppColors.border.withValues(alpha: 0.5)
                                    : selected
                                        ? color.withValues(alpha: 0.7)
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
                                    // Large colored icon badge
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: alreadyAdded
                                            ? AppColors.textMuted
                                                .withValues(alpha: 0.12)
                                            : color.withValues(
                                                alpha: selected ? 0.25 : 0.15),
                                        borderRadius: BorderRadius.circular(
                                            AppSpacing.radiusMd),
                                      ),
                                      child: Icon(
                                        t.icon,
                                        size: 26,
                                        color: alreadyAdded
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
                                      ),
                                    if (alreadyAdded)
                                      const Icon(Icons.check_rounded,
                                          color: AppColors.textMuted, size: 16),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Text(
                                  t.title,
                                  style: AppTextStyles.labelLarge.copyWith(
                                    color: alreadyAdded
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
                                  t.description,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: alreadyAdded
                                        ? AppColors.textDisabled
                                        : AppColors.textMuted,
                                    height: 1.3,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ).animate().fadeIn(
                                delay: Duration(milliseconds: e.key * 40),
                                duration: 300.ms,
                              ),
                        );
                      }),
                      // "Something else" tile — always last, opens the custom form
                      GestureDetector(
                        onTap: () => setState(() => _showCustomForm = true),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceElevated,
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusMd),
                            border: const Border.fromBorderSide(
                              BorderSide(color: AppColors.border),
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
                                      color: AppColors.textMuted
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(
                                          AppSpacing.radiusMd),
                                    ),
                                    child: const Icon(
                                      Icons.edit_rounded,
                                      size: 24,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                'Something else',
                                style: AppTextStyles.labelLarge.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Write your own goal',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textMuted,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ).animate().fadeIn(
                              delay: Duration(
                                  milliseconds: _templates.length * 40),
                              duration: 300.ms,
                            ),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  if (_selectedTemplateIds.isNotEmpty)
                    AppPrimaryButton(
                      label:
                          'Add ${_selectedTemplateIds.length} Goal${_selectedTemplateIds.length > 1 ? 's' : ''}',
                      onPressed: _addTemplateGoals,
                      icon: Icons.add_rounded,
                    ),

                  const SizedBox(height: AppSpacing.md),
                ] else ...[
                  // Custom goal form
                  Text('Custom Goal', style: AppTextStyles.headlineSmall),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _titleCtrl,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    style: AppTextStyles.bodyLarge,
                    cursorColor: AppColors.primary,
                    decoration: InputDecoration(
                      hintText: 'What do you want to achieve?',
                      hintStyle: AppTextStyles.bodyLarge
                          .copyWith(color: AppColors.textMuted),
                      filled: true,
                      fillColor: AppColors.surfaceElevated,
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusMd),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusMd),
                        borderSide: const BorderSide(color: AppColors.primary),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusMd),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<String>(
                    value: _customCategory,
                    decoration: InputDecoration(
                      labelText: 'Category',
                      filled: true,
                      fillColor: AppColors.surfaceElevated,
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusMd),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusMd),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                    ),
                    items: _categories
                        .map((c) => DropdownMenuItem(
                              value: c,
                              child: Text(_categoryLabel(c)),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _customCategory = v!),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _descCtrl,
                    style: AppTextStyles.bodyLarge,
                    cursorColor: AppColors.primary,
                    maxLines: 2,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: AppStrings.goalWhyMattersHint,
                      hintStyle: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.textMuted),
                      filled: true,
                      fillColor: AppColors.surfaceElevated,
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusMd),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusMd),
                        borderSide: const BorderSide(color: AppColors.primary),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusMd),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(AppStrings.goalTimeframe,
                      style: AppTextStyles.labelMedium),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: kGoalTypeOptions.map((opt) {
                      final selected = opt.value == _customGoalType;
                      return GestureDetector(
                        onTap: () => _selectCustomTimeframe(opt.value),
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
                              color: selected
                                  ? AppColors.primary
                                  : AppColors.border,
                            ),
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusFull),
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
                  Text(AppStrings.goalTargetDate,
                      style: AppTextStyles.labelMedium),
                  const SizedBox(height: AppSpacing.sm),
                  GestureDetector(
                    onTap: _pickCustomDate,
                    child: Container(
                      height: AppSpacing.inputHeight,
                      padding:
                          const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        border: Border.all(color: AppColors.border),
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusMd),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded,
                              color: AppColors.textMuted, size: 18),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            AppDateUtils.formatDate(_customTargetDate),
                            style: AppTextStyles.bodyLarge,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      AppSecondaryButton(
                        label: 'Cancel',
                        width: 100,
                        onPressed: () =>
                            setState(() => _showCustomForm = false),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: AppPrimaryButton(
                          label: 'Add Goal',
                          onPressed: _titleCtrl.text.trim().isNotEmpty
                              ? _addCustomGoal
                              : null,
                          icon: Icons.add_rounded,
                        ),
                      ),
                    ],
                  ),
                ],

                if (_goals.isEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Select at least one goal to continue.',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.error),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),

        // Footer overlaid at the bottom. Fades out when keyboard is open so the
        // text input has the full screen without buttons crowding it.
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: AnimatedOpacity(
            opacity: keyboardVisible ? 0.0 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: IgnorePointer(
              ignoring: keyboardVisible,
              child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.background.withValues(alpha: 0),
                  AppColors.background,
                ],
                stops: const [0.0, 0.45],
              ),
            ),
            padding: EdgeInsets.fromLTRB(
              AppSpacing.screenPaddingH,
              AppSpacing.xl,
              AppSpacing.screenPaddingH,
              bottomInset + AppSpacing.md,
            ),
            child: Row(
              children: [
                AppSecondaryButton(
                  label: 'Back',
                  width: 100,
                  onPressed: widget.onBack,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: AppPrimaryButton(
                    label: 'Continue',
                    onPressed: _goals.isNotEmpty
                        ? () => widget.onNext(_goals)
                        : null,
                    icon: Icons.arrow_forward_rounded,
                  ),
                ),
              ],
            ),
          ),
            ),
          ),
        ),
      ],
    );
  }

  String _categoryLabel(String cat) =>
      const {
        'career': 'Career',
        'health': 'Health',
        'relationships': 'Relationships',
        'finances': 'Finances',
        'personal_growth': 'Personal Growth',
      }[cat] ??
      cat;
}

class _GoalChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const _GoalChip({required this.label, required this.onRemove});

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
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close_rounded,
                size: 14, color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

class _GoalTemplate {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final String category;
  final int months;

  const _GoalTemplate(this.id, this.title, this.description, this.icon,
      this.category, this.months);
}
