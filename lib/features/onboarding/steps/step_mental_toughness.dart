import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';

class StepMentalToughness extends StatefulWidget {
  final double initial;
  final void Function(double) onNext;
  final VoidCallback onBack;

  const StepMentalToughness({
    super.key,
    this.initial = 50.0,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<StepMentalToughness> createState() => _StepMentalToughnessState();
}

class _StepMentalToughnessState extends State<StepMentalToughness> {
  late double _score;

  static const _bands = [
    _Band(0, 33, 'Still Building',
        'You\'re in the foundation stage. The greats all started here. '
            'Every discomfort you push through now is building your edge.',
        AppColors.error),
    _Band(34, 66, 'Rising',
        'You\'re developing real mental muscle. You know what\'s required — '
            'you\'re closing the gap between knowing and doing.',
        AppColors.warning),
    _Band(67, 100, 'Champion',
        'You operate at the level most people aspire to. '
            'You\'ve learned that the mind is the ultimate competitive advantage.',
        AppColors.success),
  ];

  @override
  void initState() {
    super.initState();
    _score = widget.initial;
  }

  _Band get _currentBand =>
      _bands.firstWhere((b) => _score >= b.min && _score <= b.max);

  @override
  Widget build(BuildContext context) {
    final band = _currentBand;

    return Column(
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
                  'Mental toughness is the single most important factor in whether you follow through. Where are you today?',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                ).animate().fadeIn(delay: 100.ms, duration: 400.ms),

                const SizedBox(height: AppSpacing.xxl),

                // Large score display
                Center(
                  child: Column(
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child:                       Text(
                          _score.toStringAsFixed(0),
                          key: ValueKey(_score.toStringAsFixed(0)),
                          style: AppTextStyles.headlineLarge.copyWith(
                            fontSize: 72,
                            fontWeight: FontWeight.w800,
                            color: band.color,
                          ),
                        ),
                      ),
                      Text(
                        '/ 100',
                        style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textMuted),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Container(
                          key: ValueKey(band.label),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg,
                            vertical: AppSpacing.sm,
                          ),
                          decoration: BoxDecoration(
                            color: band.color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                            border: Border.all(color: band.color.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            band.label,
                            style: AppTextStyles.labelLarge.copyWith(color: band.color),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.xl),

                // Slider
                Row(
                  children: [
                    Text('0', style: AppTextStyles.labelSmall.copyWith(color: AppColors.textMuted)),
                    Expanded(
                      child: SliderTheme(
                        data: SliderThemeData(
                          activeTrackColor: band.color,
                          thumbColor: band.color,
                          inactiveTrackColor: AppColors.border,
                          overlayColor: band.color.withValues(alpha: 0.2),
                        ),
                        child: Slider(
                          value: _score,
                          min: 0,
                          max: 100,
                          divisions: 100,
                          onChanged: (v) => setState(() => _score = v),
                        ),
                      ),
                    ),
                    Text('100', style: AppTextStyles.labelSmall.copyWith(color: AppColors.textMuted)),
                  ],
                ),

                // Band labels row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: _bands.map((b) => Text(
                          b.label,
                          style: AppTextStyles.labelSmall.copyWith(
                            color: _currentBand == b ? b.color : AppColors.textMuted,
                            fontWeight: _currentBand == b ? FontWeight.w600 : FontWeight.normal,
                          ),
                        )).toList(),
                  ),
                ),

                const SizedBox(height: AppSpacing.xl),

                // Band description
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    key: ValueKey(band.label),
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
                              style: AppTextStyles.labelSmall.copyWith(color: band.color),
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
                  ),
                ),
              ],
            ),
          ),
        ),

        // Footer
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenPaddingH,
            AppSpacing.md,
            AppSpacing.screenPaddingH,
            AppSpacing.xl,
          ),
          child: Row(
            children: [
              AppSecondaryButton(label: 'Back', onPressed: widget.onBack),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppPrimaryButton(
                  label: 'Continue',
                  onPressed: () => widget.onNext(_score),
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

class _Band {
  final double min;
  final double max;
  final String label;
  final String description;
  final Color color;

  const _Band(this.min, this.max, this.label, this.description, this.color);
}
