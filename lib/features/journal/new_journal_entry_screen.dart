import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/app_strings.dart';
import '../../core/widgets/app_button.dart';
import '../../core/utils/app_date_utils.dart';
import '../../models/journal_entry.dart';
import '../../models/journal_summary.dart';
import '../../models/user_profile.dart';
import '../../providers/auth_provider.dart';
import '../../providers/claude_provider.dart';
import '../../providers/journal_provider.dart';
import '../../providers/daily_completion_provider.dart';
import '../../providers/partner_limits_provider.dart';

class NewJournalEntryScreen extends ConsumerStatefulWidget {
  const NewJournalEntryScreen({super.key});

  @override
  ConsumerState<NewJournalEntryScreen> createState() =>
      _NewJournalEntryScreenState();
}

class _NewJournalEntryScreenState extends ConsumerState<NewJournalEntryScreen> {
  int _step = 0; // 0=mode, 1=mood, 2=prompt+write, 3=tags
  String _mode = '';
  String _mood = '';
  String _prompt = '';
  final List<String> _beliefsShifted = [];
  final List<String> _fearsOutwitted = [];
  bool _isGeneratingPrompt = false;
  bool _isFreeWrite = false;
  bool _isSaving = false;
  bool _isSaved = false;
  final _contentCtrl = TextEditingController();

  static const _modes = [
    _ModeItem('reflect', 'Reflect', 'Process your thoughts and emotions', Icons.nightlight_round, AppColors.secondary),
    _ModeItem('grow', 'Grow', 'Extract lessons and forward momentum', Icons.eco_rounded, AppColors.categoryHealth),
    _ModeItem('prime', 'Prime', 'Prime your mind for peak performance', Icons.wb_sunny_rounded, AppColors.warning),
  ];

  static const _moods = [
    _MoodItem('amazing', '🤩', 'Amazing'),
    _MoodItem('good', '😊', 'Good'),
    _MoodItem('okay', '😐', 'Okay'),
    _MoodItem('struggling', '😟', 'Struggling'),
    _MoodItem('low', '😔', 'Low'),
  ];

