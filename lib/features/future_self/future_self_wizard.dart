import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/app_text_styles.dart';
import '../../models/future_self_setup.dart';
import '../../models/goal.dart';
import '../../providers/auth_provider.dart';
import '../../providers/claude_provider.dart';
import '../../providers/future_self_provider.dart';

/// 6-step setup/refine wizard for the Future Self practice. Framed as a one-time
/// (occasionally refined) setup, NOT a daily regenerate. On finish it generates
/// the embodiment script once and stores it via [futureSelfProvider].
class FutureSelfWizard extends ConsumerStatefulWidget {
  const FutureSelfWizard({super.key});

  @override
  ConsumerState<FutureSelfWizard> createState() => _FutureSelfWizardState();
}

class _FutureSelfWizardState extends ConsumerState<FutureSelfWizard> {
  static const _totalSteps = 6;

  static const _timelines = ['1 year', '3 years', '5 years', '10 years'];
  static const _emotions = [
    'Calm', 'Confident', 'Focused', 'Free', 'Energized',
    'Peaceful', 'Powerful', 'Grounded', 'Certain',
  ];
  static const _amplifierOptions = [
    'Highly disciplined', 'Financially abundant', 'Physically fit',
    'Socially respected', 'Creative / expressive', 'Calm under pressure',
    'High energy', 'Minimalist lifestyle', 'Adventurous',
  ];
  static const _voiceOptions = <(String, String)>[
    ('Direct & simple', '"The day starts. Coffee gets made. Work begins. No rush."'),
    ('Conversational', '"Morning rolls around. I grab coffee, check the schedule."'),
    ('Blunt & matter-of-fact', '"Wake up. Coffee. Work. Done. Repeat."'),
    ('Custom sample', 'Write your own sample so we learn your voice'),
  ];

  int _step = 0;
  bool _generating = false;

