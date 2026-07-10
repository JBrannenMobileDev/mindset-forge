import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/future_self_voices.dart';
import '../../core/widgets/narration_voice_picker.dart';
import '../../models/future_self_setup.dart';
import '../../providers/auth_provider.dart';
import '../../providers/future_self_provider.dart';
import 'widgets/future_self_scene_editor.dart';

/// Lean setup/refine wizard for the Future Self practice. Captures each answer
/// exactly once: the shared identity context (who the future self is, their
/// tone and voice) plus, on first-time setup, the first concrete scene. Both
/// the audio scene and the "talk to your future self" chat are fed from this
/// single capture — the chat derives its daily-life context from the scenes,
/// so nothing is asked twice.
///
/// First-time setup is 3 steps (identity, feel & voice, first scene). Refining
/// the shared config (when scenes already exist) is a clean 2-step prefix
/// (identity, feel & voice); scenes themselves are added/refined from the hub.
class FutureSelfWizard extends ConsumerStatefulWidget {
  const FutureSelfWizard({super.key});

  @override
  ConsumerState<FutureSelfWizard> createState() => _FutureSelfWizardState();
}

class _FutureSelfWizardState extends ConsumerState<FutureSelfWizard> {
  int get _totalSteps => _isFirstTime ? 3 : 2;
  bool _isFirstTime = true;

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

  // Step 1 — identity
  final _identityCtrl = TextEditingController();
  String _timeline = '5 years';
  final _workCtrl = TextEditingController();

  // Step 2 — feel & voice
  String _emotion = '';
  final List<String> _amplifiers = [];
  String _voiceStyle = '';
  final _customVoiceCtrl = TextEditingController();
  String _preferredNarrationVoice = FutureSelfVoices.defaultVoice;

  // Step 3 — first scene (first-time setup only)
  SceneDraft? _sceneDraft;

  @override
  void initState() {
    super.initState();
    final existing = ref.read(futureSelfProvider);
    _isFirstTime = existing == null || existing.scenes.isEmpty;
    if (existing != null) {
      _identityCtrl.text = existing.identityAnchor;
      _timeline = existing.futureTimeline;
      _workCtrl.text = existing.workPurpose;
      _emotion = existing.emotionalTone;
      _amplifiers.addAll(existing.amplifiers);
      _voiceStyle = existing.voiceStyle;
      _customVoiceCtrl.text = existing.customVoice;
      _preferredNarrationVoice = existing.resolvedNarrationVoice;
    }

    // Prefill the identity from the user's existing identity statement so
    // they edit rather than write from a blank field. This is personal, not a
    // generic template.
    if (_identityCtrl.text.trim().isEmpty) {
      final identity =
          ref.read(currentUserProfileProvider).valueOrNull?.identityStatement ??
              '';
      final cleaned = identity
          .replaceFirst(RegExp(r'^\s*I am (someone who\s+)?', caseSensitive: false), '')
          .trim();
      if (cleaned.isNotEmpty) _identityCtrl.text = cleaned;
    }
  }

  @override
  void dispose() {
    _identityCtrl.dispose();
    _workCtrl.dispose();
    _customVoiceCtrl.dispose();
    super.dispose();
  }

