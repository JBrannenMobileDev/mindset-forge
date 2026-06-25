import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../models/deep_dive.dart';
import '../../models/user_profile.dart';
import '../../providers/auth_provider.dart';
import '../../providers/claude_provider.dart';

// ── Module definitions ─────────────────────────────────────────────────────

class _DeepDiveModule {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final List<_Question> questions;

  const _DeepDiveModule({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.questions,
  });
}

class _Question {
  final String id;
  final String text;
  final List<String>? options; // null → free text answer

  const _Question({required this.id, required this.text, this.options});
}

// Builds the module list from the user's profile. The fear_inventory module
// personalises its questions using the fears already identified in Blueprint.
List<_DeepDiveModule> _buildModules(UserProfile profile) {
  final primaryFear = profile.fearsDrift.isNotEmpty
      ? profile.fearsDrift[0]
      : 'your primary fear';

  return [
    const _DeepDiveModule(
      id: 'mindset_patterns',
      title: 'Mindset Patterns',
      description: 'Discover the subconscious programs running your life.',
      icon: Icons.psychology_rounded,
      color: AppColors.primary,
      questions: [
        _Question(
          id: 'self_talk',
          text: 'When you face a setback, what is your most common inner voice response?',
          options: [
            'I\'m not good enough for this',
            'Why does this always happen to me?',
            'What can I learn from this?',
            'I\'ll figure it out',
          ],
        ),
        _Question(
          id: 'money_belief',
          text: 'Complete this sentence honestly: "Rich people are..."',
        ),
        _Question(
          id: 'success_pattern',
          text: 'Describe a time you self-sabotaged something you really wanted.',
        ),
        _Question(
          id: 'identity_gap',
          text: 'What is the biggest gap between who you are now and who you want to be?',
        ),
      ],
    ),
    const _DeepDiveModule(
      id: 'motivation_style',
      title: 'Motivation Style',
      description: 'Understand what truly drives you to take action.',
      icon: Icons.bolt_rounded,
      color: AppColors.secondary,
      questions: [
        _Question(
          id: 'drive_type',
          text: 'What is your primary motivation style?',
          options: [
            'Moving toward pleasure and achievement',
            'Moving away from pain and failure',
            'External validation and recognition',
            'Intrinsic passion and meaning',
          ],
        ),
        _Question(
          id: 'energy_source',
          text: 'When do you feel most alive and energized?',
        ),
        _Question(
          id: 'procrastination',
          text: 'What do you most often procrastinate on, and what story do you tell yourself about it?',
        ),
        _Question(
          id: 'accountability',
          text: 'How do you show up when no one is watching?',
          options: [
            'I slack off significantly',
            'I do the minimum',
            'I stay consistent',
            'I actually push harder',
          ],
        ),
      ],
    ),
    _DeepDiveModule(
      id: 'fear_inventory',
      title: 'Fear Inventory',
      description: 'Your Blueprint named your fears. Now let\'s understand them.',
      icon: Icons.shield_rounded,
      color: AppColors.warning,
      questions: [
        _Question(
          id: 'fear_expression',
          text: 'Your Blueprint identified $primaryFear as your primary fear. '
              'How does it show up when you\'re about to take action?',
        ),
        _Question(
          id: 'fear_origin',
          text: 'Where did your $primaryFear come from?',
          options: [
            'A childhood experience or upbringing',
            'A specific failure or rejection',
            'What others might think or say',
            'I\'m not sure. It\'s always just been there.',
          ],
        ),
        _Question(
          id: 'fear_cost',
          text: 'What has $primaryFear already cost you?',
        ),
        _Question(
          id: 'fear_reframe',
          text: 'If $primaryFear had no power over you, what would you do differently starting tomorrow?',
        ),
      ],
    ),
    const _DeepDiveModule(
      id: 'identity_assessment',
      title: 'Identity Assessment',
      description: 'Clarify who you are becoming at your core.',
      icon: Icons.person_rounded,
      color: AppColors.categoryPersonalGrowth,
      questions: [
        _Question(
          id: 'identity_words',
          text: 'Choose 3 words that describe who you are right now:',
        ),
        _Question(
          id: 'ideal_words',
          text: 'Choose 3 words that describe who you are becoming:',
        ),
        _Question(
          id: 'role_model',
          text: 'Who is one person (real or fictional) who embodies the identity you want? What specifically do you admire about them?',
        ),
        _Question(
          id: 'identity_action',
          text: 'What is ONE action you could take every day that would prove this new identity to yourself?',
        ),
      ],
    ),
    const _DeepDiveModule(
      id: 'social_influence',
      title: 'Social Influence',
      description: 'Map the people shaping your reality.',
      icon: Icons.people_rounded,
      color: AppColors.categoryRelationships,
      questions: [
        _Question(
          id: 'inner_circle',
          text: 'Who are the 3 people you spend the most time with? Do they lift you higher or keep you comfortable?',
        ),
        _Question(
          id: 'energy_drains',
          text: 'Who in your life consistently drains your energy or reinforces limiting beliefs?',
        ),
        _Question(
          id: 'mentors',
          text: 'Do you have mentors or role models in the areas where you want to grow? (yes/no and who)',
        ),
        _Question(
          id: 'environment_change',
          text: 'What ONE change to your environment or social circle would have the biggest impact on your growth?',
        ),
      ],
    ),
  ];
}