  // Step state
  final _identityCtrl = TextEditingController();
  String _timeline = '5 years';
  final Set<String> _achievedGoalIds = {};
  final List<String> _customGoals = [];
  final _customGoalCtrl = TextEditingController();
  final _snapshotCtrl = TextEditingController();
  final _envLocationCtrl = TextEditingController();
  final _envFeelCtrl = TextEditingController();
  final _workCtrl = TextEditingController();
  String _emotion = '';
  final List<String> _amplifiers = [];
  String _voiceStyle = '';
  final _customVoiceCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final existing = ref.read(futureSelfProvider);
    if (existing != null) {
      _identityCtrl.text = existing.identityAnchor;
      _timeline = existing.futureTimeline;
      _achievedGoalIds.addAll(existing.achievedGoalIds);
      _customGoals.addAll(existing.customGoals);
      _snapshotCtrl.text = existing.dailySnapshot;
      _envLocationCtrl.text = existing.envLocation;
      _envFeelCtrl.text = existing.envFeel;
      _workCtrl.text = existing.workPurpose;
      _emotion = existing.emotionalTone;
      _amplifiers.addAll(existing.amplifiers);
      _voiceStyle = existing.voiceStyle;
      _customVoiceCtrl.text = existing.customVoice;
    }
  }

  @override
  void dispose() {
    _identityCtrl.dispose();
    _customGoalCtrl.dispose();
    _snapshotCtrl.dispose();
    _envLocationCtrl.dispose();
    _envFeelCtrl.dispose();
    _workCtrl.dispose();
    _customVoiceCtrl.dispose();
    super.dispose();
  }

  bool get _canAdvance {
    switch (_step) {
      case 0:
        return _identityCtrl.text.trim().isNotEmpty && _timeline.isNotEmpty;
      case 1:
        return true; // goals optional
      case 2:
        return _snapshotCtrl.text.trim().isNotEmpty;
      case 3:
        return _workCtrl.text.trim().isNotEmpty;
      case 4:
        return _emotion.isNotEmpty;
      case 5:
        return _voiceStyle.isNotEmpty &&
            (_voiceStyle != 'Custom sample' ||
                _customVoiceCtrl.text.trim().isNotEmpty);
      default:
        return true;
    }
  }

  void _addCustomGoal() {
    final text = _customGoalCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _customGoals.add(text);
      _customGoalCtrl.clear();
    });
  }

  void _toggleAmplifier(String label) {
    setState(() {
      if (_amplifiers.contains(label)) {
        _amplifiers.remove(label);
      } else if (_amplifiers.length < 3) {
        _amplifiers.add(label);
      }
    });
  }

  Future<void> _finish() async {
    setState(() => _generating = true);
    final existing = ref.read(futureSelfProvider);
    final profile = ref.read(currentUserProfileProvider).valueOrNull;

    var setup = FutureSelfSetup(
      identityAnchor: _identityCtrl.text.trim(),
      futureTimeline: _timeline,
      achievedGoalIds: _achievedGoalIds.toList(),
      customGoals: _customGoals,
      dailySnapshot: _snapshotCtrl.text.trim(),
      envLocation: _envLocationCtrl.text.trim(),
      envFeel: _envFeelCtrl.text.trim(),
      workPurpose: _workCtrl.text.trim(),
      emotionalTone: _emotion,
      amplifiers: _amplifiers,
      voiceStyle: _voiceStyle,
      customVoice: _customVoiceCtrl.text.trim(),
      beatsEnabled: existing?.beatsEnabled ?? true,
      binauralHz: existing?.binauralHz ?? 7,
      createdAt: existing?.createdAt ?? DateTime.now(),
    );

    try {
      if (profile != null) {
        final script = await ref
            .read(claudeServiceProvider)
            .generateFutureSelfScript(setup, profile);
        setup = setup.copyWith(generatedScript: script);
      }
    } catch (_) {
      // saveSetup still proceeds; player can regenerate if script is empty.
    }

    await ref.read(futureSelfProvider.notifier).saveSetup(setup);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_step) / (_totalSteps - 1);
    return Scaffold(
      backgroundColor: AppColors.futureSelfBackground,
      appBar: AppBar(
        backgroundColor: AppColors.futureSelfBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppColors.futureSelfAccent),
          onPressed: _generating ? null : () => Navigator.of(context).pop(),
        ),
        title: Text(
          AppStrings.futureSelfSetupTitle,
          style: AppTextStyles.headlineSmall
              .copyWith(color: AppColors.futureSelfAccent),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screenPaddingH,
                  AppSpacing.sm, AppSpacing.screenPaddingH, AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Step ${_step + 1} of $_totalSteps',
                    style: AppTextStyles.labelSmall,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: AppColors.futureSelfSurface,
                      valueColor: const AlwaysStoppedAnimation(
                          AppColors.futureSelfAccent),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.screenPaddingH, 0,
                    AppSpacing.screenPaddingH, AppSpacing.xl),
                child: _buildStep(),
              ),
            ),
            _buildNav(),
          ],
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return _StepIdentity(
          identityCtrl: _identityCtrl,
          timeline: _timeline,
          timelines: _timelines,
          onTimeline: (t) => setState(() => _timeline = t),
          onChanged: () => setState(() {}),
        );
      case 1:
        return _StepGoals(
          goals: ref
                  .watch(currentUserProfileProvider)
                  .valueOrNull
                  ?.goals
                  .where((g) => g.status == 'active')
                  .toList() ??
              const <Goal>[],
          selectedIds: _achievedGoalIds,
          customGoals: _customGoals,
          customCtrl: _customGoalCtrl,
          onToggle: (id) => setState(() {
            _achievedGoalIds.contains(id)
                ? _achievedGoalIds.remove(id)
                : _achievedGoalIds.add(id);
          }),
          onAddCustom: _addCustomGoal,
          onRemoveCustom: (i) => setState(() => _customGoals.removeAt(i)),
        );
      case 2:
        return _StepSnapshot(
          snapshotCtrl: _snapshotCtrl,
          envLocationCtrl: _envLocationCtrl,
          envFeelCtrl: _envFeelCtrl,
          onChanged: () => setState(() {}),
        );
      case 3:
        return _StepWork(
          workCtrl: _workCtrl,
          onChanged: () => setState(() {}),
        );
      case 4:
        return _StepEmotion(
          emotions: _emotions,
          selected: _emotion,
          onSelect: (e) => setState(() => _emotion = e),
        );
      case 5:
        return _StepAmplifiersVoice(
          amplifierOptions: _amplifierOptions,
          selectedAmplifiers: _amplifiers,
          onToggleAmplifier: _toggleAmplifier,
          voiceOptions: _voiceOptions,
          voiceStyle: _voiceStyle,
          onVoice: (v) => setState(() => _voiceStyle = v),
          customVoiceCtrl: _customVoiceCtrl,
          onChanged: () => setState(() {}),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildNav() {
    final isLast = _step == _totalSteps - 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screenPaddingH,
          AppSpacing.sm, AppSpacing.screenPaddingH, AppSpacing.lg),
      child: Row(
        children: [
          if (_step > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _generating ? null : () => setState(() => _step--),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.border),
                  minimumSize: const Size.fromHeight(AppSpacing.buttonHeight),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                ),
                child: const Text('Back'),
              ),
            ),
          if (_step > 0) const SizedBox(width: AppSpacing.md),
          Expanded(
            flex: 2,
            child: _AccentButton(
              label: isLast ? 'Create Practice' : 'Continue',
              isLoading: _generating,
              onPressed: !_canAdvance || _generating
                  ? null
                  : () {
                      if (isLast) {
                        _finish();
                      } else {
                        setState(() => _step++);
                      }
                    },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Shared field widgets ─────────────────────────────────────────────────────

class _WizardHeading extends StatelessWidget {
  final String title;
  final String? subtitle;

  const _WizardHeading(this.title, [this.subtitle]);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTextStyles.headlineMedium),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(subtitle!,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary)),
        ],
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }
}

