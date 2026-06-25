import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/goal_meta.dart';
import '../../core/utils/app_date_utils.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/partner_upgrade_sheet.dart';
import '../../models/goal.dart';
import '../../providers/auth_provider.dart';
import '../../providers/claude_provider.dart';
import '../../providers/goals_provider.dart';
import '../../providers/partner_limits_provider.dart';
import 'goal_setup_sheet.dart';
import 'widgets/sheet_handle.dart';

class GoalFormModal {
  static Future<void> show(
    BuildContext context,
    WidgetRef ref, {
    Goal? existing,
    String? initialTitle,
  }) async {
    // Free partner accounts must set up their journey first, then are capped on
    // how many goals they can create before upgrading.
    if (existing == null) {
      final profile = ref.read(currentUserProfileProvider).valueOrNull;
      if (profile != null && profile.isPartnerAccount) {
        if (!profile.hasCompletedOnboarding) {
          showPartnerSetupSheet(
            context,
            featureName: 'goal tracking',
            partnerName: profile.supportingPersonName,
          );
          return;
        }
        if (!ref.read(partnerLimitsProvider).canUse(profile, PartnerFeature.goal)) {
          showPartnerUpgradeSheet(
            context,
            featureName: 'goal tracking',
            partnerName: profile.supportingPersonName,
          );
          return;
        }
      }
    }

    // The form sheet pops with the newly created goal (or null for edits/cancel)
    // so we can chain the post-creation "build your plan" experience.
    final created = await showModalBottomSheet<Goal?>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
      ),
      builder: (_) => ProviderScope(
        parent: ProviderScope.containerOf(context),
        child: _GoalFormSheet(existing: existing, initialTitle: initialTitle),
      ),
    );

    // For long-horizon goals, immediately guide the user into milestones and
    // supporting habit/affirmation wiring.
    if (created != null && created.isLongHorizon && context.mounted) {
      await GoalSetupSheet.show(context, ref, created);
    }
  }
}

class _GoalFormSheet extends ConsumerStatefulWidget {
  final Goal? existing;
  final String? initialTitle;

  const _GoalFormSheet({this.existing, this.initialTitle});

  @override
  ConsumerState<_GoalFormSheet> createState() => _GoalFormSheetState();
}

