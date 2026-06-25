import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../models/goal.dart';
import '../../../models/mindset_blueprint.dart';
import '../../../providers/claude_provider.dart';

/// 3-part identity wizard:
///   Part 1 — Current situation (single-select)
///   Part 2 — Future self qualities (multi-select, ≥3)
///   Part 3 — Generate / review / edit identity statement
class StepIdentity extends ConsumerStatefulWidget {
  final String initial;
  final MindsetBlueprint blueprint;
  final List<Goal> goals;
  /// Returns the final identity statement plus the raw inputs used to craft it
  /// (resolved situation text and selected future-self qualities) so they can be
  /// persisted and reused to enrich AI personalization.
  final void Function(String statement, String situation, List<String> qualities)
      onNext;
  final VoidCallback onBack;

  const StepIdentity({
    super.key,
    required this.initial,
    required this.blueprint,
    required this.goals,
    required this.onNext,
    required this.onBack,
  });

  @override
  ConsumerState<StepIdentity> createState() => _StepIdentityState();
}

class _StepIdentityState extends ConsumerState<StepIdentity> {
  int _wizardPart = 1; // 1, 2, or 3
  String _situation = '';
  final Set<String> _qualities = {};
  String _identityStatement = '';
  bool _isGenerating = false;
  bool _isEditing = false;
  final _editCtrl = TextEditingController();
  final _customSituationCtrl = TextEditingController();

  static const _situations = [
    _Situation('job', 'Working a job I don\'t love', Icons.work_off_rounded),
    _Situation('business', 'Building my own business', Icons.storefront_rounded),
    _Situation('transition', 'In career transition', Icons.sync_alt_rounded),
    _Situation('stuck', 'Feeling stuck or unmotivated', Icons.pause_circle_rounded),
    _Situation('setback', 'Starting fresh after a setback', Icons.restart_alt_rounded),
    _Situation('other', 'Other', Icons.more_horiz_rounded),
  ];

  static const _qualityOptions = [
    'Confident', 'Disciplined', 'Abundant', 'Focused', 'Healthy',
    'Successful', 'Free', 'Inspiring', 'Resilient', 'Decisive',
    'Generous', 'Peaceful',
  ];

  @override
  void initState() {
    super.initState();
    _identityStatement = widget.initial;
    _editCtrl.text = widget.initial;
    if (widget.initial.isNotEmpty) _wizardPart = 3;
  }

  @override
  void dispose() {
    _editCtrl.dispose();
    _customSituationCtrl.dispose();
    super.dispose();
  }

  /// Human-readable situation, resolving the free-text option to its custom value.
  String get _situationText => _situation == 'other'
      ? _customSituationCtrl.text.trim()
      : _situations
          .firstWhere((s) => s.id == _situation,
              orElse: () => const _Situation('', '', Icons.more_horiz_rounded))
          .label;

  Future<void> _generate() async {
    setState(() {
      _isGenerating = true;
      _isEditing = false;
    });

    try {
      final situationText = _situationText;

      final result = await ref.read(claudeServiceProvider).complete(
        systemPrompt:
            'You write powerful identity statements for mindset coaching. '
            'Write in first person, present tense. One sentence, 15–30 words. '
            'Bold, specific, emotionally resonant. No preamble, no quotes.',
        userPrompt:
            'Write an identity statement for someone who is currently: "$situationText". '
            'They want to become: ${_qualities.join(', ')}. '
            'Their goals: ${widget.goals.take(3).map((g) => g.title).join(', ')}. '
            'Mindset scores: Confidence ${widget.blueprint.confidence}, '
            'Discipline ${widget.blueprint.discipline}, '
            'Abundance ${widget.blueprint.abundanceThinking}.',
        maxTokens: 60,
      );

      if (!mounted) return;
      setState(() {
        _identityStatement = result.trim();
        _editCtrl.text = result.trim();
        _isGenerating = false;
        _wizardPart = 3;
      });
    } catch (_) {
      if (!mounted) return;
      // Fallback: build from qualities
      final fallback =
          'I am a ${_qualities.take(3).join(', ').toLowerCase()} person who takes consistent action toward my most important goals.';
      setState(() {
        _identityStatement = fallback;
        _editCtrl.text = fallback;
        _isGenerating = false;
        _wizardPart = 3;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Progress dots
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenPaddingH,
            vertical: AppSpacing.md,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (i) {
              final active = i + 1 == _wizardPart;
              final done = i + 1 < _wizardPart;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: active ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: done || active ? AppColors.primary : AppColors.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
        ),

        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: switch (_wizardPart) {
              1 => _Part1(
                  key: const ValueKey(1),
                  situations: _situations,
                  selected: _situation,
                  customCtrl: _customSituationCtrl,
                  onSelect: (id) => setState(() => _situation = id),
                  onNext: () => setState(() => _wizardPart = 2),
                  onBack: widget.onBack,
                ),
              2 => _Part2(
                  key: const ValueKey(2),
                  options: _qualityOptions,
                  selected: _qualities,
                  onToggle: (q) => setState(() {
                    if (_qualities.contains(q)) {
                      _qualities.remove(q);
                    } else {
                      _qualities.add(q);
                    }
                  }),
                  onNext: _generate,
                  onBack: () => setState(() => _wizardPart = 1),
                  isGenerating: _isGenerating,
                ),
              _ => _Part3(
                  key: const ValueKey(3),
                  statement: _identityStatement,
                  isEditing: _isEditing,
                  editCtrl: _editCtrl,
                  onEdit: () => setState(() => _isEditing = true),
                  onSaveEdit: () => setState(() {
                    _identityStatement = _editCtrl.text.trim();
                    _isEditing = false;
                  }),
                  onRegenerate: () {
                    setState(() => _wizardPart = 2);
                  },
                  onNext: _identityStatement.trim().length >= 10
                      ? () => widget.onNext(
                            _identityStatement.trim(),
                            _situationText,
                            _qualities.toList(),
                          )
                      : null,
                  onBack: () => setState(() => _wizardPart = 2),
                ),
            },
          ),
        ),
      ],
    );
  }
}

