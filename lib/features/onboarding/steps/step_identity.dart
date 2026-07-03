import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/hoverable.dart';

/// 2-part identity input wizard:
///   Part 1 — Current situation (single-select)
///   Part 2 — Future self qualities (multi-select, >=1)
///
/// This step only *collects* the raw identity inputs. The AI identity statement
/// is generated later as part of the single merged reveal, so there is only one
/// climactic "aha" instead of two AI reveals back to back.
class StepIdentity extends StatefulWidget {
  final String initialSituation;
  final List<String> initialQualities;

  /// Returns the resolved situation text and the selected future-self qualities.
  final void Function(String situation, List<String> qualities) onNext;
  final VoidCallback onBack;

  const StepIdentity({
    super.key,
    this.initialSituation = '',
    this.initialQualities = const [],
    required this.onNext,
    required this.onBack,
  });

  @override
  State<StepIdentity> createState() => _StepIdentityState();
}

class _StepIdentityState extends State<StepIdentity> {
  int _wizardPart = 1; // 1 or 2
  String _situation = '';
  final Set<String> _qualities = {};
  final _customSituationCtrl = TextEditingController();

  static const _situations = [
    _Situation('job', 'Working a job I don\'t love', Icons.work_off_rounded),
    _Situation('business', 'Building my own business', Icons.storefront_rounded),
    _Situation('transition', 'In career transition', Icons.sync_alt_rounded),
    _Situation('health', 'Focused on my health', Icons.favorite_rounded),
    _Situation(
        'relationships', 'Working on my relationships', Icons.people_rounded),
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
    // Hydrate from any previously entered inputs (back-nav / app restore).
    if (widget.initialSituation.isNotEmpty) {
      final match = _situations.firstWhere(
        (s) => s.label == widget.initialSituation,
        orElse: () => const _Situation('', '', Icons.more_horiz_rounded),
      );
      if (match.id.isNotEmpty) {
        _situation = match.id;
      } else {
        _situation = 'other';
        _customSituationCtrl.text = widget.initialSituation;
      }
    }
    _qualities.addAll(widget.initialQualities);
  }

  @override
  void dispose() {
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
            children: List.generate(2, (i) {
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
              _ => _Part2(
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
                  onNext: () =>
                      widget.onNext(_situationText, _qualities.toList()),
                  onBack: () => setState(() => _wizardPart = 1),
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
                    child: Hoverable(
                      onTap: () => onSelect(s.id),
                      builder: (context, hovered) => AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primaryContainer : AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : hovered
                                    ? AppColors.primary.withValues(alpha: 0.5)
                                    : AppColors.border,
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
                                textCapitalization: TextCapitalization.sentences,
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
                      ),
                    ).animate().fadeIn(delay: Duration(milliseconds: e.key * 60), duration: 300.ms),
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

  const _Part2({
    super.key,
    required this.options,
    required this.selected,
    required this.onToggle,
    required this.onNext,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final canContinue = selected.isNotEmpty;
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
                  'Pick the qualities that describe your future self. Choose as many as feel true.',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
                const SizedBox(height: AppSpacing.xl),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: options.asMap().entries.map((e) {
                    final q = e.value;
                    final isSelected = selected.contains(q);
                    return Hoverable(
                      onTap: () => onToggle(q),
                      builder: (context, hovered) => AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: AppSpacing.md,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primaryContainer : AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : hovered
                                    ? AppColors.primary.withValues(alpha: 0.5)
                                    : AppColors.border,
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
                      ),
                    ).animate().fadeIn(
                          delay: Duration(milliseconds: e.key * 40),
                          duration: 300.ms,
                        );
                  }).toList(),
                ),
                if (!canContinue) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Select at least one to continue',
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
                      label: 'Continue',
                      onPressed: canContinue ? onNext : null,
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
