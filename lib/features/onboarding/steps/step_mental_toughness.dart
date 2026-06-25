import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../models/mindset_blueprint.dart';

/// Mental toughness assessment — 3 behavioural questions auto-scored and
/// blended with the discipline + resilience traits already in [blueprint].
///
/// Score formula:
///   quizScore  = average of 3 answers (each: 0 / 33 / 67 / 100)
///   traitScore = (blueprint.discipline + blueprint.resilience) / 2 / 10 * 100
///   final      = quizScore * 0.6 + traitScore * 0.4
class StepMentalToughness extends StatefulWidget {
  final MindsetBlueprint blueprint;
  final double initial;
  final void Function(double) onNext;
  final VoidCallback onBack;

  const StepMentalToughness({
    super.key,
    required this.blueprint,
    this.initial = 50.0,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<StepMentalToughness> createState() => _StepMentalToughnessState();
}

class _StepMentalToughnessState extends State<StepMentalToughness> {
  String _phase = 'quiz'; // 'quiz' | 'results'
  int _currentQuestion = 0;
  final List<int> _answers = []; // scores per question (0/33/67/100)
  double _finalScore = 0;

  static const _questions = [
    _Question(
      'When you miss your goals for a week, you typically...',
      [
        _Answer('Jump back in the next day', 100),
        _Answer('Restart within a few days', 67),
        _Answer('Take about a week to reset', 33),
        _Answer('Struggle to find your footing again', 0),
      ],
    ),
    _Question(
      'When you feel completely unmotivated, you...',
      [
        _Answer('Do the work anyway. Feelings follow action.', 100),
        _Answer('Reduce the task but still do something', 67),
        _Answer('Wait until you feel ready', 33),
        _Answer('Skip it and try again later', 0),
      ],
    ),
    _Question(
      'When someone doubts your ability or criticizes your plan...',
      [
        _Answer('Use it as fuel to prove them wrong', 100),
        _Answer('Consider it briefly but stay the course', 67),
        _Answer('Feel shaken but push through eventually', 33),
        _Answer('Find it hard to continue', 0),
      ],
    ),
  ];

  static const _bands = [
    _Band(0, 33, 'Still Building',
        'You\'re in the foundation stage, and that\'s exactly where every champion has stood. '
            'Every time you push through discomfort now, you\'re building an edge others won\'t have.',
        AppColors.error),
    _Band(34, 66, 'Rising',
        'You\'re developing real mental muscle. You know what\'s required, '
            'and you\'re steadily closing the gap between knowing and doing.',
        AppColors.warning),
    _Band(67, 100, 'Champion',
        'You operate at a level most people only aspire to. '
            'You\'ve learned that the mind is the ultimate competitive advantage.',
        AppColors.success),
  ];

  _Band get _currentBand =>
      _bands.firstWhere((b) => _finalScore >= b.min && _finalScore <= b.max,
          orElse: () => _bands.last);

  void _selectAnswer(int score) {
    final updated = List<int>.from(_answers)..add(score);

    if (_currentQuestion < _questions.length - 1) {
      setState(() {
        _answers.clear();
        _answers.addAll(updated);
        _currentQuestion++;
      });
    } else {
      // All questions answered — compute final score
      final quizScore = updated.reduce((a, b) => a + b) / updated.length;
      final traitScore =
          (widget.blueprint.discipline + widget.blueprint.resilience) /
              2 /
              10 *
              100;
      final computed = (quizScore * 0.6) + (traitScore * 0.4);
      setState(() {
        _answers.clear();
        _answers.addAll(updated);
        _finalScore = computed.clamp(0, 100);
        _phase = 'results';
      });
    }
  }

  void _retakeQuiz() {
    setState(() {
      _phase = 'quiz';
      _currentQuestion = 0;
      _answers.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: _phase == 'quiz' ? _buildQuiz() : _buildResults(),
    );
  }

  Widget _buildQuiz() {
    final q = _questions[_currentQuestion];
    final progress = (_currentQuestion + 1) / _questions.length;

    return Column(
      key: const ValueKey('quiz'),
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.screenPaddingH),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Mental Toughness', style: AppTextStyles.headlineMedium)
                    .animate().fadeIn(duration: 400.ms),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Answer honestly. This isn\'t a test. It\'s a mirror.',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary),
                ).animate().fadeIn(delay: 100.ms, duration: 400.ms),

                const SizedBox(height: AppSpacing.lg),

                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 4,
                    backgroundColor: AppColors.border,
                    valueColor:
                        const AlwaysStoppedAnimation(AppColors.primary),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Question ${_currentQuestion + 1} of ${_questions.length}',
                  style: AppTextStyles.labelSmall
                      .copyWith(color: AppColors.textMuted),
                ),

                const SizedBox(height: AppSpacing.xl),

                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Column(
                    key: ValueKey(_currentQuestion),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(q.text, style: AppTextStyles.headlineSmall)
                          .animate().fadeIn(duration: 300.ms),
                      const SizedBox(height: AppSpacing.lg),
                      ...q.answers.asMap().entries.map((e) => Padding(
                            padding:
                                const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: GestureDetector(
                              onTap: () => _selectAnswer(e.value.score),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(AppSpacing.lg),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceElevated,
                                  borderRadius: BorderRadius.circular(
                                      AppSpacing.radiusMd),
                                  border:
                                      Border.all(color: AppColors.border),
                                ),
                                child: Text(
                                  e.value.text,
                                  style: AppTextStyles.bodyMedium,
                                ),
                              ).animate().fadeIn(
                                    delay: Duration(
                                        milliseconds: e.key * 50),
                                    duration: 300.ms,
                                  ),
                            ),
                          )),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.screenPaddingH,
            AppSpacing.md,
            AppSpacing.screenPaddingH,
            MediaQuery.of(context).padding.bottom + AppSpacing.md,
          ),
          child: Row(
            children: [
              AppSecondaryButton(
                label: 'Back',
                width: 100,
                onPressed: widget.onBack,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppSecondaryButton(
                  label: 'Skip',
                  onPressed: () => widget.onNext(widget.initial),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResults() {
    final band = _currentBand;
    final score = _finalScore.round();

    return Column(
      key: const ValueKey('results'),
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.screenPaddingH),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your Mental Toughness', style: AppTextStyles.headlineMedium)
                    .animate().fadeIn(duration: 400.ms),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Based on how you actually behave under pressure.',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary),
                ).animate().fadeIn(delay: 100.ms, duration: 400.ms),

                const SizedBox(height: AppSpacing.xxl),

                // Score display
                Center(
                  child: Column(
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                          '$score',
                          key: ValueKey(score),
                          style: AppTextStyles.headlineLarge.copyWith(
                            fontSize: 72,
                            fontWeight: FontWeight.w800,
                            color: band.color,
                          ),
                        ),
                      ),
                      Text(
                        '/ 100',
                        style: AppTextStyles.bodyLarge
                            .copyWith(color: AppColors.textMuted),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: AppSpacing.sm,
                        ),
                        decoration: BoxDecoration(
                          color: band.color.withValues(alpha: 0.12),
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusFull),
                          border: Border.all(
                              color: band.color.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          band.label,
                          style: AppTextStyles.labelLarge
                              .copyWith(color: band.color),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 200.ms, duration: 500.ms)
                    .scale(begin: const Offset(0.85, 0.85), delay: 200.ms, duration: 500.ms, curve: Curves.easeOut),

                const SizedBox(height: AppSpacing.xl),

                // Band description card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.format_quote_rounded,
                              color: band.color, size: 18),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            '177 Mental Toughness Secrets',
                            style: AppTextStyles.labelSmall
                                .copyWith(color: band.color),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        band.description,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 400.ms, duration: 400.ms),

                const SizedBox(height: AppSpacing.lg),

                // Score composition note
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  child: Text(
                    'Score weighted from your answers (60%) and your discipline + resilience ratings (40%).',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ).animate().fadeIn(delay: 500.ms, duration: 400.ms),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.screenPaddingH,
            AppSpacing.md,
            AppSpacing.screenPaddingH,
            MediaQuery.of(context).padding.bottom + AppSpacing.md,
          ),
          child: Row(
            children: [
              AppSecondaryButton(
                label: 'Retake',
                width: 100,
                onPressed: _retakeQuiz,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppPrimaryButton(
                  label: 'Continue',
                  onPressed: () => widget.onNext(_finalScore),
                  icon: Icons.arrow_forward_rounded,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Data classes ──────────────────────────────────────────────────────────────

class _Question {
  final String text;
  final List<_Answer> answers;
  const _Question(this.text, this.answers);
}

class _Answer {
  final String text;
  final int score;
  const _Answer(this.text, this.score);
}

class _Band {
  final double min;
  final double max;
  final String label;
  final String description;
  final Color color;
  const _Band(this.min, this.max, this.label, this.description, this.color);
}
