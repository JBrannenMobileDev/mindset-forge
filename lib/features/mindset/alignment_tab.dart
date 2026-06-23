import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/widgets/app_card.dart';
import '../../models/user_profile.dart';
import '../../models/manifestation_alignment.dart';
import '../../providers/auth_provider.dart';
import 'dart:math' as math;

class AlignmentTab extends ConsumerStatefulWidget {
  final UserProfile profile;

  const AlignmentTab({super.key, required this.profile});

  @override
  ConsumerState<AlignmentTab> createState() => _AlignmentTabState();
}

class _AlignmentTabState extends ConsumerState<AlignmentTab> {
  late ManifestationAlignment _alignment;
  bool _isDirty = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _alignment = widget.profile.manifestationAlignment;
  }

  @override
  void didUpdateWidget(AlignmentTab old) {
    super.didUpdateWidget(old);
    if (!_isDirty) {
      _alignment = widget.profile.manifestationAlignment;
    }
  }

  Future<void> _save() async {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;
    setState(() => _isSaving = true);
    try {
      await ref.read(firestoreServiceProvider).updateUserField(uid, {
        'manifestationAlignment': _alignment.copyWith(recordedAt: DateTime.now()).toJson(),
      });
      if (mounted) setState(() => _isDirty = false);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _update(ManifestationAlignment updated) {
    setState(() {
      _alignment = updated;
      _isDirty = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPaddingH,
        AppSpacing.lg,
        AppSpacing.screenPaddingH,
        100,
      ),
      children: [
        _AlignmentHero(alignment: _alignment).animate().fadeIn(duration: 400.ms),
        const SizedBox(height: AppSpacing.xl),
        Row(
          children: [
            Expanded(child: Text('Adjust Your Scores', style: AppTextStyles.headlineSmall)),
            if (_isDirty)
              _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                    )
                  : TextButton(
                      onPressed: _save,
                      child: const Text('Save'),
                    ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Reflect honestly on each dimension of your alignment.',
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.md),
        _EditableDimensionCards(
          alignment: _alignment,
          onChanged: _update,
        ).animate().fadeIn(delay: 200.ms),
        const SizedBox(height: AppSpacing.xl),
        Text('Tips to Level Up', style: AppTextStyles.headlineSmall),
        const SizedBox(height: AppSpacing.md),
        _TipsSection(alignment: _alignment).animate().fadeIn(delay: 400.ms),
      ],
    );
  }
}

class _AlignmentHero extends StatelessWidget {
  final ManifestationAlignment alignment;

  const _AlignmentHero({required this.alignment});

  @override
  Widget build(BuildContext context) {
    final score = alignment.overall;
    return AppCard(
      child: Row(
        children: [
          SizedBox(
            width: 110,
            height: 110,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(110, 110),
                  painter: _ScoreRingPainter(score: score),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      score.toStringAsFixed(0),
                      style: AppTextStyles.statNumber.copyWith(color: AppColors.primary),
                    ),
                    Text('score', style: AppTextStyles.labelSmall),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xl),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alignment.masteryLevel,
                  style: AppTextStyles.headlineMedium.copyWith(color: AppColors.primary),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text('Manifestation Level', style: AppTextStyles.labelSmall),
                const SizedBox(height: AppSpacing.md),
                Text(
                  _masteryDescription(alignment.masteryLevel),
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _masteryDescription(String level) {
    return switch (level) {
      'Awakening' => 'You\'re becoming aware of the power of your mind.',
      'Shifting' => 'Old patterns are dissolving. New beliefs are forming.',
      'Building' => 'Your identity and actions are aligning.',
      'Manifesting' => 'Your inner and outer worlds are synchronizing.',
      _ => 'You\'ve mastered the art of aligned creation.',
    };
  }
}

class _ScoreRingPainter extends CustomPainter {
  final double score;

  _ScoreRingPainter({required this.score});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 12) / 2;

    final bgPaint = Paint()
      ..color = AppColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    final gradient = SweepGradient(
      colors: [AppColors.primary, AppColors.secondary],
      startAngle: -math.pi / 2,
      endAngle: -math.pi / 2 + math.pi * 2 * (score / 100),
    );

    final fgPaint = Paint()
      ..shader = gradient.createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * (score / 100),
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(_ScoreRingPainter old) => old.score != score;
}

class _EditableDimensionCards extends StatelessWidget {
  final ManifestationAlignment alignment;
  final ValueChanged<ManifestationAlignment> onChanged;

  const _EditableDimensionCards({required this.alignment, required this.onChanged});

  static const _descriptions = {
    'Subconscious': 'Your deep-rooted beliefs and identity programs that shape reality automatically.',
    'Thought': 'The quality and direction of your conscious thoughts and mental focus.',
    'Action': 'Your daily behaviors, habits, and committed execution toward goals.',
    'Results': 'The tangible outcomes and evidence manifesting in your external world.',
  };

  @override
  Widget build(BuildContext context) {
    final dimensions = [
      ('Subconscious', alignment.subconscious),
      ('Thought', alignment.thought),
      ('Action', alignment.action),
      ('Results', alignment.results),
    ];

    return Column(
      children: dimensions.asMap().entries.map((e) {
        final name = e.value.$1;
        final value = e.value.$2;
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(name, style: AppTextStyles.labelLarge),
                    const Spacer(),
                    Text(
                      '${value.toStringAsFixed(0)}%',
                      style: AppTextStyles.headlineSmall.copyWith(color: AppColors.primary),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _descriptions[name] ?? '',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.sm),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppColors.primary,
                    inactiveTrackColor: AppColors.border,
                    thumbColor: AppColors.primary,
                    overlayColor: AppColors.primaryGlow,
                    trackHeight: 6,
                  ),
                  child: Slider(
                    value: value,
                    min: 0,
                    max: 100,
                    divisions: 20,
                    onChanged: (v) {
                      onChanged(switch (name) {
                        'Subconscious' => alignment.copyWith(subconscious: v),
                        'Thought' => alignment.copyWith(thought: v),
                        'Action' => alignment.copyWith(action: v),
                        _ => alignment.copyWith(results: v),
                      });
                    },
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: Duration(milliseconds: e.key * 80), duration: 400.ms),
        );
      }).toList(),
    );
  }
}

class _TipsSection extends StatelessWidget {
  final ManifestationAlignment alignment;

  const _TipsSection({required this.alignment});

  List<String> get _tips {
    if (alignment.subconscious < 40) {
      return [
        'Practice daily affirmations — morning and evening',
        'Read your identity statement with emotion every day',
        'Journal about the version of you who has already achieved your goals',
      ];
    }
    if (alignment.action < 40) {
      return [
        'Set 3 non-negotiable priority actions each morning',
        'Track habit completion — consistency compounds',
        'Raise the floor, not the ceiling: show up even on bad days',
      ];
    }
    return [
      'Log daily evidence of your new identity taking shape',
      'Have your weekly insight conversation',
      'Celebrate small wins loudly — the brain needs evidence',
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _tips.asMap().entries.map((e) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(right: AppSpacing.md),
              decoration: const BoxDecoration(
                color: AppColors.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '${e.key + 1}',
                  style: AppTextStyles.labelSmall.copyWith(color: AppColors.primary),
                ),
              ),
            ),
            Expanded(
              child: Text(e.value, style: AppTextStyles.bodyMedium.copyWith(height: 1.5)),
            ),
          ],
        ),
      )).toList(),
    );
  }
}
