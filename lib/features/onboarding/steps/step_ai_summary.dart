import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../models/mindset_blueprint.dart';
import '../../../models/goal.dart';
import '../../../models/habit.dart';
import '../../../models/user_profile.dart';
import '../../../models/deep_dive.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/claude_provider.dart';
import '../../../providers/habits_provider.dart';

/// The single, merged onboarding "aha": one AI call produces BOTH the user's
/// identity statement (editable) AND a personalized coach analysis, revealed
/// together as one climactic payoff before the first ritual.
class StepAiSummary extends ConsumerStatefulWidget {
  final MindsetBlueprint blueprint;
  final List<String> limitingBeliefs;
  final List<Goal> goals;
  final String primaryGoalId;
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
    this.primaryGoalId = '',
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

  // Optional, skippable habit suggestion tied to the user's primary goal —
  // loaded independently of the identity reveal so a slow/failed AI call
  // here never blocks onboarding completion.
  Map<String, String>? _habitSuggestion;
  bool _habitHandled = false;

  @override
  void initState() {
    super.initState();
    _generate();
    _loadHabitSuggestion();
  }

  @override
  void dispose() {
    _editCtrl.dispose();
    super.dispose();
  }

  UserProfile _buildTempProfile() {
    final authUser = ref.read(authStateProvider).valueOrNull;
    return UserProfile(
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
  }

  Future<void> _generate() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _isEditing = false;
    });

    try {
      final result = await ref
          .read(claudeServiceProvider)
          .generateOnboardingReveal(_buildTempProfile());
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

  /// Best-effort, silent — a failed or empty suggestion just means the card
  /// never appears; it never blocks or errors the onboarding flow.
  Future<void> _loadHabitSuggestion() async {
    if (widget.goals.isEmpty) return;
    final goal = widget.goals.firstWhere(
      (g) => g.id == widget.primaryGoalId,
      orElse: () => widget.goals.first,
    );
    try {
      final suggestion = await ref
          .read(claudeServiceProvider)
          .generateHabitForGoal(goal, _buildTempProfile());
      if (!mounted) return;
      if (suggestion.isEmpty || (suggestion['name'] ?? '').isEmpty) return;
      setState(() => _habitSuggestion = suggestion);
    } catch (_) {
      // Silent — see doc comment above.
    }
  }

  Future<void> _addSuggestedHabit() async {
    final suggestion = _habitSuggestion;
    if (suggestion == null) return;
    setState(() => _habitHandled = true);
    try {
      await ref.read(habitsProvider.notifier).addHabit(
            Habit(
              id: const Uuid().v4(),
              name: suggestion['name'] ?? '',
              trigger: suggestion['trigger'] ?? '',
              identityReinforces: suggestion['identityReinforces'] ?? '',
              createdAt: DateTime.now(),
            ),
          );
    } catch (e) {
      debugPrint('StepAiSummary._addSuggestedHabit failed: $e');
    }
  }

  void _skipHabitSuggestion() => setState(() => _habitHandled = true);

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
            if (_habitSuggestion != null && !_habitHandled) ...[
              const SizedBox(height: AppSpacing.lg),
              _HabitSuggestionCard(
                suggestion: _habitSuggestion!,
                onAdd: _addSuggestedHabit,
                onSkip: _skipHabitSuggestion,
              ).animate().fadeIn(duration: 400.ms),
            ],
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

/// Optional, one-tap habit suggestion tied to the user's primary goal —
/// skippable, never blocks the "Start First Ritual" CTA below it.
class _HabitSuggestionCard extends StatelessWidget {
  final Map<String, String> suggestion;
  final VoidCallback onAdd;
  final VoidCallback onSkip;

  const _HabitSuggestionCard({
    required this.suggestion,
    required this.onAdd,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final name = suggestion['name'] ?? '';
    final trigger = suggestion['trigger'] ?? '';
    final identity = suggestion['identityReinforces'] ?? '';

    return AppCard(
      borderColor: AppColors.primary.withValues(alpha: 0.25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.repeat_rounded, color: AppColors.primary, size: 18),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'A habit to back this up',
                style: AppTextStyles.labelLarge.copyWith(color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(name, style: AppTextStyles.bodyLarge),
          if (trigger.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '${AppStrings.habitWhenPrefix} $trigger',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
              ),
            ),
          if (identity.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                identity,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.primary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: AppSecondaryButton(label: 'Add this habit', onPressed: onAdd),
              ),
              const SizedBox(width: AppSpacing.sm),
              AppTextButton(label: AppStrings.skip, onPressed: onSkip),
            ],
          ),
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