class _WarmField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final VoidCallback onChanged;
  final TextCapitalization textCapitalization;

  const _WarmField({
    required this.controller,
    required this.hint,
    required this.onChanged,
    this.maxLines = 1,
    this.textCapitalization = TextCapitalization.sentences,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      textCapitalization: textCapitalization,
      style: AppTextStyles.bodyMedium,
      cursorColor: AppColors.futureSelfAccent,
      onChanged: (_) => onChanged(),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
        filled: true,
        fillColor: AppColors.futureSelfSurface,
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
              const BorderSide(color: AppColors.futureSelfAccent, width: 1.5),
        ),
      ),
    );
  }
}

class _SelectChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;

  const _SelectChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.futureSelfAccent.withValues(alpha: 0.15)
              : AppColors.futureSelfSurface,
          border: Border.all(
            color: selected
                ? AppColors.futureSelfAccent
                : disabled
                    ? AppColors.borderSubtle
                    : AppColors.border,
          ),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelMedium.copyWith(
            color: selected
                ? AppColors.futureSelfAccent
                : disabled
                    ? AppColors.textDisabled
                    : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _AccentButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;

  const _AccentButton({
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSpacing.buttonHeight,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.futureSelfAccent,
          foregroundColor: Colors.black,
          disabledBackgroundColor:
              AppColors.futureSelfAccent.withValues(alpha: 0.4),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.black),
              )
            : Text(label,
                style: AppTextStyles.button.copyWith(color: Colors.black)),
      ),
    );
  }
}

// ─── Steps ────────────────────────────────────────────────────────────────────

class _StepIdentity extends StatelessWidget {
  final TextEditingController identityCtrl;
  final String timeline;
  final List<String> timelines;
  final ValueChanged<String> onTimeline;
  final VoidCallback onChanged;

