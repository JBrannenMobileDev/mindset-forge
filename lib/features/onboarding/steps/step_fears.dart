import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';

/// 3-question quiz that auto-scores to a primary + secondary fear.
/// Results screen shows fear cards with a confirm / swap flow.
class StepFears extends StatefulWidget {
  final List<String> initial;
  final void Function(List<String>) onNext;
  final VoidCallback onBack;

  const StepFears({
    super.key,
    required this.initial,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<StepFears> createState() => _StepFearsState();
}

class _StepFearsState extends State<StepFears> {
  // quiz | results
  String _phase = 'quiz';
  int _currentQuestion = 0;
  final Map<String, int> _scores = {};

  List<String> _top2 = [];
  bool _adjusting = false; // whether user is manually selecting their fears

  // ── Question data ──────────────────────────────────────────────────────────

  static const _questions = [
    _Question(
      'When you feel stuck, which happens most?',
      [
        _Answer('I overthink instead of acting', 'Perfectionism'),
        _Answer('I worry what others will think', 'Fear of Judgment'),
        _Answer('I doubt I have what it takes', 'Imposter Syndrome'),
        _Answer('I\'m afraid to fail publicly', 'Fear of Failure'),
        _Answer('I freeze and have no idea what to do', 'Fear of Uncertainty'),
        _Answer('I wait for the "right" moment', 'Fear of Failure'),
      ],
    ),
    _Question(
      'Which situation creates the most anxiety?',
      [
        _Answer('Public speaking or being seen', 'Fear of Judgment'),
        _Answer('Starting something with no guarantee', 'Fear of Uncertainty'),
        _Answer('Asking for what I want', 'Fear of Rejection'),
        _Answer('Being judged by people I respect', 'Fear of Judgment'),
        _Answer('Failing after putting in real effort', 'Fear of Failure'),
        _Answer('Succeeding and then losing it', 'Fear of Success'),
      ],
    ),
    _Question(
      'First thought when considering a big action?',
      [
        _Answer('What if it doesn\'t work?', 'Fear of Failure'),
        _Answer('What will people say?', 'Fear of Judgment'),
        _Answer('I\'m not ready yet', 'Imposter Syndrome'),
        _Answer('Someone else should do this', 'Fear of Success'),
        _Answer('I\'ll start when conditions are right', 'Perfectionism'),
        _Answer('I don\'t deserve this level of success', 'Fear of Success'),
      ],
    ),
  ];

  // ── Fear metadata ──────────────────────────────────────────────────────────

  static const _fearMeta = {
    'Fear of Failure': _FearMeta(
      'Fear of Failure',
      'You avoid action because the possibility of failing feels worse than not trying. Napoleon Hill called this "the sixth basic fear."',
      Icons.sports_score_rounded,
    ),
    'Fear of Judgment': _FearMeta(
      'Fear of Judgment',
      'The opinions of others weigh heavily on your decisions. You edit yourself to avoid criticism.',
      Icons.visibility_rounded,
    ),
    'Fear of Success': _FearMeta(
      'Fear of Success',
      'Deep down, you fear the demands success would place on you. The new responsibilities, the higher expectations, the version of yourself you\'d have to become.',
      Icons.emoji_events_rounded,
    ),
    'Fear of Rejection': _FearMeta(
      'Fear of Rejection',
      'Asking or putting yourself forward feels risky because you anticipate being turned down.',
      Icons.block_rounded,
    ),
    'Fear of Uncertainty': _FearMeta(
      'Fear of Uncertainty',
      'You need to see the full picture before acting. The unknown paralyzes rather than excites you.',
      Icons.help_outline_rounded,
    ),
    'Imposter Syndrome': _FearMeta(
      'Imposter Syndrome',
      'You believe others will eventually discover you\'re not as capable as they think. You self-select out before being "found out."',
      Icons.person_off_rounded,
    ),
    'Perfectionism': _FearMeta(
      'Perfectionism',
      'Standards so high they prevent starting. You mistake perfect for good, and miss the reps that build real competence.',
      Icons.auto_fix_high_rounded,
    ),
  };

  // ── Logic ──────────────────────────────────────────────────────────────────

  void _answer(String fearLabel) {
    setState(() {
      _scores[fearLabel] = (_scores[fearLabel] ?? 0) + 1;
      if (_currentQuestion < _questions.length - 1) {
        _currentQuestion++;
      } else {
        _computeResults();
      }
    });
  }

  void _computeResults() {
    final sorted = _scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    _top2 = sorted.take(2).map((e) => e.key).toList();
    if (_top2.isEmpty) _top2 = ['Fear of Failure'];
    if (_top2.length < 2) _top2.add('Fear of Uncertainty');
    _phase = 'results';
  }

  void _toggleManualSelect(String fear) {
    setState(() {
      if (_top2.contains(fear)) {
        _top2 = List.from(_top2)..remove(fear);
      } else if (_top2.length < 2) {
        _top2 = [..._top2, fear];
      } else {
        // Replace the secondary (second item) with the new choice
        _top2 = [_top2[0], fear];
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: _phase == 'quiz' ? _buildQuiz() : _buildResults(),
    );
  }

  // ── Quiz UI ────────────────────────────────────────────────────────────────

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
                Text('Identify Your Fears', style: AppTextStyles.headlineMedium)
                    .animate().fadeIn(duration: 400.ms),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Outwitting the Devil begins with naming the fears that keep you drifting.',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                ).animate().fadeIn(delay: 100.ms, duration: 400.ms),

                const SizedBox(height: AppSpacing.lg),

                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 4,
                    backgroundColor: AppColors.border,
                    valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Question ${_currentQuestion + 1} of ${_questions.length}',
                  style: AppTextStyles.labelSmall.copyWith(color: AppColors.textMuted),
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
                            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: GestureDetector(
                              onTap: () => _answer(e.value.fearLabel),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(AppSpacing.lg),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceElevated,
                                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Text(
                                  e.value.text,
                                  style: AppTextStyles.bodyMedium,
                                ),
                              ).animate().fadeIn(
                                    delay: Duration(milliseconds: e.key * 50),
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
            AppSpacing.screenPaddingH, AppSpacing.md,
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
                  onPressed: () => widget.onNext([]),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Results UI ─────────────────────────────────────────────────────────────

  Widget _buildResults() {
    final primary = _top2.isNotEmpty ? _fearMeta[_top2[0]] : null;
    final secondary = _top2.length > 1 ? _fearMeta[_top2[1]] : null;

    return Column(
      key: const ValueKey('results'),
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.screenPaddingH),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your Fear Profile', style: AppTextStyles.headlineMedium)
                    .animate().fadeIn(duration: 400.ms),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Awareness is the first step to outwitting these patterns.',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                ).animate().fadeIn(delay: 100.ms, duration: 400.ms),

                const SizedBox(height: AppSpacing.xl),

                if (primary != null) ...[
                  _FearCard(
                    meta: primary,
                    badge: 'Primary Fear',
                    badgeColor: AppColors.error,
                    delay: 200,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                if (secondary != null) ...[
                  _FearCard(
                    meta: secondary,
                    badge: 'Secondary Fear',
                    badgeColor: AppColors.warning,
                    delay: 300,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],

                if (_adjusting) ...[
                  Text(
                    'Pick up to two fears. Your first choice becomes primary.',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ..._fearMeta.keys.map((f) {
                    final idx = _top2.indexOf(f);
                    final isSelected = idx != -1;
                    final badgeLabel = idx == 0 ? 'Primary' : idx == 1 ? 'Secondary' : null;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: GestureDetector(
                        onTap: () => _toggleManualSelect(f),
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primaryContainer
                                : AppColors.surfaceElevated,
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusMd),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.border,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                  child: Text(f, style: AppTextStyles.bodyMedium)),
                              if (badgeLabel != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.sm,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(
                                        AppSpacing.radiusFull),
                                  ),
                                  child: Text(
                                    badgeLabel,
                                    style: AppTextStyles.labelSmall
                                        .copyWith(color: AppColors.primary),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ] else ...[
                  TextButton(
                    onPressed: () => setState(() => _adjusting = true),
                    child: Text(
                      'This doesn\'t feel right',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        decoration: TextDecoration.underline,
                        decorationColor: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.screenPaddingH, AppSpacing.md,
            AppSpacing.screenPaddingH,
            MediaQuery.of(context).padding.bottom + AppSpacing.md,
          ),
          child: Row(
            children: [
              AppSecondaryButton(
                label: _adjusting ? 'Cancel' : 'Back',
                width: 100,
                onPressed: () => setState(() {
                  if (_adjusting) {
                    _adjusting = false;
                  } else {
                    _phase = 'quiz';
                    _currentQuestion = 0;
                    _scores.clear();
                  }
                }),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppPrimaryButton(
                  label: _adjusting ? 'Use these' : 'Continue',
                  onPressed: _top2.isNotEmpty
                      ? () {
                          if (_adjusting) {
                            setState(() => _adjusting = false);
                          } else {
                            widget.onNext(_top2);
                          }
                        }
                      : null,
                  icon: _adjusting ? Icons.check_rounded : Icons.arrow_forward_rounded,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Fear card ────────────────────────────────────────────────────────────────

class _FearCard extends StatelessWidget {
  final _FearMeta meta;
  final String badge;
  final Color badgeColor;
  final int delay;

  const _FearCard({
    required this.meta,
    required this.badge,
    required this.badgeColor,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  badge,
                  style: AppTextStyles.labelSmall.copyWith(color: badgeColor),
                ),
              ),
              const Spacer(),
              Icon(meta.icon, color: badgeColor, size: 20),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(meta.label, style: AppTextStyles.labelLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(
            meta.description,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: delay), duration: 400.ms);
  }
}

// ─── Data classes ─────────────────────────────────────────────────────────────

class _Question {
  final String text;
  final List<_Answer> answers;

  const _Question(this.text, this.answers);
}

class _Answer {
  final String text;
  final String fearLabel;

  const _Answer(this.text, this.fearLabel);
}

class _FearMeta {
  final String label;
  final String description;
  final IconData icon;

  const _FearMeta(this.label, this.description, this.icon);
}
