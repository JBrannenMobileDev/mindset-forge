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

/// The single, merged onboarding "aha": one AI call produces BOTH the user's
/// identity statement (editable) AND a personalized coach analysis, revealed
/// together as one climactic payoff before the first ritual.
class StepAiSummary extends ConsumerStatefulWidget {
  final MindsetBlueprint blueprint;
  final List<String> limitingBeliefs;
  final List<Goal> goals;
  final String identitySituation;
  final List<String> identityQualities;
  final List<String> fearsDrift;
  final double mentalToughnessScore;

  /// Called with the (possibly edited) identity statement + analysis so the
  /// container can persist them.
  final void Function(String identityStatement, String summaryText) onComplete;

  const StepAiSummary({
    super.key,
    required this.blueprint,
    required this.limitingBeliefs,
    required this.goals,
    required this.identitySituation,
    required this.identityQualities,
    this.fearsDrift = const [],
    this.mentalToughnessScore = 50.0,
    required this.onComplete,
  });

  @override
  ConsumerState<StepAiSummary> createState() => _StepAiSummaryState();
}

class _StepAiSummaryState extends ConsumerState<StepAiSummary> {
  String _statement = '';
  String? _analysis;
  bool _isLoading = true;
  String? _error;
  bool _isEditing = false;
  final _editCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _generate();
  }

  @override
  void dispose() {
    _editCtrl.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _isEditing = false;
    });

    try {
      final authUser = ref.read(authStateProvider).valueOrNull;
      final tempProfile = UserProfile(
        uid: authUser?.uid ?? '',
        email: authUser?.email ?? '',
        displayName: authUser?.displayName ?? 'Friend',
        mindsetBlueprint: widget.blueprint,
        originalMindsetBaseline: widget.blueprint,
        limitingBeliefs: widget.limitingBeliefs,
        goals: widget.goals,
        identitySituation: widget.identitySituation,
        identityQualities: widget.identityQualities,
        fearsDrift: widget.fearsDrift,
        mentalToughnessScore: widget.mentalToughnessScore,
        deepDive: DeepDive.initial(),
        createdAt: DateTime.now(),
      );

      final result =
          await ref.read(claudeServiceProvider).generateOnboardingReveal(tempProfile);
      if (!mounted) return;
      setState(() {
        _statement = result['identityStatement'] ?? '';
        _editCtrl.text = _statement;
        _analysis = result['analysis'] ?? '';
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
                  AppTextButton(label: AppStrings.retry, onPressed: _generate),
                ],
              ),
            ),

          if (!_isLoading && _error == null) ...[
            _IdentityReveal(
              statement: _statement,
              isEditing: _isEditing,
              editCtrl: _editCtrl,
              onEdit: () => setState(() => _isEditing = true),
              onSaveEdit: () => setState(() {
                _statement = _editCtrl.text.trim();
                _isEditing = false;
              }),
              onRegenerate: _generate,
            ),
            const SizedBox(height: AppSpacing.lg),
            if (_analysis != null && _analysis!.isNotEmpty)
              AppGlowCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.psychology_rounded,
                            color: AppColors.primary, size: 20),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          'Your Coach\'s Analysis',
                          style: AppTextStyles.labelLarge
                              .copyWith(color: AppColors.primary),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      _analysis!,
                      style: AppTextStyles.bodyMedium.copyWith(height: 1.7),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 600.ms),
          ],

          const SizedBox(height: AppSpacing.xl),
          AppPrimaryButton(
            label: AppStrings.onboardingStartFirstRitual,
            onPressed: (_isLoading || _isEditing)
                ? null
                : () => widget.onComplete(_statement, _analysis ?? ''),
            icon: Icons.arrow_forward_rounded,
          ).animate().fadeIn(delay: 200.ms),
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: Text(
              'We\'ll take you straight to your first daily ritual.',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
          ).animate().fadeIn(delay: 250.ms),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

class _IdentityReveal extends StatelessWidget {
  final String statement;
  final bool isEditing;
  final TextEditingController editCtrl;
  final VoidCallback onEdit;
  final VoidCallback onSaveEdit;
  final VoidCallback onRegenerate;

  const _IdentityReveal({
    required this.statement,
    required this.isEditing,
    required this.editCtrl,
    required this.onEdit,
    required this.onSaveEdit,
    required this.onRegenerate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.bolt_rounded, color: AppColors.secondary, size: 18),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Who you\'re becoming',
              style: AppTextStyles.labelLarge.copyWith(color: AppColors.secondary),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary.withValues(alpha: 0.12),
                AppColors.secondary.withValues(alpha: 0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          child: isEditing
              ? TextField(
                  controller: editCtrl,
                  autofocus: true,
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  style: AppTextStyles.headlineSmall.copyWith(height: 1.6),
                  cursorColor: AppColors.primary,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    filled: false,
                  ),
                )
              : Text(
                  '"$statement"',
                  style: AppTextStyles.headlineSmall.copyWith(
                    height: 1.6,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(duration: 600.ms),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isEditing)
              AppSecondaryButton(label: 'Save', width: 120, onPressed: onSaveEdit)
            else ...[
              AppTextButton(label: 'Edit', onPressed: onEdit),
              const SizedBox(width: AppSpacing.md),
              AppTextButton(label: 'Regenerate', onPressed: onRegenerate),
            ],
          ],
        ),
      ],
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