// ─── Part 1: Situation ────────────────────────────────────────────────────────

class _Part1 extends StatelessWidget {
  final List<_Situation> situations;
  final String selected;
  final TextEditingController customCtrl;
  final void Function(String) onSelect;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const _Part1({
    super.key,
    required this.situations,
    required this.selected,
    required this.customCtrl,
    required this.onSelect,
    required this.onNext,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.screenPaddingH),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Where are you right now?', style: AppTextStyles.headlineMedium)
                    .animate().fadeIn(duration: 400.ms),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Be honest. This helps us craft an identity statement that meets you where you are.',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
                const SizedBox(height: AppSpacing.xl),
                ...situations.asMap().entries.map((e) {
                  final s = e.value;
                  final isSelected = selected == s.id;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: GestureDetector(
                      onTap: () => onSelect(s.id),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primaryContainer : AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                          border: Border.all(
                            color: isSelected ? AppColors.primary : AppColors.border,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(s.icon,
                                    color: isSelected ? AppColors.primary : AppColors.textSecondary,
                                    size: 20),
                                const SizedBox(width: AppSpacing.md),
                                Text(
                                  s.label,
                                  style: AppTextStyles.bodyLarge.copyWith(
                                    color: isSelected ? AppColors.primary : AppColors.textPrimary,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                            if (s.id == 'other' && isSelected) ...[
                              const SizedBox(height: AppSpacing.md),
                              TextField(
                                controller: customCtrl,
                                autofocus: true,
                                style: AppTextStyles.bodyMedium,
                                cursorColor: AppColors.primary,
                                decoration: InputDecoration(
                                  hintText: 'Describe your current situation...',
                                  hintStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                                  filled: true,
                                  fillColor: AppColors.background,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                                    borderSide: const BorderSide(color: AppColors.border),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                                    borderSide: const BorderSide(color: AppColors.primary),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                                    borderSide: const BorderSide(color: AppColors.border),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ).animate().fadeIn(delay: Duration(milliseconds: e.key * 60), duration: 300.ms),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        AnimatedOpacity(
          opacity: MediaQuery.of(context).viewInsets.bottom > 0 ? 0.0 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: IgnorePointer(
            ignoring: MediaQuery.of(context).viewInsets.bottom > 0,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.screenPaddingH, AppSpacing.md,
                AppSpacing.screenPaddingH,
                MediaQuery.of(context).padding.bottom + AppSpacing.md,
              ),
              child: Row(
                children: [
                  AppSecondaryButton(label: 'Back', width: 100, onPressed: onBack),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppPrimaryButton(
                      label: 'Continue',
                      onPressed: selected.isNotEmpty ? onNext : null,
                      icon: Icons.arrow_forward_rounded,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Part 2: Qualities ────────────────────────────────────────────────────────

class _Part2 extends StatelessWidget {
  final List<String> options;
  final Set<String> selected;
  final void Function(String) onToggle;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final bool isGenerating;

  const _Part2({
    super.key,
    required this.options,
    required this.selected,
    required this.onToggle,
    required this.onNext,
    required this.onBack,
    required this.isGenerating,
  });

  @override
  Widget build(BuildContext context) {
    final canGenerate = selected.length >= 3;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.screenPaddingH),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Who are you becoming?', style: AppTextStyles.headlineMedium)
                    .animate().fadeIn(duration: 400.ms),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Select 3–5 qualities that describe your future self.',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
                const SizedBox(height: AppSpacing.xl),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: options.asMap().entries.map((e) {
                    final q = e.value;
                    final isSelected = selected.contains(q);
                    return GestureDetector(
                      onTap: () => onToggle(q),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: AppSpacing.md,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primaryContainer : AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                          border: Border.all(
                            color: isSelected ? AppColors.primary : AppColors.border,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isSelected) ...[
                              const Icon(Icons.check_rounded, size: 14, color: AppColors.primary),
                              const SizedBox(width: 4),
                            ],
                            Text(
                              q,
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(
                            delay: Duration(milliseconds: e.key * 40),
                            duration: 300.ms,
                          ),
                    );
                  }).toList(),
                ),
                if (!canGenerate) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Select at least ${3 - selected.length} more',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                  ),
                ],
              ],
            ),
          ),
        ),
        AnimatedOpacity(
          opacity: MediaQuery.of(context).viewInsets.bottom > 0 ? 0.0 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: IgnorePointer(
            ignoring: MediaQuery.of(context).viewInsets.bottom > 0,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.screenPaddingH, AppSpacing.md,
                AppSpacing.screenPaddingH,
                MediaQuery.of(context).padding.bottom + AppSpacing.md,
              ),
              child: Row(
                children: [
                  AppSecondaryButton(label: 'Back', width: 100, onPressed: onBack),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppPrimaryButton(
                      label: isGenerating ? 'Crafting your identity...' : 'Generate My Identity',
                      onPressed: canGenerate && !isGenerating ? onNext : null,
                      isLoading: isGenerating,
                      icon: Icons.auto_awesome_rounded,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Part 3: Review ───────────────────────────────────────────────────────────

class _Part3 extends StatelessWidget {
  final String statement;
  final bool isEditing;
  final TextEditingController editCtrl;
  final VoidCallback onEdit;
  final VoidCallback onSaveEdit;
  final VoidCallback onRegenerate;
  final VoidCallback? onNext;
  final VoidCallback onBack;

  const _Part3({
    super.key,
    required this.statement,
    required this.isEditing,
    required this.editCtrl,
    required this.onEdit,
    required this.onSaveEdit,
    required this.onRegenerate,
    required this.onNext,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.screenPaddingH),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your Identity Statement', style: AppTextStyles.headlineMedium)
                    .animate().fadeIn(duration: 400.ms),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'This is who you are becoming. Read it every day.',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
                const SizedBox(height: AppSpacing.xl),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.12),
                        AppColors.secondary.withValues(alpha: 0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: isEditing
                      ? TextField(
                          controller: editCtrl,
                          autofocus: true,
                          maxLines: null,
                          style: AppTextStyles.headlineSmall.copyWith(height: 1.6),
                          cursorColor: AppColors.primary,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            filled: false,
                          ),
                        )
                      : Text(
                          '"$statement"',
                          style: AppTextStyles.headlineSmall.copyWith(
                            height: 1.6,
                            color: AppColors.textPrimary,
                          ),
                          textAlign: TextAlign.center,
                        ).animate().fadeIn(duration: 600.ms),
                ),

                const SizedBox(height: AppSpacing.lg),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isEditing)
                      AppSecondaryButton(label: 'Save', width: 120, onPressed: onSaveEdit)
                    else ...[
                      AppTextButton(label: 'Edit', onPressed: onEdit),
                      const SizedBox(width: AppSpacing.md),
                      AppTextButton(label: 'Regenerate', onPressed: onRegenerate),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
        AnimatedOpacity(
          opacity: MediaQuery.of(context).viewInsets.bottom > 0 ? 0.0 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: IgnorePointer(
            ignoring: MediaQuery.of(context).viewInsets.bottom > 0,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.screenPaddingH, AppSpacing.md,
                AppSpacing.screenPaddingH,
                MediaQuery.of(context).padding.bottom + AppSpacing.md,
              ),
              child: Row(
                children: [
                  AppSecondaryButton(label: 'Back', width: 100, onPressed: onBack),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppPrimaryButton(
                      label: 'Continue',
                      onPressed: onNext,
                      icon: Icons.arrow_forward_rounded,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Situation {
  final String id;
  final String label;
  final IconData icon;

  const _Situation(this.id, this.label, this.icon);
}
