import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';

/// Lightweight "what's holding you back?" step.
///
/// Collects at least one limiting belief (tap suggestions or type your own) plus
/// an optional primary fear. This is the only blocker input required to reach the
/// onboarding "aha" — the deeper fear quiz and trait blueprint are collected
/// progressively in-app afterwards.
class StepBlocker extends StatefulWidget {
  final List<String> initialBeliefs;
  final List<String> initialFears;
  final void Function(List<String> beliefs, List<String> fears) onNext;
  final VoidCallback onBack;

  const StepBlocker({
    super.key,
    required this.initialBeliefs,
    required this.initialFears,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<StepBlocker> createState() => _StepBlockerState();
}

class _StepBlockerState extends State<StepBlocker> {
  late List<String> _beliefs;
  String? _fear;
  final _beliefCtrl = TextEditingController();
  String? _errorText;

  static const _beliefSuggestions = [
    "I'm not good enough",
    "Money is hard to make",
    "I always fail",
    "Success isn't for people like me",
    "I don't deserve success",
    "People will judge me",
    "I'm too young/old",
    "I lack the talent",
  ];

  static const _fearOptions = [
    'Fear of Failure',
    'Fear of Judgment',
    'Fear of Success',
    'Fear of Rejection',
    'Fear of Uncertainty',
    'Imposter Syndrome',
    'Perfectionism',
  ];

  @override
  void initState() {
    super.initState();
    _beliefs = List.from(widget.initialBeliefs);
    _fear = widget.initialFears.isNotEmpty ? widget.initialFears.first : null;
  }

  @override
  void dispose() {
    _beliefCtrl.dispose();
    super.dispose();
  }

  void _addBelief(String belief) {
    final trimmed = belief.trim();
    if (trimmed.isEmpty || _beliefs.contains(trimmed)) return;
    setState(() {
      _beliefs = [..._beliefs, trimmed];
      _beliefCtrl.clear();
      _errorText = null;
    });
  }

  void _removeBelief(String belief) =>
      setState(() => _beliefs = _beliefs.where((b) => b != belief).toList());

  void _tryNext() {
    if (_beliefs.isEmpty) {
      setState(() => _errorText = 'Add at least one belief to continue.');
      return;
    }
    widget.onNext(_beliefs, _fear != null ? [_fear!] : const []);
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
                  "What's holding you back?",
                  style: AppTextStyles.headlineLarge,
                ).animate().fadeIn(duration: 400.ms),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Name the stories that keep you stuck. Awareness is the first step to outwitting them.',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary),
                ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
                const SizedBox(height: AppSpacing.xl),

                // ── Limiting beliefs ─────────────────────────────────────────
                Text('Tap any that ring true', style: AppTextStyles.labelLarge)
                    .animate()
                    .fadeIn(delay: 150.ms, duration: 400.ms),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: _beliefSuggestions.map((s) {
                    final added = _beliefs.contains(s);
                    return GestureDetector(
                      onTap: added ? () => _removeBelief(s) : () => _addBelief(s),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        decoration: BoxDecoration(
                          color: added
                              ? AppColors.primaryContainer
                              : AppColors.surfaceElevated,
                          border: Border.all(
                            color: added ? AppColors.primary : AppColors.border,
                          ),
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusFull),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (added)
                              const Padding(
                                padding: EdgeInsets.only(right: 4),
                                child: Icon(Icons.check_rounded,
                                    size: 14, color: AppColors.primary),
                              ),
                            Text(
                              s,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: added
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
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
                        onSubmitted: _addBelief,
                        decoration: InputDecoration(
                          hintText: 'Type your own...',
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
                      onPressed: () => _addBelief(_beliefCtrl.text),
                      icon: const Icon(Icons.add_rounded),
                      style:
                          IconButton.styleFrom(backgroundColor: AppColors.primary),
                    ),
                  ],
                ),

                if (_errorText != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _errorText!,
                    style:
                        AppTextStyles.bodySmall.copyWith(color: AppColors.error),
                  ),
                ],

                const SizedBox(height: AppSpacing.xl),
                const Divider(color: AppColors.border),
                const SizedBox(height: AppSpacing.xl),

                // ── Optional primary fear ────────────────────────────────────
                Text('Your biggest fear?', style: AppTextStyles.headlineMedium)
                    .animate()
                    .fadeIn(duration: 400.ms),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Pick the one that holds you back the most. You can always change it later.',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary),
                ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
                const SizedBox(height: AppSpacing.lg),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: _fearOptions.map((f) {
                    final selected = _fear == f;
                    return GestureDetector(
                      onTap: () =>
                          setState(() => _fear = selected ? null : f),
                      child: AnimatedContainer(
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
                            color:
                                selected ? AppColors.primary : AppColors.border,
                          ),
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusFull),
                        ),
                        child: Text(
                          f,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: selected
                                ? AppColors.primary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

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
                    onPressed: _tryNext,
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
