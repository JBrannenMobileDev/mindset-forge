import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../models/goal.dart';

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
  String _customCategory = 'personal_growth';
  DateTime _customTargetDate = DateTime.now().add(const Duration(days: 90));

  static const _templates = [
    _GoalTemplate('launch_business', 'Launch a Business', 'Build your own company or startup', Icons.rocket_launch_rounded, 'career', 12),
    _GoalTemplate('get_in_shape', 'Get in Shape', 'Transform your health and fitness', Icons.fitness_center_rounded, 'health', 6),
    _GoalTemplate('build_wealth', 'Build Wealth', 'Grow your financial independence', Icons.savings_rounded, 'finances', 24),
    _GoalTemplate('side_hustle', 'Start a Side Hustle', 'Create additional income streams', Icons.trending_up_rounded, 'career', 9),
    _GoalTemplate('find_purpose', 'Find My Purpose', 'Discover your definite major purpose', Icons.explore_rounded, 'personal_growth', 6),
    _GoalTemplate('relationships', 'Improve Relationships', 'Deepen connections that matter', Icons.favorite_rounded, 'relationships', 6),
    _GoalTemplate('quit_habit', 'Break a Bad Habit', 'Replace negative patterns with empowering ones', Icons.block_rounded, 'personal_growth', 3),
    _GoalTemplate('write_book', 'Write a Book', 'Share your story or expertise', Icons.menu_book_rounded, 'career', 12),
    _GoalTemplate('learn_skill', 'Master a New Skill', 'Level up your capabilities', Icons.school_rounded, 'personal_growth', 6),
    _GoalTemplate('mental_health', 'Improve Mental Health', 'Build emotional resilience and peace', Icons.self_improvement_rounded, 'health', 6),
    _GoalTemplate('travel', 'Travel the World', 'Experience life beyond your comfort zone', Icons.flight_rounded, 'personal_growth', 12),
    _GoalTemplate('buy_home', 'Buy a Home', 'Secure your foundation', Icons.home_rounded, 'finances', 24),
  ];

  static const _categories = ['career', 'health', 'relationships', 'finances', 'personal_growth'];

  @override
  void initState() {
    super.initState();
    _goals = List.from(widget.initial);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
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

  void _addCustomGoal() {
    if (_titleCtrl.text.trim().isEmpty) return;
    final goal = Goal(
      id: const Uuid().v4(),
      title: _titleCtrl.text.trim(),
      category: _customCategory,
      targetDate: _customTargetDate,
      createdAt: DateTime.now(),
    );
    setState(() {
      _goals = [..._goals, goal];
      _titleCtrl.clear();
      _customCategory = 'personal_growth';
      _customTargetDate = DateTime.now().add(const Duration(days: 90));
      _showCustomForm = false;
    });
  }

  void _removeGoal(int index) => setState(() => _goals.removeAt(index));

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.screenPaddingH),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('What do you want to achieve?', style: AppTextStyles.headlineMedium)
                    .animate().fadeIn(duration: 400.ms),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Choose from common goals or create your own. You can add multiple.',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                ).animate().fadeIn(delay: 100.ms, duration: 400.ms),

                const SizedBox(height: AppSpacing.xl),

                // Added goals chips
                if (_goals.isNotEmpty) ...[
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: _goals.asMap().entries.map((e) => _GoalChip(
                          label: e.value.title,
                          onRemove: () => _removeGoal(e.key),
                        )).toList(),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Divider(color: AppColors.border),
                  const SizedBox(height: AppSpacing.lg),
                ],

                if (!_showCustomForm) ...[
                  // Template grid
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: AppSpacing.sm,
                    mainAxisSpacing: AppSpacing.sm,
                    childAspectRatio: 1.15,
                    children: _templates.asMap().entries.map((e) {
                      final t = e.value;
                      final selected = _selectedTemplateIds.contains(t.id);
                      final alreadyAdded = _goals.any((g) => g.title == t.title);
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
                                ? AppColors.surfaceElevated.withValues(alpha: 0.5)
                                : selected
                                    ? AppColors.primaryContainer
                                    : AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                            border: Border.all(
                              color: selected ? AppColors.primary : AppColors.border,
                              width: selected ? 1.5 : 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Icon(t.icon,
                                      color: selected ? AppColors.primary : AppColors.textSecondary,
                                      size: 22),
                                  if (selected)
                                    const Icon(Icons.check_circle_rounded,
                                        color: AppColors.primary, size: 16),
                                  if (alreadyAdded)
                                    const Icon(Icons.check_rounded,
                                        color: AppColors.textMuted, size: 16),
                                ],
                              ),
                              const Spacer(),
                              Text(
                                t.title,
                                style: AppTextStyles.bodySmall.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: alreadyAdded
                                      ? AppColors.textMuted
                                      : selected
                                          ? AppColors.primary
                                          : AppColors.textPrimary,
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
                    }).toList(),
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // Add selected templates button
                  if (_selectedTemplateIds.isNotEmpty)
                    AppPrimaryButton(
                      label: 'Add ${_selectedTemplateIds.length} Goal${_selectedTemplateIds.length > 1 ? 's' : ''}',
                      onPressed: _addTemplateGoals,
                      icon: Icons.add_rounded,
                    ),

                  const SizedBox(height: AppSpacing.md),

                  // Custom goal button
                  Center(
                    child: TextButton.icon(
                      onPressed: () => setState(() => _showCustomForm = true),
                      icon: const Icon(Icons.edit_rounded, size: 16, color: AppColors.textSecondary),
                      label: Text(
                        'Create a custom goal instead',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                ] else ...[
                  // Custom goal form
                  Text('Custom Goal', style: AppTextStyles.headlineSmall),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _titleCtrl,
                    autofocus: true,
                    style: AppTextStyles.bodyLarge,
                    cursorColor: AppColors.primary,
                    decoration: InputDecoration(
                      hintText: 'What do you want to achieve?',
                      hintStyle: AppTextStyles.bodyLarge.copyWith(color: AppColors.textMuted),
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
                    value: _customCategory,
                    decoration: InputDecoration(
                      labelText: 'Category',
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
                    items: _categories.map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(_categoryLabel(c)),
                        )).toList(),
                    onChanged: (v) => setState(() => _customCategory = v!),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      AppSecondaryButton(
                        label: 'Cancel',
                        onPressed: () => setState(() => _showCustomForm = false),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: AppPrimaryButton(
                          label: 'Add Goal',
                          onPressed: _titleCtrl.text.trim().isNotEmpty ? _addCustomGoal : null,
                          icon: Icons.add_rounded,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),

        // Footer
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenPaddingH,
            AppSpacing.md,
            AppSpacing.screenPaddingH,
            AppSpacing.xl,
          ),
          child: Column(
            children: [
              if (_goals.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Text(
                    'Select at least one goal to continue.',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
                    textAlign: TextAlign.center,
                  ),
                ),
              Row(
                children: [
                  AppSecondaryButton(label: 'Back', onPressed: widget.onBack),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppPrimaryButton(
                      label: 'Continue',
                      onPressed: _goals.isNotEmpty ? () => widget.onNext(_goals) : null,
                      icon: Icons.arrow_forward_rounded,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _categoryLabel(String cat) => const {
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
            child: const Icon(Icons.close_rounded, size: 14, color: AppColors.primary),
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

  const _GoalTemplate(this.id, this.title, this.description, this.icon, this.category, this.months);
}
