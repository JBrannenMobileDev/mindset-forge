import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/app_strings.dart';
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

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPaddingH,
        AppSpacing.lg,
        AppSpacing.screenPaddingH,
        100,
      ),
      children: state.isPlanned
          ? _plannedChildren(state)
          : _emptyChildren(state),
    );
  }

  List<Widget> _emptyChildren(PriorityActionsState state) {
    return [
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
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
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
      const SizedBox(height: AppSpacing.xs),
      _AddPriorityRow(controller: _addCtrl, onAdd: _add),
    ];
  }
}

class _AddPriorityRow extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onAdd;

  const _AddPriorityRow({required this.controller, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            style: AppTextStyles.bodyMedium,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onAdd(),
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
        ),
        const SizedBox(width: AppSpacing.sm),
        GestureDetector(
          onTap: onAdd,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
          ),
        ),
      ],
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
      backgroundColor:
          isCompleted ? AppColors.primaryContainer : AppColors.surfaceElevated,
      borderColor: isFocus
          ? AppColors.primary.withValues(alpha: 0.5)
          : (isCompleted
              ? AppColors.primary.withValues(alpha: 0.3)
              : AppColors.border),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Completion circle — primary action, stays prominent on the left.
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: GestureDetector(
                onTap: onToggleComplete,
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isCompleted ? AppColors.primary : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color:
                          isCompleted ? AppColors.primary : AppColors.border,
                      width: 2,
                    ),
                  ),
                  child: isCompleted
                      ? const Icon(Icons.check_rounded,
                          color: Colors.white, size: 16)
                      : null,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            // Text-forward column: focus badge → action text → footer controls.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isFocus) ...[
                    _FocusBadge(),
                    const SizedBox(height: AppSpacing.xs),
                  ],
                  Text(
                    action,
                    style: AppTextStyles.bodyLarge.copyWith(
                      height: 1.45,
                      color: isCompleted
                          ? AppColors.primary
                          : AppColors.textPrimary,
                      decoration:
                          isCompleted ? TextDecoration.lineThrough : null,
                      decorationColor: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  // Footer: focus toggle (labelled) + overflow menu.
                  Row(
                    children: [
                      GestureDetector(
                        onTap: onSetFocus,
                        behavior: HitTestBehavior.opaque,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isFocus
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              color: isFocus
                                  ? AppColors.primary
                                  : AppColors.textMuted,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isFocus
                                  ? AppStrings.priorityActionsFocusLabel
                                  : AppStrings.priorityActionsSetFocus,
                              style: AppTextStyles.labelSmall.copyWith(
                                color: isFocus
                                    ? AppColors.primary
                                    : AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_horiz_rounded,
                            color: AppColors.textMuted, size: 18),
                        color: AppColors.surfaceElevated,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusMd),
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Focus badge ──────────────────────────────────────────────────────────────

class _FocusBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm + 2, vertical: AppSpacing.xs - 1),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, color: AppColors.primary, size: 11),
          const SizedBox(width: 3),
          Text(
            AppStrings.priorityActionsFocusLabel,
            style: AppTextStyles.labelSmall.copyWith(color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}
