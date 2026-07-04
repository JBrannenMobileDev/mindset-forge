import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/habit_library.dart';
import '../../core/services/confetti_gate.dart';
import '../../core/widgets/adaptive_sheet.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/habit_completion_checkbox.dart';
import '../../core/widgets/shimmer_widget.dart';
import '../../models/habit.dart';
import '../../providers/habits_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/claude_provider.dart';
import '../../providers/future_self_provider.dart';
import '../../providers/notification_provider.dart';
import '../../core/utils/breakpoints.dart';
import 'actions_layout.dart';
import 'widgets/actions_tab_skeleton.dart';
import 'widgets/sheet_handle.dart';

/// Reusable opener for the add/edit-habit form so it can be launched from
/// anywhere (e.g. a coach chat action pill), optionally prefilled with
/// [initialName] for a new habit, or [editHabit] to edit an existing one.
class HabitFormModal {
  static void show(
    BuildContext context,
    WidgetRef ref, {
    String? initialName,
    Habit? editHabit,
  }) {
    showAdaptiveSheet<void>(
      context: context,
      dialogMaxWidth: 560,
      builder: (_) => ProviderScope(
        parent: ProviderScope.containerOf(context),
        child: _HabitFormSheet(initialName: initialName, editHabit: editHabit),
      ),
    );
  }
}

class HabitsTab extends ConsumerWidget {
  final ActionsLayoutContext layoutContext;

  const HabitsTab({
    super.key,
    this.layoutContext = ActionsLayoutContext.mobileTab,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);

    return profileAsync.when(
      loading: () => ActionsTabSkeleton(layoutContext: layoutContext),
      error: (_, __) => _wrapIfDesktop(
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
        return _HabitsContent(layoutContext: layoutContext);
      },
    );
  }

  static Widget _wrapIfDesktop(ActionsLayoutContext ctx, Widget child) {
    if (ctx == ActionsLayoutContext.mobileTab) return child;
    return Center(child: child);
  }
}

class _HabitsContent extends ConsumerStatefulWidget {
  final ActionsLayoutContext layoutContext;

  const _HabitsContent({required this.layoutContext});

  @override
  ConsumerState<_HabitsContent> createState() => _HabitsContentState();
}

class _HabitsContentState extends ConsumerState<_HabitsContent> {
  /// Streak lengths worth celebrating. Crossing one while checking in fires
  /// a single confetti burst (gated app-wide by [ConfettiGate]) plus a toast
  /// naming the habit, so the milestone reads as earned rather than generic.
  static const List<int> _milestones = [7, 30, 100];

  late final ConfettiController _confettiCtrl;
  bool _pausedExpanded = false;

  @override
  void initState() {
    super.initState();
    _confettiCtrl = ConfettiController(duration: const Duration(seconds: 2));
  }

  @override
  void dispose() {
    _confettiCtrl.dispose();
    super.dispose();
  }