  @override
  void dispose() {
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _generatePrompt() async {
    setState(() {
      _isGeneratingPrompt = true;
      _step = 2;
      // Keep _isFreeWrite as-is during generation so the writing step can
      // show an inline spinner instead of a full-screen one when the user
      // requested a prompt from the escape hatch mid-entry.
    });
    try {
      final profile = ref.read(currentUserProfileProvider).valueOrNull;
      if (profile == null) return;

      final result = await ref.read(claudeServiceProvider).generateJournalPrompt(
            _mode,
            _mood,
            profile,
          );

      if (!mounted) return;
      setState(() {
        _prompt = result;
        _isGeneratingPrompt = false;
        _isFreeWrite = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _prompt = 'What is on your mind today? Write freely.';
        _isGeneratingPrompt = false;
        _isFreeWrite = false;
      });
    }
  }

  Future<void> _save() async {
    if (_contentCtrl.text.trim().isEmpty) return;

    // Free partner accounts get a limited number of journal entries per week.
    final allowed = await ref
        .read(partnerLimitsProvider)
        .tryConsume(context, PartnerFeature.journal);
    if (!allowed || !mounted) return;

    setState(() => _isSaving = true);

    try {
      final uid = ref.read(authStateProvider).valueOrNull?.uid ?? '';
      final entry = JournalEntry(
        id: const Uuid().v4(),
        uid: uid,
        mode: _mode,
        mood: _mood,
        prompt: _prompt,
        content: _contentCtrl.text.trim(),
        limitingBeliefsShifted: _beliefsShifted,
        fearsOutwitted: _fearsOutwitted,
        createdAt: DateTime.now(),
      );

      await ref.read(journalProvider.notifier).saveEntry(entry);
      await ref.read(dailyCompletionProvider.notifier).toggle('journalCompleted', true);

      // Cache a lightweight summary on UserProfile so AI context stays fresh
      // without requiring an extra Firestore read on every call.
      final profile = ref.read(currentUserProfileProvider).valueOrNull;
      if (profile != null) {
        final content = _contentCtrl.text.trim();
        final newSummary = JournalSummary(
          date: AppDateUtils.todayString(),
          mood: _mood,
          mode: _mode,
          snippet: content.length > 100 ? content.substring(0, 100) : content,
          prompt: _prompt,
        );
        final updated = [newSummary, ...profile.recentJournalSummaries]
            .take(14)
            .toList();
        await ref.read(firestoreServiceProvider).updateUserField(uid, {
          'recentJournalSummaries': updated.map((s) => s.toJson()).toList(),
        });
      }

      if (mounted) setState(() => _isSaved = true);
    } catch (_) {
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/dashboard');
            }
          },
        ),
        title: Text(
          _step == 0
              ? 'New Entry'
              : _step == 1
                  ? 'How are you feeling?'
                  : _step == 10
                      ? 'New Entry'
                      : _step == 2
                          ? 'Write'
                          : _isSaved
                              ? 'Entry Saved'
                              : 'Wrap Up',
          style: AppTextStyles.headlineSmall,
        ),
      ),
      body: SafeArea(
        child: switch (_step) {
          0 => _ModeSelector(
              modes: _modes,
              onSelect: (mode) {
                setState(() {
                  _mode = mode;
                  _step = 1;
                });
              },
            ),
          1 => _MoodSelector(
              moods: _moods,
              onSelect: (mood) {
                setState(() => _mood = mood);
                // Prime always gets a coach prompt — that IS the priming mechanism.
                // Reflect and Grow give the user a choice.
                if (_mode == 'prime') {
                  _generatePrompt();
                } else {
                  setState(() => _step = 10);
                }
              },
            ),
          10 => _PromptChoiceStep(
              onCoachPrompt: _generatePrompt,
              onFreeWrite: () => setState(() {
                _isFreeWrite = true;
                _step = 2;
              }),
            ),
          2 => _WritingStep(
              prompt: _prompt,
              isGenerating: _isGeneratingPrompt,
              isFreeWrite: _isFreeWrite,
              controller: _contentCtrl,
              onChanged: (_) => setState(() {}),
              onNext: () => setState(() => _step = 3),
              onGetCoachPrompt: _generatePrompt,
            ),
          _ => _TagsStep(
              profile: ref.watch(currentUserProfileProvider).valueOrNull,
              selectedBeliefs: _beliefsShifted,
              selectedFears: _fearsOutwitted,
              mode: _mode,
              prompt: _prompt,
              content: _contentCtrl.text.trim(),
              isSaving: _isSaving,
              isSaved: _isSaved,
              onToggleBelief: (belief) {
                setState(() {
                  if (_beliefsShifted.contains(belief)) {
                    _beliefsShifted.remove(belief);
                  } else {
                    _beliefsShifted.add(belief);
                  }
                });
              },
              onToggleFear: (fear) {
                setState(() {
                  if (_fearsOutwitted.contains(fear)) {
                    _fearsOutwitted.remove(fear);
                  } else {
                    _fearsOutwitted.add(fear);
                  }
                });
              },
              onSave: _save,
              onDone: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/dashboard');
                }
              },
              onDiscuss: (content, prompt) => context.go('/chat',
                  extra: {'journalContext': content, 'journalPrompt': prompt}),
            ),
        },
      ),
    );
  }
}

class _ModeSelector extends StatelessWidget {
  final List<_ModeItem> modes;
  final void Function(String) onSelect;

  const _ModeSelector({required this.modes, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.screenPaddingH),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Choose your journal mode', style: AppTextStyles.headlineMedium),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: modes.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: GestureDetector(
                  onTap: () => onSelect(e.value.value),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: e.value.color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                          ),
                          child: Icon(e.value.icon, color: e.value.color, size: 28),
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(e.value.label, style: AppTextStyles.headlineSmall),
                              Text(
                                e.value.description,
                                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                      ],
                    ),
                  ),
                ).animate().fadeIn(delay: Duration(milliseconds: e.key * 100), duration: 400.ms),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _MoodSelector extends StatelessWidget {
  final List<_MoodItem> moods;
  final void Function(String) onSelect;

  const _MoodSelector({required this.moods, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.screenPaddingH),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How are you feeling right now?', style: AppTextStyles.headlineMedium),
          const SizedBox(height: AppSpacing.xl),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: moods.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: GestureDetector(
                  onTap: () => onSelect(e.value.value),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Text(e.value.emoji, style: const TextStyle(fontSize: 28)),
                        const SizedBox(width: AppSpacing.md),
                        Text(e.value.label, style: AppTextStyles.bodyLarge),
                        const Spacer(),
                        const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                      ],
                    ),
                  ),
                ).animate().fadeIn(delay: Duration(milliseconds: e.key * 60), duration: 300.ms),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _PromptChoiceStep extends StatelessWidget {
  final VoidCallback onCoachPrompt;
  final VoidCallback onFreeWrite;

  const _PromptChoiceStep({
    required this.onCoachPrompt,
    required this.onFreeWrite,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.screenPaddingH),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How do you want to write?', style: AppTextStyles.headlineMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Your coach can spark you with a question, or you can go straight to the blank page.',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
          ),
          const Spacer(),
          _buildTile(
            icon: Icons.auto_awesome_rounded,
            color: AppColors.primary,
            title: 'Coach Prompt',
            subtitle: 'Personalized to your goals & mood',
            onTap: onCoachPrompt,
            animationDelay: 0,
          ),
          const SizedBox(height: AppSpacing.md),
          _buildTile(
            icon: Icons.edit_note_rounded,
            color: AppColors.secondary,
            title: 'Free Write',
            subtitle: 'Blank page, your words',
            onTap: onFreeWrite,
            animationDelay: 80,
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required int animationDelay,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.headlineSmall),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(delay: Duration(milliseconds: animationDelay), duration: 400.ms)
        .slideY(begin: 0.15, duration: 400.ms, curve: Curves.easeOut);
  }
}

