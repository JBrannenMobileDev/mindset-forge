import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/app_button.dart';
import '../../../models/user_profile.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/claude_provider.dart';
import '../../../providers/daily_completion_provider.dart';

/// Shows the Plan Day bottom sheet. Call this from anywhere that has a
/// BuildContext and WidgetRef (e.g. DailyWinsTracker tile tap).
Future<void> showPlanDaySheet(
  BuildContext context,
  WidgetRef ref,
  UserProfile profile,
) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppSpacing.radiusXl),
      ),
    ),
    builder: (_) => ProviderScope(
      parent: ProviderScope.containerOf(context),
      child: _PlanDaySheet(profile: profile),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────

class _PlanDaySheet extends ConsumerStatefulWidget {
  final UserProfile profile;

  const _PlanDaySheet({required this.profile});

  @override
  ConsumerState<_PlanDaySheet> createState() => _PlanDaySheetState();
}

class _PlanDaySheetState extends ConsumerState<_PlanDaySheet> {
  List<String> _actions = [];
  int? _selectedIndex;
  bool _isLoading = true;
  bool _isCommitting = false;

  final _customCtrl = TextEditingController();

  String get _todayStr {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _loadActions();
  }

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadActions() async {
    // Re-use today's cached actions if available, otherwise generate new ones
    final p = widget.profile;
    if (p.priorityActionsDate == _todayStr && p.priorityActions.isNotEmpty) {
      setState(() {
        _actions = List<String>.from(p.priorityActions);
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);
    try {
      final actions = await ref
          .read(claudeServiceProvider)
          .generatePriorityActions(widget.profile);
      if (mounted) {
        setState(() {
          _actions = actions;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _addCustomAction() {
    final text = _customCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _actions.add(text);
      _selectedIndex = _actions.length - 1; // auto-select the new item
      _customCtrl.clear();
    });
    // Dismiss keyboard
    FocusScope.of(context).unfocus();
  }

  void _removeAction(int idx) {
    setState(() {
      _actions.removeAt(idx);
      if (_selectedIndex == idx) {
        _selectedIndex = null;
      } else if (_selectedIndex != null && _selectedIndex! > idx) {
        _selectedIndex = _selectedIndex! - 1;
      }
    });
  }

  Future<void> _commit() async {
    if (_selectedIndex == null || _selectedIndex! >= _actions.length) return;
    final focusAction = _actions[_selectedIndex!];

    setState(() => _isCommitting = true);
    try {
      final uid = ref.read(authStateProvider).valueOrNull?.uid;
      if (uid != null) {
        await ref.read(firestoreServiceProvider).updateUserField(uid, {
          'dailyFocusAction': focusAction,
          'dailyFocusActionDate': _todayStr,
          'dailyFocusActionCompleted': false,
          'priorityActions': _actions,
          'priorityActionsDate': _todayStr,
        });
      }
      await ref.read(dailyCompletionProvider.notifier).toggle('priorityActionsCompleted', true);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.errorGeneric)),
        );
        setState(() => _isCommitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Handle ───────────────────────────────────────────────
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: AppSpacing.md),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // ── Header ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenPaddingH,
                AppSpacing.lg,
                AppSpacing.screenPaddingH,
                AppSpacing.xs,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Plan Your Day', style: AppTextStyles.headlineMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Select your #1 focus, or add your own.',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // ── Scrollable content area ───────────────────────────────
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.55,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Manual add row ──────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.screenPaddingH),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _customCtrl,
                              style: AppTextStyles.bodyMedium,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _addCustomAction(),
                              decoration: InputDecoration(
                                hintText: 'Add your own action…',
                                hintStyle: AppTextStyles.bodyMedium.copyWith(
                                    color: AppColors.textMuted),
                                filled: true,
                                fillColor: AppColors.surfaceElevated,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md,
                                  vertical: AppSpacing.sm + 2,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                      AppSpacing.radiusMd),
                                  borderSide:
                                      const BorderSide(color: AppColors.border),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                      AppSpacing.radiusMd),
                                  borderSide:
                                      const BorderSide(color: AppColors.border),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                      AppSpacing.radiusMd),
                                  borderSide: const BorderSide(
                                      color: AppColors.primary, width: 1.5),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          _AddButton(onTap: _addCustomAction),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // ── AI suggestions label ────────────────────────
                    if (!_isLoading)
                      Padding(
                        padding: const EdgeInsets.only(
                          left: AppSpacing.screenPaddingH,
                          bottom: AppSpacing.sm,
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.auto_awesome_rounded,
                                size: 14, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Text(
                              'SUGGESTIONS',
                              style: AppTextStyles.overline
                                  .copyWith(color: AppColors.primary),
                            ),
                          ],
                        ),
                      ),

                    // ── Action list ─────────────────────────────────
                    if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                        child: Center(
                          child: Column(
                            children: [
                              CircularProgressIndicator(
                                  color: AppColors.primary),
                              SizedBox(height: AppSpacing.md),
                              Text('Generating your focus actions…'),
                            ],
                          ),
                        ),
                      )
                    else if (_actions.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.screenPaddingH),
                        child: Text(
                          'Add an action above or try generating again.',
                          style: AppTextStyles.bodyMedium
                              .copyWith(color: AppColors.textSecondary),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.screenPaddingH),
                        itemCount: _actions.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (_, i) {
                          final isSelected = _selectedIndex == i;
                          return _ActionRow(
                            action: _actions[i],
                            index: i,
                            isSelected: isSelected,
                            onSelect: () =>
                                setState(() => _selectedIndex = i),
                            onRemove: () => _removeAction(i),
                          ).animate().fadeIn(
                                delay: Duration(milliseconds: i * 60),
                                duration: 280.ms,
                              );
                        },
                      ),

                    const SizedBox(height: AppSpacing.md),
                  ],
                ),
              ),
            ),

            // ── Footer ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenPaddingH,
                AppSpacing.sm,
                AppSpacing.screenPaddingH,
                AppSpacing.lg,
              ),
              child: Column(
                children: [
                  AppPrimaryButton(
                    label: 'Commit to this Focus',
                    onPressed: (_selectedIndex != null && !_isCommitting)
                        ? _commit
                        : null,
                    isLoading: _isCommitting,
                    icon: Icons.my_location_rounded,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      "I'll Decide Later",
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textMuted),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Action row ────────────────────────────────────────────────────────────────

class _ActionRow extends StatelessWidget {
  final String action;
  final int index;
  final bool isSelected;
  final VoidCallback onSelect;
  final VoidCallback onRemove;

  const _ActionRow({
    required this.action,
    required this.index,
    required this.isSelected,
    required this.onSelect,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSelect,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryContainer
              : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Radio indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              margin: const EdgeInsets.only(top: 1),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.border,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded,
                      size: 13, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: AppSpacing.md),

            // Action text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (index == 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(
                        'TOP PRIORITY',
                        style: AppTextStyles.overline
                            .copyWith(color: AppColors.primary),
                      ),
                    ),
                  Text(
                    action,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color:
                          isSelected ? AppColors.primary : AppColors.textPrimary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            // Delete button
            GestureDetector(
              onTap: onRemove,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(left: AppSpacing.sm),
                child: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.5)
                      : AppColors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Add button ────────────────────────────────────────────────────────────────

class _AddButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AddButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
      ),
    );
  }
}