  bool get _canAdvance {
    switch (_step) {
      case 0:
        return _identityCtrl.text.trim().isNotEmpty && _timeline.isNotEmpty;
      case 1:
        return _emotion.isNotEmpty &&
            _voiceStyle.isNotEmpty &&
            (_voiceStyle != 'Custom sample' ||
                _customVoiceCtrl.text.trim().isNotEmpty);
      case 2:
        return _sceneDraft?.isValid ?? false;
      default:
        return true;
    }
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
    final notifier = ref.read(futureSelfProvider.notifier);

    if (existing != null &&
        existing.resolvedNarrationVoice != _preferredNarrationVoice) {
      await notifier.updateNarrationVoice(_preferredNarrationVoice);
    }

    final scenesAfterVoice =
        ref.read(futureSelfProvider)?.scenes ?? existing?.scenes ?? const [];

    final setup = FutureSelfSetup(
      identityAnchor: _identityCtrl.text.trim(),
      futureTimeline: _timeline,
      workPurpose: _workCtrl.text.trim(),
      emotionalTone: _emotion,
      amplifiers: _amplifiers,
      voiceStyle: _voiceStyle,
      customVoice: _customVoiceCtrl.text.trim(),
      preferredNarrationVoice: _preferredNarrationVoice,
      // Preserve legacy shared context (daily-life/environment/achieved goals)
      // for back-compat; these are no longer collected here — the chat derives
      // that context from the scene library instead.
      achievedGoalIds: existing?.achievedGoalIds ?? const [],
      customGoals: existing?.customGoals ?? const [],
      dailySnapshot: existing?.dailySnapshot ?? '',
      envLocation: existing?.envLocation ?? '',
      envFeel: existing?.envFeel ?? '',
      scenes: scenesAfterVoice,
      beatsEnabled: existing?.beatsEnabled ?? true,
      binauralHz: existing?.binauralHz ?? 7,
      beatsVolume: existing?.beatsVolume ?? 0.3,
      narrationVolume: existing?.narrationVolume ?? 1.0,
      hasSeenHowTo: existing?.hasSeenHowTo ?? false,
      createdAt: existing?.createdAt ?? DateTime.now(),
    );

    await notifier.saveSetup(setup);

    // First-time setup also generates the first scene (script + narration).
    final draft = _sceneDraft;
    if (_isFirstTime && draft != null && draft.isValid) {
      await notifier.createScene(
        title: draft.title,
        setting: draft.setting,
        people: draft.people,
        beats: draft.beats,
        sensory: draft.sensory,
        goalIds: draft.goalIds,
      );
    }

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_step + 1) / _totalSteps;
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
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
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => FocusScope.of(context).unfocus(),
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
                  padding: const EdgeInsets.fromLTRB(AppSpacing.screenPaddingH,
                      0, AppSpacing.screenPaddingH, AppSpacing.xl),
                  child: _buildStep(),
                ),
              ),
              if (!keyboardOpen) _buildNav(),
            ],
          ),
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
          workCtrl: _workCtrl,
          onTimeline: (t) => setState(() => _timeline = t),
          onChanged: () => setState(() {}),
        );
      case 1:
        return _StepFeelVoice(
          emotions: _emotions,
          selectedEmotion: _emotion,
          onEmotion: (e) => setState(() => _emotion = e),
          amplifierOptions: _amplifierOptions,
          selectedAmplifiers: _amplifiers,
          onToggleAmplifier: _toggleAmplifier,
          voiceOptions: _voiceOptions,
          voiceStyle: _voiceStyle,
          onVoice: (v) => setState(() => _voiceStyle = v),
          customVoiceCtrl: _customVoiceCtrl,
          preferredNarrationVoice: _preferredNarrationVoice,
          onNarrationVoice: (v) => setState(() => _preferredNarrationVoice = v),
          onChanged: () => setState(() {}),
        );
      case 2:
        return _StepScene(
          initial: null,
          onChanged: (d) => setState(() => _sceneDraft = d),
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
              label: isLast
                  ? (_isFirstTime ? 'Create Practice' : 'Save changes')
                  : 'Continue',
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

  const _WarmField({
    required this.controller,
    required this.hint,
    required this.onChanged,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      textCapitalization: TextCapitalization.sentences,
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
  final TextEditingController workCtrl;
  final ValueChanged<String> onTimeline;
  final VoidCallback onChanged;

  const _StepIdentity({
    required this.identityCtrl,
    required this.timeline,
    required this.timelines,
    required this.workCtrl,
    required this.onTimeline,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _WizardHeading('Who are you becoming?',
            'This grounds both your scenes and your future-self conversations.'),
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
        const SizedBox(height: AppSpacing.xl),
        Text('You spend most of your time… (optional)',
            style: AppTextStyles.labelLarge
                .copyWith(color: AppColors.futureSelfAccent)),
        const SizedBox(height: AppSpacing.sm),
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

class _StepFeelVoice extends StatelessWidget {
  final List<String> emotions;
  final String selectedEmotion;
  final ValueChanged<String> onEmotion;
  final List<String> amplifierOptions;
  final List<String> selectedAmplifiers;
  final ValueChanged<String> onToggleAmplifier;
  final List<(String, String)> voiceOptions;
  final String voiceStyle;
  final ValueChanged<String> onVoice;
  final TextEditingController customVoiceCtrl;
  final String preferredNarrationVoice;
  final ValueChanged<String> onNarrationVoice;
  final VoidCallback onChanged;

  const _StepFeelVoice({
    required this.emotions,
    required this.selectedEmotion,
    required this.onEmotion,
    required this.amplifierOptions,
    required this.selectedAmplifiers,
    required this.onToggleAmplifier,
    required this.voiceOptions,
    required this.voiceStyle,
    required this.onVoice,
    required this.customVoiceCtrl,
    required this.preferredNarrationVoice,
    required this.onNarrationVoice,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _WizardHeading('In this future, you mostly feel…',
            'This drives the entire tone of your practice.'),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: emotions
              .map((e) => _SelectChip(
                    label: e,
                    selected: e == selectedEmotion,
                    onTap: () => onEmotion(e),
                  ))
              .toList(),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text('Pick up to 3 traits (optional)',
            style: AppTextStyles.labelLarge
                .copyWith(color: AppColors.futureSelfAccent)),
        const SizedBox(height: AppSpacing.xs),
        Text('These are woven in naturally, not stated outright.',
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textMuted)),
        const SizedBox(height: AppSpacing.sm),
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
        NarrationVoicePicker(
          selectedVoiceId: preferredNarrationVoice,
          onSelected: onNarrationVoice,
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(AppStrings.futureSelfWritingStyleLabel,
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

class _StepScene extends StatelessWidget {
  final FutureSelfScene? initial;
  final ValueChanged<SceneDraft> onChanged;

  const _StepScene({required this.initial, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _WizardHeading(
          'Build your first scene',
          'A vivid moment in your future where your goals are already real. You can add more later.',
        ),
        VisionSceneBuilder(initial: initial, onChanged: onChanged),
      ],
    );
  }
}
