import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/goal_meta.dart';
import '../../core/constants/goal_templates.dart';
import '../../core/utils/app_date_utils.dart';
import '../../core/widgets/adaptive_sheet.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/goal_template_card.dart';
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
      // Gifted-premium partners get unlimited, gate-free access during their
      // window; the setup/upgrade gates only apply once it lapses.
      if (profile != null &&
          profile.isPartnerAccount &&
          !profile.hasGiftedPremium) {
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

    // The sheet pops with the newly created goal (or null for edits/cancel)
    // so we can chain the post-creation "build your plan" experience.
    final created = await showAdaptiveSheet<Goal?>(
      context: context,
      dialogMaxWidth: 560,
      builder: (_) => ProviderScope(
        parent: ProviderScope.containerOf(context),
        child: _GoalCreationFlow(
          existing: existing,
          initialTitle: initialTitle,
        ),
      ),
    );

    // Immediately guide every newly created goal into milestones and
    // supporting habit/affirmation wiring.
    if (created != null && context.mounted) {
      await GoalSetupSheet.show(context, ref, created);
    }
  }
}

enum _CreationStep { gallery, form }

/// New goals open on the template gallery; edits go straight to the form.
class _GoalCreationFlow extends StatefulWidget {
  final Goal? existing;
  final String? initialTitle;

  const _GoalCreationFlow({this.existing, this.initialTitle});

  @override
  State<_GoalCreationFlow> createState() => _GoalCreationFlowState();
}

class _GoalCreationFlowState extends State<_GoalCreationFlow> {
  late _CreationStep _step;
  Goal? _seed;

  @override
  void initState() {
    super.initState();
    // Deep-link title skips the gallery — user already has intent.
    _step = widget.existing != null || widget.initialTitle != null
        ? _CreationStep.form
        : _CreationStep.gallery;
  }

  void _openForm({Goal? seed}) {
    setState(() {
      _seed = seed;
      _step = _CreationStep.form;
    });
  }

  void _backToGallery() {
    setState(() {
      _seed = null;
      _step = _CreationStep.gallery;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.existing != null || _step == _CreationStep.form) {
      return _GoalFormSheet(
        existing: widget.existing,
        seed: widget.existing == null ? _seed : null,
        initialTitle: widget.initialTitle,
        onBack: widget.existing == null && widget.initialTitle == null
            ? _backToGallery
            : null,
      );
    }
    return _GoalTemplateGallery(onTemplate: _openForm);
  }
}

/// Single-select template picker for in-app goal creation.
class _GoalTemplateGallery extends StatelessWidget {
  final void Function({Goal? seed}) onTemplate;

