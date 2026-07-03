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
  final String initialPrimaryGoalId;
  final void Function(List<Goal> goals, String primaryGoalId) onNext;
  final VoidCallback onBack;

  const StepGoals({
    super.key,
    required this.initial,
    this.initialPrimaryGoalId = '',
    required this.onNext,
    required this.onBack,
  });

  @override
  State<StepGoals> createState() => _StepGoalsState();
}

class _StepGoalsState extends State<StepGoals> {
  late List<Goal> _goals;
  late String _primaryGoalId;
  bool _showCustomForm = false;
  final Set<String> _selectedTemplateIds = {};

  // Custom form state
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _whyCtrl = TextEditingController();
  String _customCategory = 'personal_growth';
  String _customGoalType = kGoalTypeLongTerm;
  DateTime _customTargetDate =
      DateTime.now().add(const Duration(days: 365 * 3));

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
    _primaryGoalId = _goals.any((g) => g.id == widget.initialPrimaryGoalId)
        ? widget.initialPrimaryGoalId
        : (_goals.isNotEmpty ? _goals.first.id : '');
    _syncWhyToPrimary();
    // Rebuild so the custom "Add Goal" button enables live as the user types
    // (TextField edits don't otherwise trigger a rebuild).
    _titleCtrl.addListener(_onTitleChanged);
  }

  @override
  void dispose() {
    _titleCtrl.removeListener(_onTitleChanged);
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _whyCtrl.dispose();
    super.dispose();
  }

  void _onTitleChanged() => setState(() {});

  Goal? get _primaryGoal {
    for (final g in _goals) {
      if (g.id == _primaryGoalId) return g;
    }
    return null;
  }

  void _syncWhyToPrimary() {
    _whyCtrl.text = _primaryGoal?.description ?? '';
  }

  void _setPrimary(String id) {
    setState(() {
      _primaryGoalId = id;
      _syncWhyToPrimary();
    });
  }

  void _onWhyChanged(String value) {
    final id = _primaryGoalId;
    setState(() {
      _goals = _goals
          .map((g) => g.id == id ? g.copyWith(description: value) : g)
          .toList();
    });
  }

  /// Keeps [_primaryGoalId] valid after goals are added or removed.
  void _ensurePrimary() {
    if (_goals.isEmpty) {
      _primaryGoalId = '';
    } else if (!_goals.any((g) => g.id == _primaryGoalId)) {
      _primaryGoalId = _goals.first.id;
    }
    _syncWhyToPrimary();
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
      _ensurePrimary();
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
      _goals = [..._goals, goal];
      _titleCtrl.clear();
      _descCtrl.clear();
      _customCategory = 'personal_growth';
      _customGoalType = kGoalTypeLongTerm;
      _customTargetDate = DateTime.now().add(const Duration(days: 365 * 3));
      _showCustomForm = false;
      _ensurePrimary();
    });
  }

  void _removeGoal(int index) => setState(() {
        _goals = List.of(_goals)..removeAt(index);
        _ensurePrimary();
      });

  /// Short human-readable horizon label for a template's month count.
  String _horizonLabel(int months) {
    if (months < 12) return '~$months mo';
    if (months == 12) return '~1 yr';
    return '~${(months / 12).round()} yr';
  }

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

                // Added goals + #1 focus selection
                if (_goals.isNotEmpty) ...[
                  if (_goals.length > 1) ...[
                    Text(AppStrings.onboardingPrimaryGoalPrompt,
                        style: AppTextStyles.labelLarge),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      AppStrings.onboardingPrimaryGoalSubtitle,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: _goals
                        .asMap()
                        .entries
                        .map((e) => _GoalChip(
                              label: e.value.title,
                              isPrimary: e.value.id == _primaryGoalId,
                              showStar: _goals.length > 1,
                              onTapPrimary: () => _setPrimary(e.value.id),
                              onRemove: () => _removeGoal(e.key),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  // "Why" for the #1 focus — the highest-value motivation signal.
                  TextField(
                    controller: _whyCtrl,
                    style: AppTextStyles.bodyMedium,
                    cursorColor: AppColors.primary,
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: 2,
                    minLines: 1,
                    onChanged: _onWhyChanged,
                    decoration: InputDecoration(
                      labelText: AppStrings.onboardingPrimaryWhyPrompt,
                      labelStyle: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textSecondary),
                      hintText: AppStrings.goalWhyMattersHint,
                      hintStyle: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.textMuted),
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
                        return Hoverable(
                          cursor: alreadyAdded
                              ? SystemMouseCursors.basic
                              : SystemMouseCursors.click,
                          onTap: alreadyAdded
                              ? null
                              : () => setState(() {
                                    if (selected) {
                                      _selectedTemplateIds.remove(t.id);
                                    } else {
                                      _selectedTemplateIds.add(t.id);
                                    }
                                  }),
                          builder: (context, hovered) => AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: alreadyAdded
                                  ? AppColors.surfaceElevated
                                      .withValues(alpha: 0.4)
                                  : selected
                                      ? color.withValues(alpha: 0.12)
                                      : hovered
                                          ? color.withValues(alpha: 0.06)
                                          : AppColors.surfaceElevated,
                              borderRadius:
                                  BorderRadius.circular(AppSpacing.radiusMd),
                              border: Border.all(
                                color: alreadyAdded
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
                                      )
                                    else if (alreadyAdded)
                                      const Icon(Icons.check_rounded,
                                          color: AppColors.textMuted, size: 16)
                                    else
                                      Text(
                                        _horizonLabel(t.months),
                                        style: AppTextStyles.labelSmall.copyWith(
                                          color: AppColors.textMuted,
                                        ),
                                      ),
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
                          ),
                        ).animate().fadeIn(
                              delay: Duration(milliseconds: e.key * 40),
                              duration: 300.ms,
                            );
                      }),
                      // "Something else" tile — always last, opens the custom form
                      Hoverable(
                        onTap: () => setState(() => _showCustomForm = true),
                        builder: (context, hovered) => AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceElevated,
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusMd),
                            border: Border.fromBorderSide(
                              BorderSide(
                                color: hovered
                                    ? AppColors.textSecondary
                                        .withValues(alpha: 0.5)
                                    : AppColors.border,
                              ),
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
                        ),
                      ).animate().fadeIn(
                            delay: Duration(
                                milliseconds: _templates.length * 40),
                            duration: 300.ms,
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
                        ? () => widget.onNext(_goals, _primaryGoalId)
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
  final bool isPrimary;
  final bool showStar;
  final VoidCallback onTapPrimary;
  final VoidCallback onRemove;

  const _GoalChip({
    required this.label,
    required this.isPrimary,
    required this.showStar,
    required this.onTapPrimary,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final active = isPrimary && showStar;
    return Hoverable(
      cursor: showStar ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onTap: showStar ? onTapPrimary : null,
      builder: (context, hovered) => AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: AppColors.primaryContainer,
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          border: Border.all(
            color: active
                ? AppColors.primary
                : AppColors.primary
                    .withValues(alpha: hovered && showStar ? 0.55 : 0.3),
            width: active ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showStar) ...[
              Icon(
                active ? Icons.star_rounded : Icons.star_outline_rounded,
                size: 14,
                color: AppColors.primary,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary),
            ),
            const SizedBox(width: AppSpacing.xs),
            Hoverable(
              onTap: onRemove,
              builder: (context, _) => const Icon(Icons.close_rounded,
                  size: 14, color: AppColors.primary),
            ),
          ],
        ),
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