  Future<void> _completeHabit(Habit habit) async {
    final before = habit.currentStreak;
    await ref.read(habitsProvider.notifier).completeHabit(habit.id);
    if (!mounted) return;

    final after = ref
        .read(habitsProvider)
        .firstWhere((h) => h.id == habit.id, orElse: () => habit)
        .currentStreak;
    final hit = _milestones.firstWhere(
      (m) => before < m && after >= m,
      orElse: () => -1,
    );
    if (hit == -1) return;

    ConfettiGate.play(_confettiCtrl, const Duration(seconds: 2));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text(AppStrings.habitStreakMilestoneToast(habit.name, hit)),
        backgroundColor: AppColors.surfaceElevated,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final habits = ref.watch(habitsProvider);

    if (habits.isEmpty) {
      return HabitsTab._wrapIfDesktop(
        widget.layoutContext,
        _HabitsEmptyState(
          onBrowse: () => _showLibrary(context, ref),
          onGenerate: () => _showAISuggestions(context, ref),
          onWrite: () => HabitFormModal.show(context, ref),
        ),
      );
    }

    final active = habits.where((h) => h.state == 'active').toList();
    final paused = habits.where((h) => h.state != 'active').toList();
    final padding = actionsTabPadding(widget.layoutContext);
    final shrinkWrap = actionsTabShrinkWrap(widget.layoutContext);

    return Stack(
      children: [
        ReorderableListView.builder(
          shrinkWrap: shrinkWrap,
          physics: actionsTabScrollPhysics(widget.layoutContext),
          buildDefaultDragHandles: false,
          padding: padding,
          header: Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${habits.length} habit${habits.length == 1 ? '' : 's'}',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textSecondary),
                      ),
                    ),
                    AppTextButton(
                      label: AppStrings.browseLibrary,
                      onPressed: () => _showLibrary(context, ref),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    AppTextButton(
                      label: AppStrings.aiSuggestions,
                      onPressed: () => _showAISuggestions(context, ref),
                    ),
                  ],
                ),
                if (active.isNotEmpty && paused.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    AppStrings.habitsActiveSectionTitle,
                    style: AppTextStyles.labelSmall
                        .copyWith(color: AppColors.textMuted),
                  ),
                ],
              ],
            ),
          ),
          itemCount: active.length,
          onReorder: (oldIndex, newIndex) {
            if (newIndex > oldIndex) newIndex--;
            ref.read(habitsProvider.notifier).reorderActive(oldIndex, newIndex);
          },
          itemBuilder: (context, index) {
            final habit = active[index];
            return Padding(
              key: ValueKey(habit.id),
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _HabitCard(
                habit: habit,
                dragIndex: index,
                onComplete: () => _completeHabit(habit),
                onOpenDetail: () => context.push('/actions/habit/${habit.id}'),
              ),
            );
          },
          footer: paused.isEmpty
              ? null
              : _PausedHabitsSection(
                  habits: paused,
                  expanded: _pausedExpanded,
                  onToggleExpanded: () =>
                      setState(() => _pausedExpanded = !_pausedExpanded),
                  onOpenDetail: (h) => context.push('/actions/habit/${h.id}'),
                ),
        ),
        IgnorePointer(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiCtrl,
              blastDirectionality: BlastDirectionality.explosive,
              colors: const [
                AppColors.primary,
                AppColors.secondary,
                AppColors.warning,
              ],
              numberOfParticles: 30,
            ),
          ),
        ),
      ],
    );
  }

  void _showAISuggestions(BuildContext context, WidgetRef ref) {
    showAdaptiveSheet<void>(
      context: context,
      dialogMaxWidth: 560,
      builder: (_) => ProviderScope(
        parent: ProviderScope.containerOf(context),
        child: const _HabitSuggestionsSheet(),
      ),
    );
  }

  void _showLibrary(BuildContext context, WidgetRef ref) {
    showAdaptiveSheet<void>(
      context: context,
      dialogMaxWidth: 640,
      builder: (_) => ProviderScope(
        parent: ProviderScope.containerOf(context),
        child: const _HabitLibrarySheet(),
      ),
    );
  }
}

/// Collapsed-by-default footer listing paused habits below the (reorderable)
/// active list. Paused habits are lower priority day-to-day, so they default
/// to a single summary row the user can expand rather than competing for
/// attention with what's actually active.
class _PausedHabitsSection extends StatelessWidget {
  final List<Habit> habits;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final void Function(Habit) onOpenDetail;