  const _GoalTemplateGallery({required this.onTemplate});

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.85;
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
          children: [
            const SheetHandle(),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: Text(
                    AppStrings.goalGalleryTitle,
                    style: AppTextStyles.headlineMedium,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              AppStrings.goalGallerySubtitle,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: AppSpacing.sm,
              mainAxisSpacing: AppSpacing.sm,
              childAspectRatio: 1.0,
              children: [
                ...kGoalTemplates.asMap().entries.map(
                      (e) => GoalTemplateCard(
                        template: e.value,
                        index: e.key,
                        selected: false,
                        onTap: () => onTemplate(
                          seed: goalDraftFromTemplate(e.value),
                        ),
                      ),
                    ),
                GoalSomethingElseTile(
                  index: kGoalTemplates.length,
                  title: AppStrings.goalStartFromScratch,
                  subtitle: AppStrings.goalStartFromScratchHint,
                  onTap: () => onTemplate(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalFormSheet extends ConsumerStatefulWidget {
  final Goal? existing;
  final Goal? seed;
  final String? initialTitle;
  final VoidCallback? onBack;

  const _GoalFormSheet({
    this.existing,
    this.seed,
    this.initialTitle,
    this.onBack,
  });

  @override
  ConsumerState<_GoalFormSheet> createState() => _GoalFormSheetState();
}

class _GoalFormSheetState extends ConsumerState<_GoalFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _identityCtrl;
  late final TextEditingController _customCategoryCtrl;
  late String _category;
  late String _goalType;
  late DateTime _targetDate;
  bool _targetDateTouched = false;
  bool _customCategory = false;
  bool _isSaving = false;
  bool _isRefining = false;

  Goal? get _prefill => widget.existing ?? widget.seed;

  String get _effectiveCategory =>
      _customCategory ? _customCategoryCtrl.text.trim() : _category;

  @override
  void initState() {
    super.initState();
    final prefill = _prefill;
    _titleCtrl = TextEditingController(
      text: prefill?.title ?? widget.initialTitle ?? '',
    );
    _descCtrl = TextEditingController(text: prefill?.description ?? '');
    _identityCtrl =
        TextEditingController(text: prefill?.identityBecomes ?? '');
    final prefillCategory = prefill?.category ?? 'personal_growth';
    if (prefill != null && !isCuratedGoalCategory(prefillCategory)) {
      _customCategory = true;
      _category = 'personal_growth';
      _customCategoryCtrl = TextEditingController(text: prefillCategory);
    } else {
      _customCategory = false;
      _category = prefillCategory;
      _customCategoryCtrl = TextEditingController();
    }
    _goalType = prefill?.goalType ?? kGoalTypeLongTerm;
    if (prefill != null) {
      _targetDate = prefill.targetDate;
      _targetDateTouched = widget.existing != null;
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
          .refineGoal(draft, _effectiveCategory, profile);
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
    _customCategoryCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_customCategory && _customCategoryCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.categoryOtherHint)),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final goal = Goal(
        id: widget.existing?.id ?? const Uuid().v4(),
        title: _titleCtrl.text.trim(),
        category: _effectiveCategory,
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

      if (mounted) {
        Navigator.pop(context, isNew ? goal : null);
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
                  if (widget.onBack != null)
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      onPressed: widget.onBack,
                    ),
                  Expanded(
                    child: Text(
                      widget.existing != null
                          ? AppStrings.editGoal
                          : AppStrings.addGoal,
                      style: AppTextStyles.headlineMedium,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(AppStrings.goalIntentionPrompt,
                  style: AppTextStyles.headlineSmall),
              const SizedBox(height: AppSpacing.md),
              Text(AppStrings.goalCategory, style: AppTextStyles.labelMedium),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  ...kGoalCategories.map((cat) {
                  final selected = !_customCategory && cat == _category;
                  final color = goalCategoryColor(cat);
                  final icon = goalCategoryIcon(cat);
                  return GestureDetector(
                    onTap: () => setState(() {
                      _customCategory = false;
                      _category = cat;
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? color.withValues(alpha: 0.15)
                            : AppColors.surfaceElevated,
                        border: Border.all(
                          color: selected ? color : AppColors.border,
                        ),
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusFull),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon,
                              color: selected ? color : AppColors.textMuted,
                              size: 14),
                          const SizedBox(width: 4),
                          Text(
                            goalCategoryLabel(cat),
                            style: AppTextStyles.labelSmall.copyWith(
                              color: selected
                                  ? color
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                  GestureDetector(
                    onTap: () => setState(() => _customCategory = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: _customCategory
                            ? AppColors.primaryContainer
                            : AppColors.surfaceElevated,
                        border: Border.all(
                          color: _customCategory
                              ? AppColors.primary
                              : AppColors.border,
                        ),
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusFull),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit_rounded,
                              color: _customCategory
                                  ? AppColors.primary
                                  : AppColors.textMuted,
                              size: 14),
                          const SizedBox(width: 4),
                          Text(
                            AppStrings.categoryOther,
                            style: AppTextStyles.labelSmall.copyWith(
                              color: _customCategory
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (_customCategory) ...[
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  label: AppStrings.categoryOther,
                  hint: AppStrings.categoryOtherHint,
                  controller: _customCategoryCtrl,
                  textCapitalization: TextCapitalization.words,
                  validator: (v) => _customCategory &&
                          (v == null || v.trim().isEmpty)
                      ? AppStrings.fieldRequired
                      : null,
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: AppStrings.goalTitle,
                hint: AppStrings.goalTitleHint,
                controller: _titleCtrl,
                textCapitalization: TextCapitalization.words,
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(AppStrings.goalIdentityPrompt,
                  style: AppTextStyles.headlineSmall),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                label: AppStrings.goalIdentityBecomes,
                hint: AppStrings.goalIdentityHint,
                controller: _identityCtrl,
                textCapitalization: TextCapitalization.sentences,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? AppStrings.fieldRequired : null,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(AppStrings.goalWhyMatters,
                  style: AppTextStyles.headlineSmall),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                label: AppStrings.goalDescription,
                hint: AppStrings.goalWhyMattersHint,
                controller: _descCtrl,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 3,
              ),
              const SizedBox(height: AppSpacing.md),
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
                        colorScheme:
                            const ColorScheme.dark(primary: AppColors.primary),
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
                      const Icon(Icons.calendar_today_rounded,
                          color: AppColors.textMuted, size: 18),
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