// ── Screen ─────────────────────────────────────────────────────────────────

class DeepDiveScreen extends ConsumerStatefulWidget {
  const DeepDiveScreen({super.key});

  @override
  ConsumerState<DeepDiveScreen> createState() => _DeepDiveScreenState();
}

class _DeepDiveScreenState extends ConsumerState<DeepDiveScreen> {
  int _currentModuleIndex = 0;
  bool _inModule = false;
  String _currentModuleTitle = '';

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentUserProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            if (_inModule) {
              setState(() => _inModule = false);
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(
          _inModule ? _currentModuleTitle : 'Deep Dive',
          style: AppTextStyles.headlineMedium,
        ),
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (_, __) => const Center(child: Text('Failed to load profile.')),
        data: (profile) {
          if (profile == null) return const SizedBox.shrink();

          // Blueprint must be complete before Deep Dive is accessible.
          if (!profile.blueprintCompleted) {
            return _BlueprintRequiredState();
          }

          final modules = _buildModules(profile);

          if (_inModule) {
            return _ModuleScreen(
              module: modules[_currentModuleIndex],
              profile: profile,
              onComplete: (insight) async {
                final uid = ref.read(authStateProvider).valueOrNull?.uid;
                if (uid != null) {
                  final moduleId = modules[_currentModuleIndex].id;
                  await ref.read(firestoreServiceProvider).updateUserField(uid, {
                    'deepDive.$moduleId.insight': insight,
                    'deepDive.$moduleId.completedAt': DateTime.now().toIso8601String(),
                  });
                }
                if (mounted) setState(() => _inModule = false);
              },
            );
          }
          return _ModuleList(
            modules: modules,
            deepDive: profile.deepDive,
            onSelectModule: (index) => setState(() {
              _currentModuleIndex = index;
              _currentModuleTitle = modules[index].title;
              _inModule = true;
            }),
          );
        },
      ),
    );
  }
}

// ── Blueprint required gate ───────────────────────────────────────────────

class _BlueprintRequiredState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
              ),
              child: const Icon(Icons.lock_rounded, color: AppColors.primary, size: 36),
            ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.8, 0.8)),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Complete Your Blueprint First',
              style: AppTextStyles.headlineSmall,
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: 150.ms),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Deep Dive builds on your Blueprint scores. Finish your Blueprint to unlock these modules.',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: 250.ms),
            const SizedBox(height: AppSpacing.xl),
            AppPrimaryButton(
              label: 'Build My Blueprint',
              icon: Icons.arrow_forward_rounded,
              onPressed: () => context.push('/blueprint-setup'),
            ).animate().fadeIn(delay: 350.ms),
          ],
        ),
      ),
    );
  }
}