class _GoalFormSheetState extends ConsumerState<_GoalFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _identityCtrl;
  late String _category;
  late String _goalType;
  late DateTime _targetDate;
  bool _targetDateTouched = false;
  bool _isSaving = false;
  bool _isRefining = false;

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
    _titleCtrl = TextEditingController(
      text: widget.existing?.title ?? widget.initialTitle ?? '',
    );
    _descCtrl = TextEditingController(text: widget.existing?.description ?? '');
    _identityCtrl = TextEditingController(text: widget.existing?.identityBecomes ?? '');
    _category = widget.existing?.category ?? 'personal_growth';
    _goalType = widget.existing?.goalType ?? kGoalTypeLongTerm;
    if (widget.existing != null) {
      _targetDate = widget.existing!.targetDate;
      _targetDateTouched = true;
    } else {
      final defaultDays = kGoalTypeOptions
          .firstWhere((o) => o.value == _goalType)
          .defaultDays;
      _targetDate = DateTime.now().add(Duration(days: defaultDays));
    }
  }

  void _selectTimeframe(String value) {
    setState(() {
      _goalType = value;
      // Re-seed the target date from the timeframe unless the user picked one.
      if (!_targetDateTouched) {
        final days =
            kGoalTypeOptions.firstWhere((o) => o.value == value).defaultDays;
        _targetDate = DateTime.now().add(Duration(days: days));
      }
    });
  }

  Future<void> _refineWithAI() async {
    final draft = _titleCtrl.text.trim();
    if (draft.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.goalTitleHint)),
      );
      return;
    }
    final profile = ref.read(currentUserProfileProvider).valueOrNull;
    if (profile == null) return;

    setState(() => _isRefining = true);
    try {
      final result = await ref
          .read(claudeServiceProvider)
          .refineGoal(draft, _category, profile);
      if (!mounted) return;
      setState(() {
        _titleCtrl.text = result['title'] ?? draft;
        final desc = result['description'] ?? '';
        if (desc.isNotEmpty && _descCtrl.text.trim().isEmpty) {
          _descCtrl.text = desc;
        }
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.errorAI)),
        );
      }
    } finally {
      if (mounted) setState(() => _isRefining = false);
    }
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
        goalType: _goalType,
        description: _descCtrl.text.trim(),
        parentGoalId: widget.existing?.parentGoalId,
        targetDate: _targetDate,
        identityBecomes: _identityCtrl.text.trim(),
        progressPercent: widget.existing?.progressPercent ?? 0.0,
        actionSteps: widget.existing?.actionSteps ?? const [],
        status: widget.existing?.status ?? 'active',
        completedAt: widget.existing?.completedAt,
        createdAt: widget.existing?.createdAt ?? DateTime.now(),
      );

      final isNew = widget.existing == null;
      if (isNew) {
        await ref.read(goalsProvider.notifier).addGoal(goal);
      } else {
        await ref.read(goalsProvider.notifier).updateGoal(goal);
      }

      // Pop with the goal only for new top-level goals so the caller can chain
      // the post-creation setup sheet. Edits and sub-goals close silently.
      if (mounted) {
        Navigator.pop(context, isNew && goal.isLongTerm ? goal : null);
      }
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
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.sm,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SheetHandle(),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Text(
                    widget.existing != null
                        ? AppStrings.editGoal
                        : AppStrings.addGoal,
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

              // 1. Intention — category + title (with AI refine)
              Text(AppStrings.goalIntentionPrompt,
                  style: AppTextStyles.headlineSmall),
              const SizedBox(height: AppSpacing.md),
              Text(AppStrings.goalCategory, style: AppTextStyles.labelMedium),
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
                hint: AppStrings.goalTitleHint,
                controller: _titleCtrl,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? AppStrings.fieldRequired : null,
              ),
              const SizedBox(height: AppSpacing.xs),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _isRefining ? null : _refineWithAI,
                  icon: _isRefining
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.primary),
                        )
                      : const Icon(Icons.auto_awesome_rounded,
                          size: 16, color: AppColors.primary),
                  label: Text(
                    AppStrings.goalRefineWithAI,
                    style: AppTextStyles.labelMedium
                        .copyWith(color: AppColors.primary),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // 2. Identity anchor — the heart of the experience
              Text(AppStrings.goalIdentityPrompt,
                  style: AppTextStyles.headlineSmall),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                label: AppStrings.goalIdentityBecomes,
                hint: AppStrings.goalIdentityHint,
                controller: _identityCtrl,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? AppStrings.fieldRequired : null,
              ),
              const SizedBox(height: AppSpacing.md),

              // 3. Why it matters
              Text(AppStrings.goalWhyMatters,
                  style: AppTextStyles.headlineSmall),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                label: AppStrings.goalDescription,
                hint: AppStrings.goalWhyMattersHint,
                controller: _descCtrl,
                maxLines: 3,
              ),
              const SizedBox(height: AppSpacing.md),

              // 4. Timeframe + target date
              Text(AppStrings.goalTimeframe, style: AppTextStyles.labelMedium),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: kGoalTypeOptions.map((opt) {
                  final selected = opt.value == _goalType;
                  return GestureDetector(
                    onTap: () => _selectTimeframe(opt.value),
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
              Text(AppStrings.goalTargetDate, style: AppTextStyles.labelMedium),
              const SizedBox(height: AppSpacing.sm),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _targetDate,
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
                      _targetDate = picked;
                      _targetDateTouched = true;
                    });
                  }
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
                        AppDateUtils.formatDate(_targetDate),
                        style: AppTextStyles.bodyLarge,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppPrimaryButton(
                label: widget.existing != null
                    ? AppStrings.saveChanges
                    : AppStrings.addGoal,
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