class _WritingStep extends StatefulWidget {
  final String prompt;
  final bool isGenerating;
  final bool isFreeWrite;
  final TextEditingController controller;
  final void Function(String) onChanged;
  final VoidCallback onNext;
  final VoidCallback onGetCoachPrompt;

  const _WritingStep({
    required this.prompt,
    required this.isGenerating,
    required this.isFreeWrite,
    required this.controller,
    required this.onChanged,
    required this.onNext,
    required this.onGetCoachPrompt,
  });

  @override
  State<_WritingStep> createState() => _WritingStepState();
}

class _WritingStepState extends State<_WritingStep> {
  @override
  Widget build(BuildContext context) {
    final keyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
    final screenHeight = MediaQuery.of(context).size.height;

    // Full-screen spinner only for the initial coach-prompt load (not free-write
    // escape hatch, where we keep the writing area visible).
    if (widget.isGenerating && !widget.isFreeWrite) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: AppSpacing.md),
            Text(
              'Crafting your personalized prompt...',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.screenPaddingH),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.prompt.isNotEmpty)
                  _CollapsiblePromptCard(prompt: widget.prompt)
                      .animate()
                      .fadeIn(duration: 500.ms)
                else if (widget.isFreeWrite)
                  // Escape hatch: inline spinner while fetching, button when idle
                  widget.isGenerating
                      ? Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.sm),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                'Getting your coach prompt...',
                                style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ).animate().fadeIn(duration: 300.ms)
                      : TextButton.icon(
                          onPressed: widget.onGetCoachPrompt,
                          icon: const Icon(
                            Icons.auto_awesome_rounded,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          label: Text(
                            'Need inspiration? Get a coach prompt',
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.primary),
                          ),
                        ).animate().fadeIn(duration: 400.ms),
                const SizedBox(height: AppSpacing.lg),
                ConstrainedBox(
                  constraints: BoxConstraints(minHeight: screenHeight * 0.5),
                  child: TextField(
                    controller: widget.controller,
                    onChanged: widget.onChanged,
                    maxLines: null,
                    autofocus: true,
                    textCapitalization: TextCapitalization.sentences,
                    style: AppTextStyles.bodyLarge.copyWith(height: 1.8),
                    cursorColor: AppColors.primary,
                    decoration: InputDecoration(
                      hintText: widget.isFreeWrite
                          ? 'Write whatever is on your mind...'
                          : AppStrings.writeYourThoughts,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: keyboardVisible
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.all(AppSpacing.screenPaddingH),
                  child: AppPrimaryButton(
                    label: 'Continue',
                    onPressed: widget.controller.text.trim().isNotEmpty
                        ? widget.onNext
                        : null,
                    icon: Icons.arrow_forward_rounded,
                  ),
                ),
        ),
      ],
    );
  }
}

class _CollapsiblePromptCard extends StatefulWidget {
  final String prompt;

  const _CollapsiblePromptCard({required this.prompt});

  @override
  State<_CollapsiblePromptCard> createState() => _CollapsiblePromptCardState();
}

class _CollapsiblePromptCardState extends State<_CollapsiblePromptCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.prompt,
            maxLines: _expanded ? null : 3,
            overflow: _expanded ? TextOverflow.visible : TextOverflow.fade,
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.primary,
              fontStyle: FontStyle.italic,
              height: 1.6,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _expanded ? 'Show less' : 'Show full prompt',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: AppColors.primary,
                  size: 16,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TagsStep extends StatefulWidget {
  final UserProfile? profile;
  final List<String> selectedBeliefs;
  final List<String> selectedFears;
  final String mode;
  final String prompt;
  final String content;
  final bool isSaving;
  final bool isSaved;
  final void Function(String) onToggleBelief;
  final void Function(String) onToggleFear;
  final VoidCallback onSave;
  final VoidCallback onDone;
  final void Function(String content, String prompt) onDiscuss;

  const _TagsStep({
    required this.profile,
    required this.selectedBeliefs,
    required this.selectedFears,
    required this.mode,
    required this.prompt,
    required this.content,
    required this.isSaving,
    required this.isSaved,
    required this.onToggleBelief,
    required this.onToggleFear,
    required this.onSave,
    required this.onDone,
    required this.onDiscuss,
  });

  @override
  State<_TagsStep> createState() => _TagsStepState();
}

