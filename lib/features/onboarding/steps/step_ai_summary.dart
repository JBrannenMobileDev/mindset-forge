import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../models/mindset_blueprint.dart';
import '../../../models/goal.dart';
import '../../../models/user_profile.dart';
import '../../../models/deep_dive.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/claude_provider.dart';

class StepAiSummary extends ConsumerStatefulWidget {
  final MindsetBlueprint blueprint;
  final List<String> limitingBeliefs;
  final List<Goal> goals;
  final String identityStatement;
  final List<String> fearsDrift;
  final double mentalToughnessScore;
  /// Called with the generated summary text so the container can persist it.
  final void Function(String summaryText) onComplete;

  const StepAiSummary({
    super.key,
    required this.blueprint,
    required this.limitingBeliefs,
    required this.goals,
    required this.identityStatement,
    this.fearsDrift = const [],
    this.mentalToughnessScore = 50.0,
    required this.onComplete,
  });

  @override
  ConsumerState<StepAiSummary> createState() => _StepAiSummaryState();
}

class _StepAiSummaryState extends ConsumerState<StepAiSummary> {
  String? _summary;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _generateSummary();
  }

  Future<void> _generateSummary() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final uid = ref.read(authStateProvider).valueOrNull?.uid ?? '';
      final authUser = ref.read(authStateProvider).valueOrNull;
      final tempProfile = UserProfile(
        uid: uid,
        email: authUser?.email ?? '',
        displayName: authUser?.displayName ?? 'Friend',
        mindsetBlueprint: widget.blueprint,
        originalMindsetBaseline: widget.blueprint,
        limitingBeliefs: widget.limitingBeliefs,
        goals: widget.goals,
        identityStatement: widget.identityStatement,
        fearsDrift: widget.fearsDrift,
        mentalToughnessScore: widget.mentalToughnessScore,
        deepDive: DeepDive.initial(),
        createdAt: DateTime.now(),
      );

      final result = await ref.read(claudeServiceProvider).generateMindsetSummary(tempProfile);
      if (!mounted) return;
      setState(() {
        _summary = result;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = AppStrings.errorAI;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenPaddingH,
        vertical: AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.onboardingSummaryTitle,
            style: AppTextStyles.headlineLarge,
          ).animate().fadeIn(duration: 400.ms),
          const SizedBox(height: AppSpacing.sm),
          Text(
            AppStrings.onboardingSummarySubtitle,
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
          ).animate().fadeIn(delay: 100.ms),
          const SizedBox(height: AppSpacing.xl),
          _BlueprintSummary(blueprint: widget.blueprint),
          const SizedBox(height: AppSpacing.lg),
          if (_isLoading) _LoadingCard(),
          if (_error != null)
            AppCard(
              child: Column(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.error, size: 32),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _error!,
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextButton(label: AppStrings.retry, onPressed: _generateSummary),
                ],
              ),
            ),
          if (_summary != null)
            AppGlowCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.psychology_rounded, color: AppColors.primary, size: 20),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Your Coach\'s Analysis',
                        style: AppTextStyles.labelLarge.copyWith(color: AppColors.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    _summary!,
                    style: AppTextStyles.bodyMedium.copyWith(height: 1.7),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 600.ms),
          const SizedBox(height: AppSpacing.xxl),
          AppPrimaryButton(
            label: AppStrings.enterMindsetForge,
            onPressed: _isLoading ? null : () => widget.onComplete(_summary ?? ''),
            icon: Icons.arrow_forward_rounded,
          ).animate().fadeIn(delay: 200.ms),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          const SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Analyzing your profile...',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    )
        .animate(onPlay: (c) => c.repeat())
        .shimmer(duration: 1500.ms, color: AppColors.primary.withValues(alpha: 0.1));
  }
}

class _BlueprintSummary extends StatelessWidget {
  final MindsetBlueprint blueprint;

  const _BlueprintSummary({required this.blueprint});

  @override
  Widget build(BuildContext context) {
    final traits = [
      ('Confidence', blueprint.confidence),
      ('Discipline', blueprint.discipline),
      ('Abundance', blueprint.abundanceThinking),
      ('Resilience', blueprint.resilience),
      ('Decisiveness', blueprint.decisiveness),
    ];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your Mindset Blueprint', style: AppTextStyles.labelLarge),
          const SizedBox(height: AppSpacing.md),
          ...traits.map((t) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  children: [
                    SizedBox(
                      width: 100,
                      child: Text(
                        t.$1,
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: t.$2 / 10,
                          backgroundColor: AppColors.border,
                          valueColor: AlwaysStoppedAnimation(AppColors.primary),
                          minHeight: 6,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      t.$2.toStringAsFixed(0),
                      style: AppTextStyles.labelMedium.copyWith(color: AppColors.primary),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