// ── Module list (overview) ─────────────────────────────────────────────────

class _ModuleList extends StatelessWidget {
  final List<_DeepDiveModule> modules;
  final DeepDive deepDive;
  final ValueChanged<int> onSelectModule;

  const _ModuleList({
    required this.modules,
    required this.deepDive,
    required this.onSelectModule,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenPaddingH,
        vertical: AppSpacing.lg,
      ),
      children: [
        Text(
          'Five modules. One breakthrough.',
          style: AppTextStyles.headlineSmall,
        ).animate().fadeIn(),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Each module goes deeper on what your Blueprint uncovered. Complete all five to give your coach your full story.',
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
        ).animate().fadeIn(delay: 100.ms),
        const SizedBox(height: AppSpacing.xl),
        ...modules.asMap().entries.map((e) {
          final module = e.value;
          final isCompleted = _isModuleComplete(module.id);
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: GestureDetector(
              onTap: () => onSelectModule(e.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: isCompleted ? AppColors.primaryContainer : AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  border: Border.all(
                    color: isCompleted ? AppColors.primary.withValues(alpha: 0.4) : AppColors.border,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: module.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      ),
                      child: Icon(module.icon, color: module.color, size: 24),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text('${e.key + 1}. ', style: AppTextStyles.labelSmall),
                              Expanded(
                                child: Text(module.title, style: AppTextStyles.labelLarge),
                              ),
                              if (isCompleted)
                                const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 18),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            module.description,
                            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                          ),
                          Text(
                            '${module.questions.length} questions',
                            style: AppTextStyles.labelSmall,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                  ],
                ),
              ),
            ).animate().fadeIn(delay: Duration(milliseconds: e.key * 80), duration: 400.ms),
          );
        }),
      ],
    );
  }

  bool _isModuleComplete(String moduleId) => deepDive.isModuleComplete(moduleId);
}

// ── Individual module screen ───────────────────────────────────────────────

class _ModuleScreen extends ConsumerStatefulWidget {
  final _DeepDiveModule module;
  final dynamic profile;
  final Future<void> Function(String insight) onComplete;

  const _ModuleScreen({
    required this.module,
    required this.profile,
    required this.onComplete,
  });

  @override
  ConsumerState<_ModuleScreen> createState() => _ModuleScreenState();
}

class _ModuleScreenState extends ConsumerState<_ModuleScreen> {
  int _questionIndex = 0;
  final Map<String, String> _answers = {};
  final _textCtrl = TextEditingController();
  String? _insight;
  bool _isGenerating = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  bool get _isLastQuestion =>
      _questionIndex == widget.module.questions.length - 1;
  bool get _hasInsight => _insight != null;
  _Question get _currentQuestion => widget.module.questions[_questionIndex];

  Future<void> _next() async {
    final answer = _textCtrl.text.trim();
    if (answer.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a response before continuing.')),
      );
      return;
    }
    _answers[_currentQuestion.id] = answer;
    _textCtrl.clear();

