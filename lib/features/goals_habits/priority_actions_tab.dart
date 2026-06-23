import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/app_strings.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../providers/auth_provider.dart';
import '../../providers/claude_provider.dart';
import '../../providers/daily_completion_provider.dart';

final _tabActionsProvider = StateProvider<List<String>>((ref) => []);
final _tabActionsLoadingProvider = StateProvider<bool>((ref) => false);

class PriorityActionsTab extends ConsumerStatefulWidget {
  const PriorityActionsTab({super.key});

  @override
  ConsumerState<PriorityActionsTab> createState() => _PriorityActionsTabState();
}

class _PriorityActionsTabState extends ConsumerState<PriorityActionsTab> {
  final Set<int> _completed = {};

  Future<void> _planDay() async {
    ref.read(_tabActionsLoadingProvider.notifier).state = true;
    try {
      final profile = ref.read(currentUserProfileProvider).valueOrNull;
      if (profile == null) return;
      final actions = await ref.read(claudeServiceProvider).generatePriorityActions(profile);
      ref.read(_tabActionsProvider.notifier).state = actions;
      setState(() => _completed.clear());
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.errorAI)),
        );
      }
    } finally {
      ref.read(_tabActionsLoadingProvider.notifier).state = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final actions = ref.watch(_tabActionsProvider);
    final isLoading = ref.watch(_tabActionsLoadingProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPaddingH,
        AppSpacing.lg,
        AppSpacing.screenPaddingH,
        100,
      ),
      children: [
        Text(
          'Plan your 3 most important actions for today.',
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppPrimaryButton(
          label: AppStrings.planMyDay,
          isLoading: isLoading,
          onPressed: _planDay,
          icon: Icons.auto_awesome_rounded,
        ),
        const SizedBox(height: AppSpacing.xl),
        if (actions.isNotEmpty)
          ...actions.asMap().entries.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _PriorityActionCard(
                number: e.key + 1,
                action: e.value,
                isCompleted: _completed.contains(e.key),
                onToggle: () async {
                  setState(() {
                    if (_completed.contains(e.key)) {
                      _completed.remove(e.key);
                    } else {
                      _completed.add(e.key);
                    }
                  });
                  if (_completed.length == actions.length) {
                    await ref.read(dailyCompletionProvider.notifier).toggle('priorityActionsCompleted', true);
                  }
                },
              ).animate().fadeIn(delay: Duration(milliseconds: e.key * 100), duration: 400.ms),
            ),
          ),
      ],
    );
  }
}

class _PriorityActionCard extends StatelessWidget {
  final int number;
  final String action;
  final bool isCompleted;
  final VoidCallback onToggle;

  const _PriorityActionCard({
    required this.number,
    required this.action,
    required this.isCompleted,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onToggle,
      backgroundColor: isCompleted ? AppColors.primaryContainer : AppColors.surfaceElevated,
      borderColor: isCompleted ? AppColors.primary.withValues(alpha: 0.4) : AppColors.border,
      child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isCompleted ? AppColors.primary : AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isCompleted ? AppColors.primary : AppColors.border,
                ),
              ),
              child: isCompleted
                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                  : Center(
                      child: Text(
                        '$number',
                        style: AppTextStyles.labelLarge.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                action,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: isCompleted ? AppColors.primary : AppColors.textPrimary,
                  decoration: isCompleted ? TextDecoration.lineThrough : null,
                  decorationColor: AppColors.primary,
                ),
              ),
            ),
          ],
      ),
    );
  }
}
