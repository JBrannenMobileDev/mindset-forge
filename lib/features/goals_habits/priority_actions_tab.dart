import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/app_date_utils.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/empty_state.dart';
import '../../providers/auth_provider.dart';
import '../../providers/priority_actions_provider.dart';
import 'widgets/actions_tab_skeleton.dart';

class PriorityActionsTab extends ConsumerWidget {
  const PriorityActionsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);

    return profileAsync.when(
      loading: () => const ActionsTabSkeleton(),
      error: (_, __) => ErrorState(
        message: AppStrings.errorGeneric,
        onRetry: () => ref.invalidate(currentUserProfileProvider),
      ),
      data: (profile) {
        if (profile == null) return const ActionsTabSkeleton();
        return const _PriorityActionsContent();
      },
    );
  }
}

class _PriorityActionsContent extends ConsumerStatefulWidget {
  const _PriorityActionsContent();

  @override
  ConsumerState<_PriorityActionsContent> createState() =>
      _PriorityActionsContentState();
}

class _PriorityActionsContentState
    extends ConsumerState<_PriorityActionsContent> {
  final _addCtrl = TextEditingController();

  @override
  void dispose() {
    _addCtrl.dispose();
    super.dispose();
  }

  void _add() {
    final text = _addCtrl.text.trim();
    if (text.isEmpty) return;
    ref.read(priorityActionsProvider.notifier).addAction(text);
    _addCtrl.clear();
    FocusScope.of(context).unfocus();
  }

  Future<void> _generate() async {
    try {
      await ref.read(priorityActionsProvider.notifier).regenerate();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.errorAI)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(priorityActionsProvider);

    if (!state.isPlanned) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenPaddingH,
          AppSpacing.lg,
          AppSpacing.screenPaddingH,
          100,
        ),
        children: _emptyChildren(state),
      );
    }

    // Planned state: full-height list with a FAB (bottom-right, above the nav)
    // that opens a quick-add sheet. The list reserves enough bottom padding for
    // the last item to clear the FAB.
    //
    // The nav shell uses `extendBody: true`, which inflates the in-body
    // `MediaQuery.padding.bottom` and reduces its `viewPadding.bottom`, so
    // neither is reliable here. Read the true device inset straight from the
    // view and mirror the shell's own bottom rule to sit just above the pill.
    final safeBottom = MediaQueryData.fromView(View.of(context)).padding.bottom;
    final bottomPad =
        safeBottom > 0 ? safeBottom : AppSpacing.bottomNavMargin;
    final pillTop = bottomPad + AppSpacing.bottomNavHeight;
    final fabBottom = pillTop + AppSpacing.sm;
    const fabSize = 56.0;
    return Stack(
      children: [
        ListView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.screenPaddingH,
            AppSpacing.lg,
            AppSpacing.screenPaddingH,
            fabBottom + fabSize + AppSpacing.md,
          ),
          children: _plannedChildren(state),
        ),
        Positioned(
          right: AppSpacing.screenPaddingH,
          bottom: fabBottom,
          child: _AddFab(onTap: _showAddSheet),
        ),
      ],
    );
  }

  Future<void> _showAddSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXl),
        ),
      ),
      builder: (_) => _AddPrioritySheet(
        onSubmit: (text) =>
            ref.read(priorityActionsProvider.notifier).addAction(text),
      ),
    );
  }

  /// Always-visible label so it's clear the list is scoped to today.
  Widget _todayLabel() {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Text(
        'Today · ${AppDateUtils.formatWeekdayLong(DateTime.now())}',
        style: AppTextStyles.overline.copyWith(color: AppColors.textMuted),
      ),
    );
  }

  List<Widget> _emptyChildren(PriorityActionsState state) {
    return [
      _todayLabel(),
      Container(
        width: 64,
        height: 64,
        decoration: const BoxDecoration(
          color: AppColors.primaryContainer,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.flag_rounded,
            color: AppColors.primary, size: 30),
      ),
      const SizedBox(height: AppSpacing.lg),
      Text(AppStrings.priorityActionsEmptyTitle,
          style: AppTextStyles.headlineSmall),
      const SizedBox(height: AppSpacing.sm),
      Text(
        AppStrings.priorityActionsEmptySubtitle,
        style:
            AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
      ),
      const SizedBox(height: AppSpacing.lg),
      _AddPriorityRow(controller: _addCtrl, onAdd: _add),
      const SizedBox(height: AppSpacing.md),
      Row(
        children: [
          const Expanded(
            child: Divider(color: AppColors.border, height: 1),
          ),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Text(
              AppStrings.orLabel,
              style: AppTextStyles.labelSmall
                  .copyWith(color: AppColors.textMuted),
            ),
          ),
          const Expanded(
            child: Divider(color: AppColors.border, height: 1),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.md),
      AppSecondaryButton(
        label: AppStrings.priorityActionsGenerate,
        icon: Icons.auto_awesome_rounded,
        isLoading: state.isGenerating,
        onPressed: _generate,
      ),
    ];
  }

  List<Widget> _plannedChildren(PriorityActionsState state) {
    final hasFocus = state.focusAction.isNotEmpty;
    final focusComplete =
        hasFocus && state.completed.contains(state.focusAction);
    final String hint;
    if (focusComplete) {
      hint = AppStrings.priorityActionsAllDone;
    } else if (hasFocus) {
      hint = AppStrings.priorityActionsFocusSet;
    } else {
      hint = AppStrings.priorityActionsFocusHint;
    }

    return [
      _todayLabel(),
      Text(
        AppStrings.priorityActionsHeader,
        style: AppTextStyles.overline.copyWith(color: AppColors.textMuted),
      ),
      const SizedBox(height: AppSpacing.xs),
      Text(
        hint,
        style: AppTextStyles.bodySmall.copyWith(
          color:
              focusComplete ? AppColors.success : AppColors.textSecondary,
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      ...state.actions.asMap().entries.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _PriorityActionCard(
                action: e.value,
                isCompleted: state.completed.contains(e.value),
                isFocus: e.value == state.focusAction,
                onToggleComplete: () => ref
                    .read(priorityActionsProvider.notifier)
                    .toggleComplete(e.value),
                onSetFocus: () =>
                    ref.read(priorityActionsProvider.notifier).setFocus(e.value),
                onRemove: () => ref
                    .read(priorityActionsProvider.notifier)
                    .removeAction(e.value),
              ).animate().fadeIn(
                    delay: Duration(milliseconds: e.key * 80),
                    duration: 400.ms,
                  ),
            ),
          ),
    ];
  }
}