    if (_isLastQuestion) {
      await _generateInsight();
    } else {
      setState(() => _questionIndex++);
    }
  }

  void _selectOption(String option) {
    _answers[_currentQuestion.id] = option;
    _textCtrl.text = option;
  }

  Future<void> _generateInsight() async {
    setState(() => _isGenerating = true);
    try {
      final insight = await ref.read(claudeServiceProvider).generateDeepDiveInsight(
        widget.module.title,
        _answers,
        widget.profile,
      );
      if (mounted) setState(() => _insight = insight);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to generate insight. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _save() async {
    if (_insight == null) return;
    setState(() => _isSaving = true);
    try {
      await widget.onComplete(_insight!);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasInsight) return _buildInsightView();
    if (_isGenerating) return _buildGenerating();
    return _buildQuestionView();
  }

  Widget _buildQuestionView() {
    final q = _currentQuestion;
    final total = widget.module.questions.length;
    final progress = (_questionIndex + 1) / total;

    return Column(
      children: [
        // Progress bar
        LinearProgressIndicator(
          value: progress,
          backgroundColor: AppColors.border,
          valueColor: AlwaysStoppedAnimation(widget.module.color),
          minHeight: 3,
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPaddingH,
              vertical: AppSpacing.lg,
            ),
            children: [
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: widget.module.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                    ),
                    child: Text(
                      'Q${_questionIndex + 1} of $total',
                      style: AppTextStyles.labelSmall.copyWith(color: widget.module.color),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                q.text,
                style: AppTextStyles.headlineSmall,
              ).animate(key: ValueKey(_questionIndex)).fadeIn().slideX(begin: 0.1),
              const SizedBox(height: AppSpacing.xl),

              // Option chips
              if (q.options != null) ...[
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: q.options!.map((opt) {
                    final isSelected = _textCtrl.text == opt;
                    return GestureDetector(
                      onTap: () => setState(() => _selectOption(opt)),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? widget.module.color.withValues(alpha: 0.15)
                              : AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                          border: Border.all(
                            color: isSelected ? widget.module.color : AppColors.border,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Text(
                          opt,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: isSelected ? widget.module.color : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ).animate(key: ValueKey(_questionIndex)).fadeIn(delay: 100.ms),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Or add your own:',
                  style: AppTextStyles.labelSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
              ],

              // Free text input
              TextField(
                controller: _textCtrl,
                maxLines: q.options != null ? 2 : 5,
                style: AppTextStyles.bodyMedium,
                cursorColor: widget.module.color,
                decoration: InputDecoration(
                  hintText: q.options != null
                      ? 'Add your own perspective...'
                      : 'Write your honest answer...',
                  hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.surface,
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
                    borderSide: BorderSide(color: widget.module.color, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppPrimaryButton(
                label: _isLastQuestion ? 'Generate My Insight' : 'Next Question',
                onPressed: _next,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGenerating() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: widget.module.color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(widget.module.icon, color: widget.module.color, size: 40),
          ).animate().scale(duration: 600.ms).then().scale(begin: const Offset(1, 1), end: const Offset(1.05, 1.05), duration: 1000.ms),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Generating your insight...',
            style: AppTextStyles.headlineSmall,
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 200.ms),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Analyzing your responses to uncover\nyour deepest patterns.',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 400.ms),
          const SizedBox(height: AppSpacing.xl),
          const CircularProgressIndicator(color: AppColors.primary),
        ],
      ),
    );
  }

  Widget _buildInsightView() {
    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenPaddingH,
        vertical: AppSpacing.lg,
      ),
      children: [
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: widget.module.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Icon(widget.module.icon, color: widget.module.color, size: 24),
            ),
            const SizedBox(width: AppSpacing.md),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your Insight', style: AppTextStyles.labelMedium.copyWith(color: widget.module.color)),
                Text(widget.module.title, style: AppTextStyles.headlineSmall),
              ],
            ),
          ],
        ).animate().fadeIn(),
        const SizedBox(height: AppSpacing.xl),
        AppCard(
          child: Text(
            _insight!,
            style: AppTextStyles.bodyLarge.copyWith(height: 1.7),
          ),
        ).animate().fadeIn(delay: 200.ms),
        const SizedBox(height: AppSpacing.xl),
        Text(
          'Your Answers',
          style: AppTextStyles.headlineSmall,
        ).animate().fadeIn(delay: 300.ms),
        const SizedBox(height: AppSpacing.md),
        ...widget.module.questions.asMap().entries.map((e) {
          final q = e.value;
          final answer = _answers[q.id] ?? '';
          if (answer.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    q.text,
                    style: AppTextStyles.labelMedium.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(answer, style: AppTextStyles.bodyMedium),
                ],
              ),
            ).animate().fadeIn(delay: Duration(milliseconds: 400 + e.key * 60)),
          );
        }),
        const SizedBox(height: AppSpacing.xl),
        AppPrimaryButton(
          label: 'Save Insight',
          onPressed: _isSaving ? null : _save,
          isLoading: _isSaving,
        ).animate().fadeIn(delay: 500.ms),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }
}
