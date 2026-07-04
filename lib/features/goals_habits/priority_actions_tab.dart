import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/app_date_utils.dart';
import '../../core/widgets/adaptive_sheet.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/empty_state.dart';
import '../../providers/auth_provider.dart';
import '../../providers/priority_actions_provider.dart';
import 'actions_layout.dart';
import 'widgets/actions_tab_skeleton.dart';
import 'widgets/sheet_handle.dart';

class PriorityActionsTab extends ConsumerWidget {
  final ActionsLayoutContext layoutContext;

  const PriorityActionsTab({
    super.key,
    this.layoutContext = ActionsLayoutContext.mobileTab,
  });

  static Future<void> showAddSheet(BuildContext context, WidgetRef ref) async {
    await showAdaptiveSheet<void>(
      context: context,
      builder: (_) => _AddPrioritySheet(
        onSubmit: (text) =>
            ref.read(priorityActionsProvider.notifier).addAction(text),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);
    final isMobile = layoutContext == ActionsLayoutContext.mobileTab;

    return profileAsync.when(
      loading: () => ActionsTabSkeleton(layoutContext: layoutContext),
      error: (_, __) => _wrapDesktopEmpty(
        layoutContext,
        ErrorState(
          message: AppStrings.errorGeneric,
          onRetry: () => ref.invalidate(currentUserProfileProvider),
        ),
      ),
      data: (profile) {
        if (profile == null) {
          return ActionsTabSkeleton(layoutContext: layoutContext);
        }
        return _PriorityActionsContent(
          layoutContext: layoutContext,
          showFab: isMobile,
        );
      },
    );
  }

  static Widget _wrapDesktopEmpty(
    ActionsLayoutContext ctx,
    Widget child,
  ) {
    if (ctx == ActionsLayoutContext.mobileTab) return child;
    return Center(child: child);
  }
}

class _PriorityActionsContent extends ConsumerStatefulWidget {
  final ActionsLayoutContext layoutContext;
  final bool showFab;

  const _PriorityActionsContent({
    required this.layoutContext,
    required this.showFab,
  });

  @override
  ConsumerState<_PriorityActionsContent> createState() =>
      _PriorityActionsContentState();
}

class _PriorityActionsContentState
    extends ConsumerState<_PriorityActionsContent> {
  final _addCtrl = TextEditingController();

  ActionsLayoutContext get _ctx => widget.layoutContext;

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

  Future<void> _showAddSheet() async {
    await PriorityActionsTab.showAddSheet(context, ref);
  }

  String get _todayLabel =>
      '${AppStrings.priorityActionsTodayPrefix}${AppDateUtils.formatWeekdayLong(DateTime.now())}';

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(priorityActionsProvider);
    final padding = actionsTabPadding(_ctx);
    final shrinkWrap = actionsTabShrinkWrap(_ctx);
    final physics = actionsTabScrollPhysics(_ctx);

    if (!state.isPlanned) {
      final content = ListView(
        shrinkWrap: shrinkWrap,
        physics: physics,
        padding: padding,
        children: _emptyChildren(state),
      );
      if (_ctx == ActionsLayoutContext.mobileTab) return content;
      return PriorityActionsTab._wrapDesktopEmpty(_ctx, content);
    }

    final focus = state.focusAction;
    final hasFocus = focus.isNotEmpty && state.actions.contains(focus);
    final movable =
        state.actions.where((a) => !hasFocus || a != focus).toList();

    double listBottomPad = padding.bottom;
    if (widget.showFab) {
      final safeBottom =
          MediaQueryData.fromView(View.of(context)).padding.bottom;
      final bottomPad =
          safeBottom > 0 ? safeBottom : AppSpacing.bottomNavMargin;
      final pillTop = bottomPad + AppSpacing.bottomNavHeight;
      final fabBottom = pillTop + AppSpacing.sm;
      const fabSize = 56.0;
      listBottomPad = fabBottom + fabSize + AppSpacing.md;
    }

    final list = ReorderableListView.builder(
      shrinkWrap: shrinkWrap,
      physics: physics,
      buildDefaultDragHandles: false,
      padding: padding.copyWith(bottom: listBottomPad),
      header: _PlannedHeader(state: state, todayLabel: _todayLabel),
      itemCount: movable.length,
      onReorder: (oldIndex, newIndex) {
        if (newIndex > oldIndex) newIndex--;
        ref
            .read(priorityActionsProvider.notifier)
            .reorderActions(oldIndex, newIndex);
      },
      itemBuilder: (context, index) {
        final action = movable[index];
        return Padding(
          key: ValueKey(action),
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: _PriorityActionCard(
            action: action,
            isCompleted: state.completed.contains(action),
            isFocus: false,
            dragIndex: index,
            onToggleComplete: () => ref
                .read(priorityActionsProvider.notifier)
                .toggleComplete(action),
            onSetFocus: () =>
                ref.read(priorityActionsProvider.notifier).setFocus(action),
            onRemove: () =>
                ref.read(priorityActionsProvider.notifier).removeAction(action),
          ),
        );
      },
    );

    if (!widget.showFab) return list;

    final safeBottom = MediaQueryData.fromView(View.of(context)).padding.bottom;
    final bottomPad = safeBottom > 0 ? safeBottom : AppSpacing.bottomNavMargin;
    final pillTop = bottomPad + AppSpacing.bottomNavHeight;
    final fabBottom = pillTop + AppSpacing.sm;

    return Stack(
      children: [
        list,
        Positioned(
          right: AppSpacing.screenPaddingH,
          bottom: fabBottom,
          child: _AddFab(onTap: _showAddSheet),
        ),
      ],
    );
  }