/// Circular add button that floats above the bottom nav and opens the
/// quick-add sheet.
class _AddFab extends StatelessWidget {
  final VoidCallback onTap;

  const _AddFab({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 56,
        height: 56,
        decoration: const BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryGlow,
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      ),
    );
  }
}

/// Quick-add bottom sheet: a drag handle, an autofocused field, and an Add
/// button. Adds and stays open so the user can add several in a row.
class _AddPrioritySheet extends StatefulWidget {
  final void Function(String text) onSubmit;

  const _AddPrioritySheet({required this.onSubmit});

  @override
  State<_AddPrioritySheet> createState() => _AddPrioritySheetState();
}

class _AddPrioritySheetState extends State<_AddPrioritySheet> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    widget.onSubmit(text);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenPaddingH,
            AppSpacing.md,
            AppSpacing.screenPaddingH,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(AppStrings.priorityActionsEmptyTitle,
                  style: AppTextStyles.headlineSmall),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _ctrl,
                focusNode: _focus,
                autofocus: true,
                style: AppTextStyles.bodyMedium,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  hintText: AppStrings.priorityActionAddHint,
                  hintStyle: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.surfaceElevated,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm + 2,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    borderSide:
                        const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppPrimaryButton(label: AppStrings.add, onPressed: _submit),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddPriorityRow extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onAdd;

  const _AddPriorityRow({required this.controller, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: AppSpacing.md, right: AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x400A0A0F),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              style: AppTextStyles.bodyMedium,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => onAdd(),
              decoration: InputDecoration(
                isDense: true,
                hintText: AppStrings.priorityActionAddHint,
                hintStyle: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textMuted),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: AppSpacing.sm + 2),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          GestureDetector(
            onTap: onAdd,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child:
                  const Icon(Icons.add_rounded, color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    );
  }
}

class _PriorityActionCard extends StatelessWidget {
  final String action;
  final bool isCompleted;
  final bool isFocus;
  final VoidCallback onToggleComplete;
  final VoidCallback onSetFocus;
  final VoidCallback onRemove;

  const _PriorityActionCard({
    required this.action,
    required this.isCompleted,
    required this.isFocus,
    required this.onToggleComplete,
    required this.onSetFocus,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 4,
      ),
      borderRadius: AppSpacing.radiusMd,
      backgroundColor:
          isCompleted ? AppColors.primaryContainer : AppColors.surfaceElevated,
      borderColor: isFocus
          ? AppColors.primary.withValues(alpha: 0.5)
          : (isCompleted
              ? AppColors.primary.withValues(alpha: 0.3)
              : AppColors.border),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Completion circle — primary action, stays prominent on the left.
          GestureDetector(
            onTap: onToggleComplete,
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isCompleted ? AppColors.primary : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isCompleted ? AppColors.primary : AppColors.border,
                  width: 2,
                ),
              ),
              child: isCompleted
                  ? const Icon(Icons.check_rounded,
                      color: Colors.white, size: 14)
                  : null,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              action,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodyMedium.copyWith(
                height: 1.3,
                color:
                    isCompleted ? AppColors.primary : AppColors.textPrimary,
                decoration: isCompleted ? TextDecoration.lineThrough : null,
                decorationColor: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          // Focus toggle — icon-only to keep the row compact.
          GestureDetector(
            onTap: onSetFocus,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xs),
              child: Icon(
                isFocus ? Icons.star_rounded : Icons.star_outline_rounded,
                color: isFocus ? AppColors.primary : AppColors.textMuted,
                size: 20,
              ),
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz_rounded,
                color: AppColors.textMuted, size: 18),
            color: AppColors.surfaceElevated,
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              side: const BorderSide(color: AppColors.border),
            ),
            onSelected: (v) {
              if (v == 'remove') onRemove();
            },
            itemBuilder: (_) => [
              PopupMenuItem<String>(
                value: 'remove',
                child: Row(
                  children: [
                    const Icon(Icons.delete_outline_rounded,
                        color: AppColors.error, size: 18),
                    const SizedBox(width: AppSpacing.sm),
                    Text(AppStrings.delete,
                        style: AppTextStyles.bodyMedium
                            .copyWith(color: AppColors.error)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
