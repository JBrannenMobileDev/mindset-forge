import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/app_strings.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_text_field.dart';
import '../../models/goal.dart';
import '../../providers/goals_provider.dart';

class GoalFormModal {
  static void show(BuildContext context, WidgetRef ref, {Goal? existing}) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
      ),
      builder: (_) => ProviderScope(
        parent: ProviderScope.containerOf(context),
        child: _GoalFormSheet(existing: existing),
      ),
    );
  }
}

class _GoalFormSheet extends ConsumerStatefulWidget {
  final Goal? existing;

  const _GoalFormSheet({this.existing});

  @override
  ConsumerState<_GoalFormSheet> createState() => _GoalFormSheetState();
}

class _GoalFormSheetState extends ConsumerState<_GoalFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _identityCtrl;
  late String _category;
  late DateTime _targetDate;
  bool _isSaving = false;

  static const _categories = [
    _Cat('career', AppStrings.categoryCareer, Icons.work_rounded, AppColors.categoryCareer),
    _Cat('health', AppStrings.categoryHealth, Icons.favorite_rounded, AppColors.categoryHealth),
    _Cat('relationships', AppStrings.categoryRelationships, Icons.people_rounded, AppColors.categoryRelationships),
    _Cat('finances', AppStrings.categoryFinances, Icons.attach_money_rounded, AppColors.categoryFinances),
    _Cat('personal_growth', AppStrings.categoryPersonalGrowth, Icons.auto_awesome_rounded, AppColors.categoryPersonalGrowth),
  ];

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.existing?.title ?? '');
    _descCtrl = TextEditingController(text: widget.existing?.description ?? '');
    _identityCtrl = TextEditingController(text: widget.existing?.identityBecomes ?? '');
    _category = widget.existing?.category ?? 'personal_growth';
    _targetDate = widget.existing?.targetDate ?? DateTime.now().add(const Duration(days: 90));
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _identityCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final goal = Goal(
        id: widget.existing?.id ?? const Uuid().v4(),
        title: _titleCtrl.text.trim(),
        category: _category,
        description: _descCtrl.text.trim(),
        targetDate: _targetDate,
        identityBecomes: _identityCtrl.text.trim(),
        progressPercent: widget.existing?.progressPercent ?? 0.0,
        createdAt: widget.existing?.createdAt ?? DateTime.now(),
      );

      if (widget.existing != null) {
        await ref.read(goalsProvider.notifier).updateGoal(goal);
      } else {
        await ref.read(goalsProvider.notifier).addGoal(goal);
      }

      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.errorGeneric)),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    widget.existing != null ? 'Edit Goal' : AppStrings.addGoal,
                    style: AppTextStyles.headlineMedium,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Category', style: AppTextStyles.labelMedium),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: _categories.map((cat) {
                  final selected = cat.value == _category;
                  return GestureDetector(
                    onTap: () => setState(() => _category = cat.value),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: selected ? cat.color.withValues(alpha: 0.15) : AppColors.surfaceElevated,
                        border: Border.all(
                          color: selected ? cat.color : AppColors.border,
                        ),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(cat.icon, color: selected ? cat.color : AppColors.textMuted, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            cat.label,
                            style: AppTextStyles.labelSmall.copyWith(
                              color: selected ? cat.color : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: AppStrings.goalTitle,
                hint: 'e.g., Build my dream business',
                controller: _titleCtrl,
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: '${AppStrings.goalDescription} (optional)',
                hint: 'More details...',
                controller: _descCtrl,
                maxLines: 3,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: AppStrings.goalIdentityBecomes,
                hint: 'e.g., I become a confident entrepreneur',
                controller: _identityCtrl,
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: AppSpacing.md),
              Text('Target Date', style: AppTextStyles.labelMedium),
              const SizedBox(height: AppSpacing.sm),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _targetDate,
                    firstDate: DateTime.now().add(const Duration(days: 1)),
                    lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
                    builder: (ctx, child) => Theme(
                      data: Theme.of(ctx).copyWith(
                        colorScheme: const ColorScheme.dark(primary: AppColors.primary),
                      ),
                      child: child!,
                    ),
                  );
                  if (picked != null) setState(() => _targetDate = picked);
                },
                child: Container(
                  height: AppSpacing.inputHeight,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded, color: AppColors.textMuted, size: 18),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        '${_targetDate.month}/${_targetDate.day}/${_targetDate.year}',
                        style: AppTextStyles.bodyLarge,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppPrimaryButton(
                label: widget.existing != null ? 'Save Changes' : AppStrings.addGoal,
                onPressed: _save,
                isLoading: _isSaving,
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}

class _Cat {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const _Cat(this.value, this.label, this.icon, this.color);
}
