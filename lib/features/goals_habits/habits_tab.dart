import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/app_strings.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/empty_state.dart';
import '../../models/habit.dart';
import '../../providers/habits_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/claude_provider.dart';

class HabitsTab extends ConsumerWidget {
  const HabitsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habits = ref.watch(habitsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddHabit(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text(AppStrings.addHabit),
      ),
      body: habits.isEmpty
          ? EmptyState(
              icon: Icons.repeat_rounded,
              title: AppStrings.noHabitsYet,
              subtitle: AppStrings.noHabitsSubtitle,
              ctaLabel: AppStrings.addHabit,
              onCta: () => _showAddHabit(context, ref),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenPaddingH,
                AppSpacing.lg,
                AppSpacing.screenPaddingH,
                100,
              ),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${habits.length} habit${habits.length == 1 ? '' : 's'}',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                      ),
                    ),
                    AppTextButton(
                      label: AppStrings.aiSuggestions,
                      onPressed: () => _showAISuggestions(context, ref),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                ...habits.asMap().entries.map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: _HabitCard(
                      habit: e.value,
                      onComplete: () async {
                        await ref.read(habitsProvider.notifier).completeHabit(e.value.id);
                      },
                      onToggleState: (newState) async {
                        await ref.read(habitsProvider.notifier).toggleState(e.value.id, newState);
                      },
                      onDelete: () async {
                        await ref.read(habitsProvider.notifier).deleteHabit(e.value.id);
                      },
                    ).animate().fadeIn(delay: Duration(milliseconds: e.key * 60), duration: 400.ms),
                  ),
                ),
              ],
            ),
    );
  }

  void _showAddHabit(BuildContext context, WidgetRef ref) {
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
        child: const _HabitFormSheet(),
      ),
    );
  }

  void _showAISuggestions(BuildContext context, WidgetRef ref) {
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
        child: const _HabitSuggestionsSheet(),
      ),
    );
  }
}

class _HabitCard extends StatelessWidget {
  final Habit habit;
  final VoidCallback onComplete;
  final void Function(String) onToggleState;
  final VoidCallback onDelete;

  const _HabitCard({
    required this.habit,
    required this.onComplete,
    required this.onToggleState,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = habit.state == 'active';

    return AppCard(
      child: Row(
        children: [
          GestureDetector(
            onTap: habit.isCompletedToday || !isActive ? null : onComplete,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: habit.isCompletedToday ? AppColors.primary : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: habit.isCompletedToday ? AppColors.primary : AppColors.border,
                  width: 2,
                ),
              ),
              child: habit.isCompletedToday
                  ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
                  : null,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  habit.name,
                  style: AppTextStyles.labelLarge.copyWith(
                    color: isActive ? AppColors.textPrimary : AppColors.textMuted,
                  ),
                ),
                if (habit.identityReinforces.isNotEmpty)
                  Text(
                    habit.identityReinforces,
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                Row(
                  children: [
                    const Icon(Icons.local_fire_department_rounded, color: AppColors.warning, size: 12),
                    const SizedBox(width: 2),
                    Text(
                      '${habit.currentStreak} day streak',
                      style: AppTextStyles.labelSmall.copyWith(color: AppColors.warning),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isActive ? AppColors.secondaryContainer : AppColors.surfaceHighest,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                      ),
                      child: Text(
                        habit.frequency,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: isActive ? AppColors.secondary : AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            color: AppColors.surfaceElevated,
            icon: const Icon(Icons.more_vert_rounded, color: AppColors.textMuted),
            onSelected: (value) {
              if (value == 'toggle') {
                onToggleState(isActive ? 'paused' : 'active');
              } else if (value == 'delete') {
                onDelete();
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'toggle',
                child: Text(
                  isActive ? 'Pause' : 'Resume',
                  style: AppTextStyles.bodyMedium,
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Text(
                  'Delete',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HabitFormSheet extends ConsumerStatefulWidget {
  const _HabitFormSheet();

  @override
  ConsumerState<_HabitFormSheet> createState() => _HabitFormSheetState();
}

class _HabitFormSheetState extends ConsumerState<_HabitFormSheet> {
  final _nameCtrl = TextEditingController();
  final _triggerCtrl = TextEditingController();
  final _identityCtrl = TextEditingController();
  String _frequency = 'daily';
  bool _isSaving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _triggerCtrl.dispose();
    _identityCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _isSaving = true);

    try {
      final habit = Habit(
        id: const Uuid().v4(),
        name: _nameCtrl.text.trim(),
        trigger: _triggerCtrl.text.trim(),
        frequency: _frequency,
        identityReinforces: _identityCtrl.text.trim(),
        createdAt: DateTime.now(),
      );
      await ref.read(habitsProvider.notifier).addHabit(habit);
      if (mounted) Navigator.pop(context);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(AppStrings.addHabit, style: AppTextStyles.headlineMedium),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              label: AppStrings.habitName,
              hint: 'e.g., Morning meditation',
              controller: _nameCtrl,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: AppStrings.habitTrigger,
              hint: 'e.g., After I wake up',
              controller: _triggerCtrl,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: AppStrings.habitIdentityReinforces,
              hint: 'e.g., I am a disciplined person',
              controller: _identityCtrl,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(AppStrings.habitFrequency, style: AppTextStyles.labelMedium),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: ['daily', 'weekly'].map((f) {
                final sel = f == _frequency;
                return Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: GestureDetector(
                    onTap: () => setState(() => _frequency = f),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: sel ? AppColors.primaryContainer : AppColors.surfaceElevated,
                        border: Border.all(color: sel ? AppColors.primary : AppColors.border),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                      ),
                      child: Text(
                        f[0].toUpperCase() + f.substring(1),
                        style: AppTextStyles.labelMedium.copyWith(
                          color: sel ? AppColors.primary : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppPrimaryButton(label: AppStrings.addHabit, onPressed: _save, isLoading: _isSaving),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}

class _HabitSuggestionsSheet extends ConsumerStatefulWidget {
  const _HabitSuggestionsSheet();

  @override
  ConsumerState<_HabitSuggestionsSheet> createState() => _HabitSuggestionsSheetState();
}

class _HabitSuggestionsSheetState extends ConsumerState<_HabitSuggestionsSheet> {
  List<Map<String, String>> _suggestions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final profile = ref.read(currentUserProfileProvider).valueOrNull;
      if (profile == null) return;
      final result = await ref.read(claudeServiceProvider).generateHabitSuggestions(profile);
      if (!mounted) return;
      setState(() {
        _suggestions = result;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addSuggestion(Map<String, String> s) async {
    final habit = Habit(
      id: const Uuid().v4(),
      name: s['name'] ?? '',
      trigger: s['trigger'] ?? '',
      identityReinforces: s['identityReinforces'] ?? '',
      createdAt: DateTime.now(),
    );
    await ref.read(habitsProvider.notifier).addHabit(habit);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Habit Suggestions', style: AppTextStyles.headlineMedium),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_isLoading)
            const Center(child: CircularProgressIndicator(color: AppColors.primary))
          else
            ..._suggestions.map(
              (s) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: AppCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s['name'] ?? '', style: AppTextStyles.labelLarge),
                            if ((s['trigger'] ?? '').isNotEmpty)
                              Text('When: ${s['trigger']}', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                            if ((s['identityReinforces'] ?? '').isNotEmpty)
                              Text(s['identityReinforces']!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary, fontStyle: FontStyle.italic)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_rounded, color: AppColors.primary),
                        onPressed: () => _addSuggestion(s),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}