class _TagsStepState extends State<_TagsStep> {
  bool _showBeliefInfo = false;

  @override
  Widget build(BuildContext context) {
    if (widget.isSaved) {
      return _SavedView(
        content: widget.content,
        onDone: widget.onDone,
        onDiscuss: () => widget.onDiscuss(widget.content, widget.prompt),
      );
    }

    final beliefs = widget.profile?.limitingBeliefs ?? [];
    final fears = widget.profile?.fearsDrift ?? [];
    final isGrow = widget.mode == 'grow';

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.screenPaddingH),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppStrings.limitingBeliefsShifted, style: AppTextStyles.headlineMedium),
            const SizedBox(height: AppSpacing.sm),
            // Subtitle + tappable "What's this?" toggle
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    'Did you shift any limiting beliefs in this entry? (optional)',
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                GestureDetector(
                  onTap: () => setState(() => _showBeliefInfo = !_showBeliefInfo),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _showBeliefInfo
                          ? AppColors.primaryContainer
                          : AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                      border: Border.all(
                        color: _showBeliefInfo
                            ? AppColors.primary.withValues(alpha: 0.4)
                            : AppColors.border,
                      ),
                    ),
                    child: Text(
                      'What\'s this?',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: _showBeliefInfo
                            ? AppColors.primary
                            : AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // Expandable explanation callout
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: _showBeliefInfo
                  ? Container(
                      margin: const EdgeInsets.only(top: AppSpacing.sm),
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Text(
                        'Limiting beliefs are the stories you tell yourself that hold '
                        'you back — things like "I\'m not good enough" or "I\'ll never '
                        'have enough." Your coach helped you identify yours during '
                        'onboarding. Tap any that felt challenged or shifted by what '
                        'you wrote today.',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.primary,
                          height: 1.5,
                        ),
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (beliefs.isNotEmpty)
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: beliefs.map((b) {
                  final selected = widget.selectedBeliefs.contains(b);
                  return _TagChip(
                    label: b,
                    selected: selected,
                    color: AppColors.primary,
                    onTap: () => widget.onToggleBelief(b),
                  );
                }).toList(),
              )
            else
              Text(
                'No limiting beliefs tracked yet. Add them in your profile.',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
              ),

            if (isGrow && fears.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  const Icon(Icons.bolt_rounded,
                      color: AppColors.warning, size: 16),
                  const SizedBox(width: 4),
                  Text('Fears Outwitted', style: AppTextStyles.headlineSmall),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Did you face any of your fears in this entry?',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: fears.map((f) {
                  final selected = widget.selectedFears.contains(f);
                  return _TagChip(
                    label: f,
                    selected: selected,
                    color: AppColors.warning,
                    onTap: () => widget.onToggleFear(f),
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: AppSpacing.xxl),
            AppPrimaryButton(
              label: AppStrings.saveEntry,
              onPressed: widget.onSave,
              isLoading: widget.isSaving,
              icon: Icons.check_rounded,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _TagChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : AppColors.surfaceElevated,
          border: Border.all(
            color: selected ? color : AppColors.border,
          ),
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(Icons.check_rounded, size: 14, color: color),
              ),
            Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: selected ? color : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedView extends StatelessWidget {
  final String content;
  final VoidCallback onDone;
  final VoidCallback onDiscuss;

  const _SavedView({
    required this.content,
    required this.onDone,
    required this.onDiscuss,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.screenPaddingH),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded,
                color: AppColors.primary, size: 36),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Entry saved!', style: AppTextStyles.headlineMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Great reflection. Would you like to explore this deeper with your coach?',
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          AppPrimaryButton(
            label: AppStrings.discussWithCoach,
            onPressed: onDiscuss,
            icon: Icons.chat_bubble_outline_rounded,
          ),
          const SizedBox(height: AppSpacing.md),
          TextButton(
            onPressed: onDone,
            child: Text(
              'Done',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

class _ModeItem {
  final String value;
  final String label;
  final String description;
  final IconData icon;
  final Color color;

  const _ModeItem(this.value, this.label, this.description, this.icon, this.color);
}

class _MoodItem {
  final String value;
  final String emoji;
  final String label;

  const _MoodItem(this.value, this.emoji, this.label);
}