  const _StepIdentity({
    required this.identityCtrl,
    required this.timeline,
    required this.timelines,
    required this.onTimeline,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _WizardHeading(
            'Who are you in this future?', 'Complete the sentence below'),
        Text('I am someone who…',
            style: AppTextStyles.labelLarge
                .copyWith(color: AppColors.futureSelfAccent)),
        const SizedBox(height: AppSpacing.sm),
        _WarmField(
          controller: identityCtrl,
          hint: 'runs a calm, focused creative business… / is a disciplined '
              'athlete and entrepreneur…',
          maxLines: 3,
          onChanged: onChanged,
        ),
        const SizedBox(height: AppSpacing.xl),
        Text('How far into the future?',
            style: AppTextStyles.labelLarge
                .copyWith(color: AppColors.futureSelfAccent)),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: timelines
              .map((t) => _SelectChip(
                    label: '$t from now',
                    selected: t == timeline,
                    onTap: () => onTimeline(t),
                  ))
              .toList(),
        ),
      ],
    );
  }
}

class _StepGoals extends StatelessWidget {
  final List<Goal> goals;
  final Set<String> selectedIds;
  final List<String> customGoals;
  final TextEditingController customCtrl;
  final ValueChanged<String> onToggle;
  final VoidCallback onAddCustom;
  final ValueChanged<int> onRemoveCustom;

  const _StepGoals({
    required this.goals,
    required this.selectedIds,
    required this.customGoals,
    required this.customCtrl,
    required this.onToggle,
    required this.onAddCustom,
    required this.onRemoveCustom,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _WizardHeading('Which goals have you achieved?',
            'Select what is already done in this future, or skip if none yet'),
        ...goals.map((g) {
          final selected = selectedIds.contains(g.id);
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: GestureDetector(
              onTap: () => onToggle(g.id),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.futureSelfSurface,
                  border: Border.all(
                    color: selected
                        ? AppColors.success
                        : AppColors.border,
                  ),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Row(
                  children: [
                    Icon(
                      selected
                          ? Icons.check_circle_rounded
                          : Icons.circle_outlined,
                      color: selected
                          ? AppColors.success
                          : AppColors.textMuted,
                      size: 20,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                        child: Text(g.title,
                            style: AppTextStyles.bodyMedium)),
                  ],
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: AppSpacing.md),
        Text('Add additional future goals',
            style: AppTextStyles.labelLarge
                .copyWith(color: AppColors.futureSelfAccent)),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _WarmField(
                controller: customCtrl,
                hint: 'e.g. Built a 7-figure business',
                onChanged: () {},
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            IconButton.filled(
              onPressed: onAddCustom,
              style: IconButton.styleFrom(
                backgroundColor: AppColors.futureSelfAccent,
                foregroundColor: Colors.black,
              ),
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        ...customGoals.asMap().entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                children: [
                  Expanded(
                      child: Text(e.value,
                          style: AppTextStyles.bodyMedium
                              .copyWith(color: AppColors.textSecondary))),
                  GestureDetector(
                    onTap: () => onRemoveCustom(e.key),
                    child: const Icon(Icons.close_rounded,
                        size: 18, color: AppColors.textMuted),
                  ),
                ],
              ),
            )),
      ],
    );
  }
}

class _StepSnapshot extends StatelessWidget {
  final TextEditingController snapshotCtrl;
  final TextEditingController envLocationCtrl;
  final TextEditingController envFeelCtrl;
  final VoidCallback onChanged;