  const _PausedHabitsSection({
    required this.habits,
    required this.expanded,
    required this.onToggleExpanded,
    required this.onOpenDetail,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onToggleExpanded,
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Row(
                children: [
                  AnimatedRotation(
                    turns: expanded ? 0.25 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.chevron_right_rounded,
                        color: AppColors.textMuted, size: 18),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${AppStrings.habitsPausedSectionTitle} (${habits.length})',
                    style: AppTextStyles.labelSmall
                        .copyWith(color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            ...habits.map(
              (h) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _HabitCard(
                  habit: h,
                  onComplete: () {},
                  onOpenDetail: () => onOpenDetail(h),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HabitCard extends StatelessWidget {
  final Habit habit;
  final VoidCallback onComplete;
  final VoidCallback onOpenDetail;
  final int? dragIndex;

  const _HabitCard({
    required this.habit,
    required this.onComplete,
    required this.onOpenDetail,
    this.dragIndex,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = habit.state == 'active';

    return AppCard(
      onTap: onOpenDetail,
      child: Row(
        children: [
          HabitCompletionCheckbox(
            isDone: habit.isCompletedToday,
            enabled: isActive,
            onTap: onComplete,
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
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.local_fire_department_rounded,
                        color: AppColors.warning, size: 12),
                    const SizedBox(width: 2),
                    Text(
                      '${habit.currentStreak} ${AppStrings.streakDays}',
                      style: AppTextStyles.labelSmall
                          .copyWith(color: AppColors.warning),
                    ),
                    if (habit.frequency == 'weekly') ...[
                      const SizedBox(width: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isActive
                              ? AppColors.secondaryContainer
                              : AppColors.surfaceHighest,
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusFull),
                        ),
                        child: Text(
                          habit.frequency,
                          style: AppTextStyles.labelSmall.copyWith(
                            color: isActive
                                ? AppColors.secondary
                                : AppColors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
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

class _HabitFormSheet extends ConsumerStatefulWidget {
  final String? initialName;
  final Habit? editHabit;

  const _HabitFormSheet({this.initialName, this.editHabit});

  @override
  ConsumerState<_HabitFormSheet> createState() => _HabitFormSheetState();
}

class _HabitFormSheetState extends ConsumerState<_HabitFormSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _triggerCtrl;
  late final TextEditingController _identityCtrl;
  late String _frequency;
  late bool _reminderEnabled;
  late int _reminderMinutes;
  bool _isSaving = false;
  bool _hasFutureSelf = false;

  bool get _isEditing => widget.editHabit != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.editHabit;
    _nameCtrl = TextEditingController(text: existing?.name ?? widget.initialName ?? '');
    _triggerCtrl = TextEditingController(text: existing?.trigger ?? '');
    _identityCtrl = TextEditingController(text: existing?.identityReinforces ?? '');
    _frequency = existing?.frequency ?? 'daily';
    _reminderEnabled = existing?.reminderEnabled ?? false;
    _reminderMinutes = existing?.reminderMinutes ?? Habit.defaultReminderMinutes;

    // Editing an existing habit: keep its own saved fields as-is, no
    // re-prefilling from Future Self/identity data.
    if (existing != null) return;

    // New habit: prefill the identity so it ties to who the user is
    // becoming. When a Future Self practice exists, anchor it to that future
    // self (today's rotating trait, else the identity anchor); otherwise
    // fall back to the user's identity statement.
    final profile = ref.read(currentUserProfileProvider).valueOrNull;
    final setup = profile?.futureSelfSetup;
    _hasFutureSelf = setup != null;
    String prefill = profile?.identityStatement ?? '';
    if (setup != null) {
      final trait = ref.read(embodimentTraitTodayProvider);
      if (trait != null && trait.isNotEmpty) {
        prefill = 'I am someone who is $trait';
      } else if (setup.identityAnchor.trim().isNotEmpty) {
        prefill = 'I am someone who ${setup.identityAnchor.trim()}';
      }
    }
    if (prefill.isNotEmpty) _identityCtrl.text = prefill;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _triggerCtrl.dispose();
    _identityCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: _reminderMinutes ~/ 60,
        minute: _reminderMinutes % 60,
      ),
      helpText: AppStrings.habitReminderLabel,
    );
    if (picked == null) return;
    setState(() => _reminderMinutes = picked.hour * 60 + picked.minute);
  }

  String _fmtReminderTime(int minutes) {
    final tod = TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
    final h = tod.hourOfPeriod == 0 ? 12 : tod.hourOfPeriod;
    final m = tod.minute.toString().padLeft(2, '0');
    final period = tod.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $period';
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _isSaving = true);

    try {
      final existing = widget.editHabit;
      final habit = existing != null
          ? existing.copyWith(
              name: _nameCtrl.text.trim(),
              trigger: _triggerCtrl.text.trim(),
              frequency: _frequency,
              identityReinforces: _identityCtrl.text.trim(),
              reminderEnabled: _reminderEnabled,
              reminderMinutes: _reminderMinutes,
            )
          : Habit(
              id: const Uuid().v4(),
              name: _nameCtrl.text.trim(),
              trigger: _triggerCtrl.text.trim(),
              frequency: _frequency,
              identityReinforces: _identityCtrl.text.trim(),
              createdAt: DateTime.now(),
              reminderEnabled: _reminderEnabled,
              reminderMinutes: _reminderMinutes,
            );
      await (existing != null
          ? ref.read(habitsProvider.notifier).updateHabit(habit)
          : ref.read(habitsProvider.notifier).addHabit(habit));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('_HabitFormSheet._save failed: $e');
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
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
                Text(
                  _isEditing ? AppStrings.editHabit : AppStrings.addHabit,
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
            if (!_isEditing) ...[
              _HabitGuidanceCard(
                title: _hasFutureSelf
                    ? AppStrings.habitGuidanceFutureSelfTitle
                    : AppStrings.habitGuidanceTitle,
                body: _hasFutureSelf
                    ? AppStrings.habitGuidanceFutureSelfBody
                    : AppStrings.habitGuidanceBody,
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            // Habit — the tiny routine
            AppTextField(
              label: AppStrings.habitNameLabel,
              hint: AppStrings.habitNameHint,
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: AppSpacing.xs),
            const _FieldHint(AppStrings.habitNameGuidance),
            const SizedBox(height: AppSpacing.md),
            // Cue — habit stacking
            AppTextField(
              label: AppStrings.habitCueLabel,
              hint: AppStrings.habitTriggerHint,
              controller: _triggerCtrl,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.xs),
            const _FieldHint(AppStrings.habitCueGuidance),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: AppStrings.habitCuePresets.map((preset) {
                final sel = _triggerCtrl.text.trim() == preset;
                return GestureDetector(
                  onTap: () => setState(() {
                    _triggerCtrl.text = preset;
                    _triggerCtrl.selection =
                        TextSelection.collapsed(offset: preset.length);
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm + 2, vertical: AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: sel
                          ? AppColors.primary.withValues(alpha: 0.15)
                          : AppColors.surfaceElevated,
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusFull),
                      border: Border.all(
                        color: sel
                            ? AppColors.primary.withValues(alpha: 0.5)
                            : AppColors.border,
                      ),
                    ),
                    child: Text(
                      preset,
                      style: AppTextStyles.labelSmall.copyWith(
                        color:
                            sel ? AppColors.primary : AppColors.textSecondary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.md),
            // Identity — who this makes you
            AppTextField(
              label: AppStrings.habitIdentityLabel,
              hint: AppStrings.habitIdentityHint,
              controller: _identityCtrl,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: AppSpacing.xs),
            const _FieldHint(AppStrings.habitIdentityGuidance),
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
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: Text(AppStrings.habitReminderLabel,
                      style: AppTextStyles.labelMedium),
                ),
                Switch(
                  value: _reminderEnabled,
                  activeTrackColor: AppColors.primary,
                  activeThumbColor: Colors.white,
                  inactiveTrackColor: AppColors.surfaceHighest,
                  inactiveThumbColor: AppColors.textSecondary,
                  onChanged: (v) async {
                    if (v) {
                      await ref
                          .read(notificationServiceProvider)
                          .requestPermission();
                    }
                    if (mounted) setState(() => _reminderEnabled = v);
                  },
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            const _FieldHint(AppStrings.habitReminderGuidance),
            if (_reminderEnabled) ...[
              const SizedBox(height: AppSpacing.sm),
              GestureDetector(
                onTap: _pickReminderTime,
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
                      const Icon(Icons.notifications_outlined,
                          color: AppColors.textMuted, size: 18),
                      const SizedBox(width: AppSpacing.sm),
                      Text(_fmtReminderTime(_reminderMinutes),
                          style: AppTextStyles.bodyLarge),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            AppPrimaryButton(
              label: _isEditing ? AppStrings.saveChanges : AppStrings.addHabit,
              onPressed: _save,
              isLoading: _isSaving,
            ),
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
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final profile = ref.read(currentUserProfileProvider).valueOrNull;
      if (profile == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      final result =
          await ref.read(claudeServiceProvider).generateHabitSuggestions(profile);
      if (!mounted) return;
      setState(() {
        _suggestions = result;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('_HabitSuggestionsSheet._load failed: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
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
              Text(AppStrings.habitSuggestionsTitle, style: AppTextStyles.headlineMedium),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_isLoading)
            const ShimmerList(count: 3, itemHeight: 88)
          else if (_hasError)
            ErrorState(message: AppStrings.errorAI, onRetry: _load)
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
                              Text('${AppStrings.habitWhenPrefix} ${s['trigger']}', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
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
        ],
      ),
    );
  }
}

// ─── Form helpers (guidance card + inline field hint) ─────────────────────────

class _HabitGuidanceCard extends StatelessWidget {
  final String title;
  final String body;

  const _HabitGuidanceCard({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      backgroundColor: AppColors.primaryContainer,
      borderColor: AppColors.primary.withValues(alpha: 0.25),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.tips_and_updates_rounded,
              color: AppColors.primary, size: 18),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppTextStyles.labelMedium
                        .copyWith(color: AppColors.primary)),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldHint extends StatelessWidget {
  final String text;

  const _FieldHint(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
    );
  }
}

// ─── Empty state (cold start: Browse / Generate / Write) ──────────────────────

class _HabitsEmptyState extends StatelessWidget {
  final VoidCallback onBrowse;
  final VoidCallback onGenerate;
  final VoidCallback onWrite;

  const _HabitsEmptyState({
    required this.onBrowse,
    required this.onGenerate,
    required this.onWrite,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              color: AppColors.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.repeat_rounded,
                color: AppColors.primary, size: 36),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            AppStrings.noHabitsYet,
            style: AppTextStyles.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            AppStrings.noHabitsSubtitle,
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          AppPrimaryButton(
            label: AppStrings.browseLibrary,
            onPressed: onBrowse,
            width: 240,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppSecondaryButton(
            label: AppStrings.generateForMe,
            onPressed: onGenerate,
            width: 240,
          ),
          const SizedBox(height: AppSpacing.xs),
          AppTextButton(
            label: AppStrings.writeMyOwn,
            onPressed: onWrite,
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }
}

// ─── Browsable habit library (curated, tap-to-add by area) ────────────────────

class _HabitLibrarySheet extends ConsumerStatefulWidget {
  const _HabitLibrarySheet();

  @override
  ConsumerState<_HabitLibrarySheet> createState() =>
      _HabitLibrarySheetState();
}

class _HabitLibrarySheetState extends ConsumerState<_HabitLibrarySheet> {
  String _area = kHabitLibraryAreas.first;

  void _add(HabitTemplate t) {
    ref.read(habitsProvider.notifier).addHabit(
          Habit(
            id: const Uuid().v4(),
            name: t.name,
            trigger: t.trigger,
            frequency: 'daily',
            identityReinforces: t.identity,
            createdAt: DateTime.now(),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final existing = ref
        .watch(habitsProvider)
        .map((h) => h.name.trim().toLowerCase())
        .toSet();
    final items = kHabitLibrary[_area] ?? const [];

    Widget body(ScrollController scrollCtrl) => Column(
          children: [
            const SizedBox(height: AppSpacing.md),
            const SheetHandle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
              child: Row(
                children: [
                  Expanded(
                    child: Text(AppStrings.habitLibraryTitle,
                        style: AppTextStyles.headlineMedium),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                itemCount: kHabitLibraryAreas.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: AppSpacing.sm),
                itemBuilder: (_, i) {
                  final area = kHabitLibraryAreas[i];
                  final selected = area == _area;
                  return GestureDetector(
                    onTap: () => setState(() => _area = area),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.xs),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primary.withValues(alpha: 0.15)
                            : AppColors.surfaceElevated,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusFull),
                        border: Border.all(
                          color: selected
                              ? AppColors.primary.withValues(alpha: 0.5)
                              : AppColors.border,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        area,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: selected
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: ListView.separated(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xxl),
                itemCount: items.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.md),
                itemBuilder: (_, i) {
                  final t = items[i];
                  final added =
                      existing.contains(t.name.trim().toLowerCase());
                  return AppCard(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t.name, style: AppTextStyles.labelLarge),
                              const SizedBox(height: 2),
                              Text(
                                '${AppStrings.habitWhenPrefix} ${t.trigger}',
                                style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textSecondary),
                              ),
                              Text(
                                t.identity,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.primary,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        added
                            ? const Icon(Icons.check_circle_rounded,
                                color: AppColors.success)
                            : IconButton(
                                icon: const Icon(Icons.add_circle_rounded,
                                    color: AppColors.primary),
                                onPressed: () => _add(t),
                              ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );

    if (Breakpoints.isWide(context)) {
      return SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: body(ScrollController()),
      );
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (_, scrollCtrl) => body(scrollCtrl),
    );
  }
}