  List<Widget> _emptyChildren(PriorityActionsState state) {
    return [
      Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Text(
          _todayLabel,
          style: AppTextStyles.overline.copyWith(color: AppColors.textMuted),
        ),
      ),
      const EmptyState(
        icon: Icons.flag_rounded,
        title: AppStrings.priorityActionsEmptyTitle,
        subtitle: AppStrings.priorityActionsEmptySubtitle,
      ),
      const SizedBox(height: AppSpacing.lg),
      _AddPriorityRow(controller: _addCtrl, onAdd: _add),
      const SizedBox(height: AppSpacing.md),
      Row(
        children: [
          const Expanded(child: Divider(color: AppColors.border, height: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Text(
              AppStrings.orLabel,
              style: AppTextStyles.labelSmall
                  .copyWith(color: AppColors.textMuted),
            ),
          ),
          const Expanded(child: Divider(color: AppColors.border, height: 1)),
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
}

class _PlannedHeader extends ConsumerWidget {
  final PriorityActionsState state;
  final String todayLabel;

  const _PlannedHeader({required this.state, required this.todayLabel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final focus = state.focusAction;
    final hasFocus = focus.isNotEmpty && state.actions.contains(focus);
    final focusComplete = hasFocus && state.completed.contains(focus);
    final String hint;
    if (focusComplete) {
      hint = AppStrings.priorityActionsAllDone;
    } else if (hasFocus) {
      hint = AppStrings.priorityActionsFocusSet;
    } else {
      hint = AppStrings.priorityActionsFocusHint;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Text(
            todayLabel,
            style: AppTextStyles.overline.copyWith(color: AppColors.textMuted),
          ),
        ),
        Text(
          AppStrings.priorityActionsHeader,
          style: AppTextStyles.overline.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          hint,
          style: AppTextStyles.bodySmall.copyWith(
            color: focusComplete ? AppColors.success : AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (hasFocus)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _PriorityActionCard(
              action: focus,
              isCompleted: focusComplete,
              isFocus: true,
              dragIndex: null,
              onToggleComplete: () => ref
                  .read(priorityActionsProvider.notifier)
                  .toggleComplete(focus),
              onSetFocus: () =>
                  ref.read(priorityActionsProvider.notifier).setFocus(focus),
              onRemove: () =>
                  ref.read(priorityActionsProvider.notifier).removeAction(focus),
            ).animate().fadeIn(duration: 400.ms),
          ),
      ],
    );
  }
}

class _AddFab extends StatelessWidget {
  final VoidCallback onTap;

  const _AddFab({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
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
      ),
    );
  }
}

class _AddPrioritySheet extends StatefulWidget {
  final void Function(String text) onSubmit;

  const _AddPrioritySheet({required this.onSubmit});

  @override
  State<_AddPrioritySheet> createState() => _AddPrioritySheetState();
}

class _AddPrioritySheetState extends State<_AddPrioritySheet> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
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
              const SheetHandle(),
              const SizedBox(height: AppSpacing.lg),
              Text(AppStrings.priorityActionsEmptyTitle,
                  style: AppTextStyles.headlineSmall),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _ctrl,
                hint: AppStrings.priorityActionAddHint,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
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
      padding:
          const EdgeInsets.only(left: AppSpacing.md, right: AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.scrim.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
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
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: onAdd,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add_rounded,
                    color: Colors.white, size: 22),
              ),
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
  final int? dragIndex;
  final VoidCallback onToggleComplete;
  final VoidCallback onSetFocus;
  final VoidCallback onRemove;

  const _PriorityActionCard({
    required this.action,
    required this.isCompleted,
    required this.isFocus,
    this.dragIndex,
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
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
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
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
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
          if (dragIndex != null)
            MouseRegion(
              cursor: SystemMouseCursors.grab,
              child: ReorderableDragStartListener(
                index: dragIndex!,
                child: const Padding(
                  padding: EdgeInsets.only(left: AppSpacing.xs),
                  child: Icon(Icons.drag_indicator_rounded,
                      color: AppColors.textMuted, size: 20),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
