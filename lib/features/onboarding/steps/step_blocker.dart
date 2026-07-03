import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/hoverable.dart';
import '../../../models/goal.dart';
import '../../../providers/claude_provider.dart';

/// "What's holding you back?" step.
///
/// Instead of asking the user to self-diagnose from a cold list, the AI infers
/// the limiting beliefs they most likely hold from what they already shared
/// (situation, future-self qualities, goals). The user reacts by tapping the
/// ones that resonate (recognition, not recall) and can add their own. The
/// deeper fear quiz and trait blueprint are collected progressively in-app
/// afterwards.
class StepBlocker extends ConsumerStatefulWidget {
  final String identitySituation;
  final List<String> identityQualities;
  final List<Goal> goals;
  final List<String> initialBeliefs;
  final void Function(List<String> beliefs) onNext;
  final VoidCallback onBack;

  const StepBlocker({
    super.key,
    required this.identitySituation,
    required this.identityQualities,
    required this.goals,
    required this.initialBeliefs,
    required this.onNext,
    required this.onBack,
  });

  @override
  ConsumerState<StepBlocker> createState() => _StepBlockerState();
}

class _StepBlockerState extends ConsumerState<StepBlocker> {
  /// All belief options shown as chips (AI-inferred + any the user added).
  late List<String> _candidates;

  /// Beliefs the user has tapped as resonating.
  late Set<String> _selected;

  bool _loading = true;
  final _beliefCtrl = TextEditingController();
  String? _errorText;

  static const _fallbackBeliefs = [
    "I'm not good enough",
    "Money is hard to make",
    "I always fail",
    "Success isn't for people like me",
    "I don't deserve success",
  ];

  @override
  void initState() {
    super.initState();
    _candidates = List.from(widget.initialBeliefs);
    _selected = widget.initialBeliefs.toSet();
    _infer();
  }

  @override
  void dispose() {
    _beliefCtrl.dispose();
    super.dispose();
  }

  Future<void> _infer() async {
    List<String> inferred;
    try {
      inferred = await ref.read(claudeServiceProvider).inferLimitingBeliefs(
            situation: widget.identitySituation,
            qualities: widget.identityQualities,
            goals: widget.goals,
          );
    } catch (_) {
      inferred = _fallbackBeliefs;
    }
    if (!mounted) return;
    setState(() {
      // Preserve any previously selected beliefs, then append fresh inferred
      // options that aren't already present.
      for (final b in inferred) {
        if (!_candidates.contains(b)) _candidates.add(b);
      }
      if (_candidates.isEmpty) _candidates = List.from(_fallbackBeliefs);
      _loading = false;
    });
  }

  void _toggle(String belief) {
    setState(() {
      if (_selected.contains(belief)) {
        _selected.remove(belief);
      } else {
        _selected.add(belief);
        _errorText = null;
      }
    });
  }

  void _addCustom(String belief) {
    final trimmed = belief.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      if (!_candidates.contains(trimmed)) _candidates.add(trimmed);
      _selected.add(trimmed);
      _beliefCtrl.clear();
      _errorText = null;
    });
  }

  void _tryNext() {
    if (_selected.isEmpty) {
      setState(() => _errorText = 'Tap at least one to continue.');
      return;
    }
    // Preserve the display order of the chips.
    final ordered = _candidates.where(_selected.contains).toList();
    widget.onNext(ordered);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final keyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
    final scrollBottomPadding =
        bottomInset + AppSpacing.buttonHeight + AppSpacing.lg;

    return Stack(
      fit: StackFit.expand,
      children: [
        SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.screenPaddingH,
            AppSpacing.md,
            AppSpacing.screenPaddingH,
            scrollBottomPadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.onboardingBlockerTitle,
                style: AppTextStyles.headlineLarge,
              ).animate().fadeIn(duration: 400.ms),
              const SizedBox(height: AppSpacing.sm),
              Text(
                AppStrings.onboardingBlockerSubtitle,
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary),
              ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
              const SizedBox(height: AppSpacing.xl),

              if (_loading)
                _LoadingBeliefs()
              else ...[
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: _candidates.asMap().entries.map((e) {
                    final belief = e.value;
                    final selected = _selected.contains(belief);
                    return Hoverable(
                      onTap: () => _toggle(belief),
                      builder: (context, hovered) => AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.primaryContainer
                              : AppColors.surfaceElevated,
                          border: Border.all(
                            color: selected
                                ? AppColors.primary
                                : hovered
                                    ? AppColors.primary.withValues(alpha: 0.5)
                                    : AppColors.border,
                          ),
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusFull),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (selected)
                              const Padding(
                                padding: EdgeInsets.only(right: 4),
                                child: Icon(Icons.check_rounded,
                                    size: 14, color: AppColors.primary),
                              ),
                            Text(
                              belief,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: selected
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ).animate().fadeIn(
                          delay: Duration(milliseconds: e.key * 40),
                          duration: 300.ms,
                        );
                  }).toList(),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Custom belief input
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _beliefCtrl,
                        style: AppTextStyles.bodyMedium,
                        cursorColor: AppColors.primary,
                        textCapitalization: TextCapitalization.sentences,
                        onSubmitted: _addCustom,
                        decoration: InputDecoration(
                          hintText: AppStrings.onboardingBlockerCustomHint,
                          hintStyle: AppTextStyles.bodyMedium
                              .copyWith(color: AppColors.textMuted),
                          filled: true,
                          fillColor: AppColors.surfaceElevated,
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusMd),
                            borderSide: const BorderSide(color: AppColors.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusMd),
                            borderSide:
                                const BorderSide(color: AppColors.primary),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusMd),
                            borderSide: const BorderSide(color: AppColors.border),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.md,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    IconButton.filled(
                      onPressed: () => _addCustom(_beliefCtrl.text),
                      icon: const Icon(Icons.add_rounded),
                      style: IconButton.styleFrom(
                          backgroundColor: AppColors.primary),
                    ),
                  ],
                ),

                if (_errorText != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _errorText!,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.error),
                  ),
                ],
              ],
            ],
          ),
        ),

        // Footer fades out when keyboard is open.
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: AnimatedOpacity(
            opacity: keyboardVisible ? 0.0 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: IgnorePointer(
              ignoring: keyboardVisible,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.background.withValues(alpha: 0),
                      AppColors.background,
                    ],
                    stops: const [0.0, 0.45],
                  ),
                ),
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.screenPaddingH,
                  AppSpacing.xl,
                  AppSpacing.screenPaddingH,
                  bottomInset + AppSpacing.md,
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
                      child: AppPrimaryButton(
                        label: 'Continue',
                        onPressed: _loading ? null : _tryNext,
                        icon: Icons.arrow_forward_rounded,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Skeleton shown while the AI infers likely limiting beliefs.
class _LoadingBeliefs extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.primary),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              AppStrings.onboardingBlockerLoading,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: List.generate(5, (i) {
            return Container(
              width: 120 + (i.isEven ? 40.0 : 0.0),
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                border: Border.all(color: AppColors.border),
              ),
            );
          }),
        )
            .animate(onPlay: (c) => c.repeat())
            .shimmer(
                duration: 1500.ms,
                color: AppColors.primary.withValues(alpha: 0.1)),
      ],
    );
  }
}
