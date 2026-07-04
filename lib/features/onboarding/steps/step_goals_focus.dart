import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/hoverable.dart';
import '../../../models/goal.dart';
import 'goals_shared.dart';

/// Onboarding goals — step 2 of 2: star your #1 focus and say why.
///
/// Shows the user's selected goals as full-width cards. When there are multiple
/// goals the user taps to pick a primary; with a single goal the star UI is
/// skipped and [primaryGoalId] is set automatically.
class StepGoalsFocus extends StatefulWidget {
  final List<Goal> goals;
  final String initialPrimaryGoalId;
  final void Function(List<Goal> goals, String primaryGoalId) onNext;
  final VoidCallback onBack;
  final VoidCallback? onChangeGoals;

  const StepGoalsFocus({
    super.key,
    required this.goals,
    this.initialPrimaryGoalId = '',
    required this.onNext,
    required this.onBack,
    this.onChangeGoals,
  });

  @override
  State<StepGoalsFocus> createState() => _StepGoalsFocusState();
}

class _StepGoalsFocusState extends State<StepGoalsFocus> {
  late List<Goal> _goals;
  late String _primaryGoalId;
  final _whyCtrl = TextEditingController();

  bool get _multipleGoals => _goals.length > 1;

  Goal? get _primaryGoal {
    for (final g in _goals) {
      if (g.id == _primaryGoalId) return g;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _goals = List.from(widget.goals);
    _primaryGoalId = _resolvePrimaryId();
    _syncWhyToPrimary();
  }

  @override
  void dispose() {
    _whyCtrl.dispose();
    super.dispose();
  }

  String _resolvePrimaryId() {
    if (_goals.isEmpty) return '';
    if (_goals.length == 1) return _goals.first.id;
    if (_goals.any((g) => g.id == widget.initialPrimaryGoalId)) {
      return widget.initialPrimaryGoalId;
    }
    return _goals.first.id;
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

  void _continue() {
    widget.onNext(_goals, _primaryGoalId);
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
                _multipleGoals
                    ? AppStrings.onboardingGoalsFocusTitle
                    : AppStrings.onboardingGoalsFocusTitleSingle,
                style: AppTextStyles.headlineMedium,
              ).animate().fadeIn(duration: 400.ms),
              const SizedBox(height: AppSpacing.xs),
              Text(
                _multipleGoals
                    ? AppStrings.onboardingGoalsFocusSubtitle
                    : AppStrings.onboardingGoalsFocusSubtitleSingle,
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary),
              ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
              if (widget.onChangeGoals != null) ...[
                const SizedBox(height: AppSpacing.sm),
                AppTextButton(
                  label: AppStrings.onboardingGoalsChangeGoals,
                  onPressed: widget.onChangeGoals,
                ),
              ],
              const SizedBox(height: AppSpacing.xl),

              if (_multipleGoals) ...[
                Text(
                  AppStrings.onboardingPrimaryGoalPrompt,
                  style: AppTextStyles.labelLarge,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  AppStrings.onboardingPrimaryGoalSubtitle,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              ..._goals.asMap().entries.map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _FocusGoalCard(
                        goal: e.value,
                        index: e.key,
                        isPrimary: e.value.id == _primaryGoalId,
                        showStar: _multipleGoals,
                        onTap: _multipleGoals
                            ? () => _setPrimary(e.value.id)
                            : null,
                      ),
                    ),
                  ),

              const SizedBox(height: AppSpacing.lg),

              Text(
                AppStrings.onboardingPrimaryWhyPrompt,
                style: AppTextStyles.labelLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _whyCtrl,
                style: AppTextStyles.bodyMedium,
                cursorColor: AppColors.primary,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 4,
                minLines: 3,
                onChanged: _onWhyChanged,
                decoration: InputDecoration(
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
            ],
          ),
        ),
        OnboardingGoalsFooter(
          onBack: widget.onBack,
          onContinue: _goals.isNotEmpty ? _continue : null,
        ),
      ],
    );
  }
}

class _FocusGoalCard extends StatelessWidget {
  final Goal goal;
  final int index;
  final bool isPrimary;
  final bool showStar;
  final VoidCallback? onTap;

  const _FocusGoalCard({
    required this.goal,
    required this.index,
    required this.isPrimary,
    required this.showStar,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final template = templateForGoal(goal);
    final color = goalCategoryColor(goal.category);
    final icon = template?.icon ?? Icons.flag_rounded;

    return Hoverable(
      cursor: showStar ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onTap: onTap,
      builder: (context, hovered) => AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isPrimary
              ? AppColors.primaryContainer
              : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(
            color: isPrimary
                ? AppColors.primary
                : hovered && showStar
                    ? AppColors.primary.withValues(alpha: 0.5)
                    : AppColors.border,
            width: isPrimary ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: isPrimary ? 0.25 : 0.15),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Icon(icon, size: 22, color: color),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    goal.title,
                    style: AppTextStyles.labelLarge.copyWith(
                      color: isPrimary
                          ? AppColors.primary
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    goalCategoryLabel(goal.category),
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            if (showStar)
              Icon(
                isPrimary ? Icons.star_rounded : Icons.star_outline_rounded,
                color: AppColors.primary,
                size: 22,
              ),
          ],
        ),
      ),
    ).animate().fadeIn(
          delay: Duration(milliseconds: index * 50),
          duration: 300.ms,
        );
  }
}