  const _StepSnapshot({
    required this.snapshotCtrl,
    required this.envLocationCtrl,
    required this.envFeelCtrl,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _WizardHeading('My ideal day looks like…',
            'Describe a normal day in this future, morning to evening'),
        _WarmField(
          controller: snapshotCtrl,
          hint: 'I wake up in a modern home, work from my laptop in the '
              'morning, meet clients in the afternoon, train at night…',
          maxLines: 4,
          onChanged: onChanged,
        ),
        const SizedBox(height: AppSpacing.xl),
        Text('Your environment (optional)',
            style: AppTextStyles.labelLarge
                .copyWith(color: AppColors.futureSelfAccent)),
        const SizedBox(height: AppSpacing.sm),
        _WarmField(
          controller: envLocationCtrl,
          hint: 'Where do you live?',
          onChanged: onChanged,
        ),
        const SizedBox(height: AppSpacing.sm),
        _WarmField(
          controller: envFeelCtrl,
          hint: 'What does it feel like? (minimal, warm, high-end…)',
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _StepWork extends StatelessWidget {
  final TextEditingController workCtrl;
  final VoidCallback onChanged;

  const _StepWork({required this.workCtrl, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _WizardHeading('What do you spend most of your time doing?',
            'Your main work, purpose, or role in this future'),
        _WarmField(
          controller: workCtrl,
          hint: 'e.g. Building my product and coaching creators… / Training '
              'clients and running a fitness brand…',
          maxLines: 3,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _StepEmotion extends StatelessWidget {
  final List<String> emotions;
  final String selected;
  final ValueChanged<String> onSelect;

  const _StepEmotion({
    required this.emotions,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _WizardHeading('In this future, you mostly feel…',
            'This drives the entire tone of your practice'),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: emotions
              .map((e) => _SelectChip(
                    label: e,
                    selected: e == selected,
                    onTap: () => onSelect(e),
                  ))
              .toList(),
        ),
      ],
    );
  }
}

class _StepAmplifiersVoice extends StatelessWidget {
  final List<String> amplifierOptions;
  final List<String> selectedAmplifiers;
  final ValueChanged<String> onToggleAmplifier;
  final List<(String, String)> voiceOptions;
  final String voiceStyle;
  final ValueChanged<String> onVoice;
  final TextEditingController customVoiceCtrl;
  final VoidCallback onChanged;

  const _StepAmplifiersVoice({
    required this.amplifierOptions,
    required this.selectedAmplifiers,
    required this.onToggleAmplifier,
    required this.voiceOptions,
    required this.voiceStyle,
    required this.onVoice,
    required this.customVoiceCtrl,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _WizardHeading('Pick up to 3 traits (optional)',
            'These are woven in naturally, not stated outright'),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: amplifierOptions.map((a) {
            final selected = selectedAmplifiers.contains(a);
            final maxed = selectedAmplifiers.length >= 3 && !selected;
            return _SelectChip(
              label: a,
              selected: selected,
              disabled: maxed,
              onTap: () => onToggleAmplifier(a),
            );
          }).toList(),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text('How do you naturally talk?',
            style: AppTextStyles.labelLarge
                .copyWith(color: AppColors.futureSelfAccent)),
        const SizedBox(height: AppSpacing.sm),
        ...voiceOptions.map((v) {
          final selected = v.$1 == voiceStyle;
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: GestureDetector(
              onTap: () => onVoice(v.$1),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.futureSelfSurface,
                  border: Border.all(
                    color: selected
                        ? AppColors.futureSelfAccent
                        : AppColors.border,
                  ),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(v.$1,
                        style: AppTextStyles.labelLarge.copyWith(
                          color: selected
                              ? AppColors.futureSelfAccent
                              : AppColors.textPrimary,
                        )),
                    const SizedBox(height: 2),
                    Text(v.$2,
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textMuted)),
                  ],
                ),
              ),
            ),
          );
        }),
        if (voiceStyle == 'Custom sample') ...[
          const SizedBox(height: AppSpacing.sm),
          _WarmField(
            controller: customVoiceCtrl,
            hint: 'Write a few sentences about anything so we learn your '
                'natural voice',
            maxLines: 3,
            onChanged: onChanged,
          ),
        ],
      ],
    );
  }
}
