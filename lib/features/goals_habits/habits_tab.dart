import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/habit_library.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/shimmer_widget.dart';
import '../../models/habit.dart';
import '../../providers/habits_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/claude_provider.dart';
import '../../providers/future_self_provider.dart';
import 'widgets/actions_tab_skeleton.dart';
import 'widgets/sheet_handle.dart';

/// Reusable opener for the add-habit form so it can be launched from anywhere
/// (e.g. a coach chat action pill), optionally prefilled with [initialName].
class HabitFormModal {
  static void show(BuildContext context, WidgetRef ref, {String? initialName}) {
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
        child: _HabitFormSheet(initialName: initialName),
      ),
    );
  }
}

class HabitsTab extends ConsumerWidget {
  const HabitsTab({super.key});

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
        return const _HabitsContent();
      },
    );
  }
}

class _HabitsContent extends ConsumerWidget {
  const _HabitsContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habits = ref.watch(habitsProvider);

    if (habits.isEmpty) {
      return _HabitsEmptyState(
        onBrowse: () => _showLibrary(context, ref),
        onGenerate: () => _showAISuggestions(context, ref),
        onWrite: () => HabitFormModal.show(context, ref),
      );
    }

    return ListView(
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
        const SizedBox(height: AppSpacing.md),
        ...habits.asMap().entries.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _HabitCard(
                  habit: e.value,
                  onComplete: () async {
                    await ref
                        .read(habitsProvider.notifier)
                        .completeHabit(e.value.id);
                  },
                  onToggleState: (newState) async {
                    await ref
                        .read(habitsProvider.notifier)
                        .toggleState(e.value.id, newState);
                  },
                  onDelete: () async {
                    await ref
                        .read(habitsProvider.notifier)
                        .deleteHabit(e.value.id);
                  },
                ).animate().fadeIn(
                      delay: Duration(milliseconds: e.key * 60),
                      duration: 400.ms,
                    ),
              ),
            ),
      ],
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

  void _showLibrary(BuildContext context, WidgetRef ref) {
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
        child: const _HabitLibrarySheet(),
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
                if (habit.trigger.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      children: [
                        const Icon(Icons.bolt_rounded,
                            color: AppColors.textMuted, size: 12),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            '${AppStrings.habitWhenPrefix} ${habit.trigger}',
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (habit.identityReinforces.isNotEmpty)
                  Text(
                    habit.identityReinforces,
                    style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.primary, fontStyle: FontStyle.italic),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.local_fire_department_rounded, color: AppColors.warning, size: 12),
                    const SizedBox(width: 2),
                    Text(
                      '${habit.currentStreak} ${AppStrings.streakDays}',
                      style: AppTextStyles.labelSmall.copyWith(color: AppColors.warning),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 2,
                      ),
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
                  isActive ? AppStrings.habitPause : AppStrings.habitResume,
                  style: AppTextStyles.bodyMedium,
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Text(
                  AppStrings.habitDelete,
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
  final String? initialName;

  const _HabitFormSheet({this.initialName});

  @override
  ConsumerState<_HabitFormSheet> createState() => _HabitFormSheetState();
}

class _HabitFormSheetState extends ConsumerState<_HabitFormSheet> {
  late final TextEditingController _nameCtrl;
  final _triggerCtrl = TextEditingController();
  final _identityCtrl = TextEditingController();
  String _frequency = 'daily';
  bool _isSaving = false;
  bool _hasFutureSelf = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName ?? '');
    // Prefill the identity so the habit ties to who the user is becoming. When
    // a Future Self practice exists, anchor it to that future self (today's
    // rotating trait, else the identity anchor); otherwise fall back to the
    // user's identity statement.
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
                Text(AppStrings.addHabit, style: AppTextStyles.headlineMedium),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            _HabitGuidanceCard(
              title: _hasFutureSelf
                  ? AppStrings.habitGuidanceFutureSelfTitle
                  : AppStrings.habitGuidanceTitle,
              body: _hasFutureSelf
                  ? AppStrings.habitGuidanceFutureSelfBody
                  : AppStrings.habitGuidanceBody,
            ),
            const SizedBox(height: AppSpacing.lg),
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
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
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
    // Dedupe against habits the user already has (case-insensitive by name).
    final existing = ref
        .watch(habitsProvider)
        .map((h) => h.name.trim().toLowerCase())
        .toSet();
    final items = kHabitLibrary[_area] ?? const [];

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (_, scrollCtrl) => Column(
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
          // Area selector
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
                        horizontal: AppSpacing.md, vertical: AppSpacing.xs),
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
                final added = existing.contains(t.name.trim().toLowerCase());
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
      ),
    );
  }
}
