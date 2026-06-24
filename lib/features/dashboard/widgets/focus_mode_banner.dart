import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../models/user_profile.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/daily_completion_provider.dart';

class FocusModeBanner extends ConsumerStatefulWidget {
  final UserProfile profile;

  const FocusModeBanner({super.key, required this.profile});

  @override
  ConsumerState<FocusModeBanner> createState() => _FocusModeBannerState();
}

class _FocusModeBannerState extends ConsumerState<FocusModeBanner> {
  bool _isCompleting = false;
  bool _showSuccess = false;
  bool _visible = true;
  bool _rendered = true;

  late final ConfettiController _confettiController;

  String get _todayStr {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  bool get _shouldShow {
    final p = widget.profile;
    return p.dailyFocusAction.isNotEmpty &&
        p.dailyFocusActionDate == _todayStr &&
        !p.dailyFocusActionCompleted;
  }

  @override
  void initState() {
    super.initState();
    _visible = _shouldShow;
    _rendered = _shouldShow;
    _confettiController =
        ConfettiController(duration: const Duration(milliseconds: 1600));
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(FocusModeBanner old) {
    super.didUpdateWidget(old);
    final wasShowing = old.profile.dailyFocusAction.isNotEmpty &&
        old.profile.dailyFocusActionDate == _todayStr &&
        !old.profile.dailyFocusActionCompleted;
    if (wasShowing && !_shouldShow && _visible && !_showSuccess && !_isCompleting) {
      setState(() => _visible = false);
    } else if (!wasShowing && _shouldShow && !_visible) {
      setState(() {
        _rendered = true;
        _visible = true;
        _showSuccess = false;
      });
    }
  }

  Future<void> _markComplete() async {
    setState(() => _isCompleting = true);
    try {
      final uid = ref.read(authStateProvider).valueOrNull?.uid;
      if (uid != null) {
        await ref.read(firestoreServiceProvider).updateUserField(uid, {
          'dailyFocusActionCompleted': true,
        });
      }
      await ref
          .read(dailyCompletionProvider.notifier)
          .toggle('priorityActionsCompleted', true);

      if (!mounted) return;
      setState(() {
        _isCompleting = false;
        _showSuccess = true;
      });
      _confettiController.play();

      Future.delayed(const Duration(milliseconds: 3500), () {
        if (mounted) setState(() => _visible = false);
      });
    } catch (e) {
      debugPrint('FocusModeBanner._markComplete failed: $e');
      if (mounted) setState(() => _isCompleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: _rendered
          ? AnimatedOpacity(
              opacity: _visible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              onEnd: () {
                if (!_visible && mounted) setState(() => _rendered = false);
              },
              child: Container(
                margin: const EdgeInsets.only(
                  left: AppSpacing.screenPaddingH,
                  right: AppSpacing.screenPaddingH,
                  bottom: AppSpacing.md,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: _showSuccess
                        ? [
                            AppColors.secondary.withValues(alpha: 0.12),
                            AppColors.primary.withValues(alpha: 0.06),
                          ]
                        : [
                            AppColors.primary.withValues(alpha: 0.18),
                            AppColors.secondary.withValues(alpha: 0.10),
                          ],
                  ),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  border: Border.all(
                    color: _showSuccess
                        ? AppColors.secondary.withValues(alpha: 0.35)
                        : AppColors.primary.withValues(alpha: 0.35),
                  ),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        child: _showSuccess
                            ? const _SuccessContent(key: ValueKey('success'))
                            : _FocusContent(
                                key: const ValueKey('focus'),
                                focusAction: widget.profile.dailyFocusAction,
                                isCompleting: _isCompleting,
                                onMarkComplete: _markComplete,
                              ),
                      ),
                    ),
                    // Confetti anchored at the top-center of the card —
                    // only mounted during the success state so it cannot
                    // fire during the default focus state.
                    if (_showSuccess)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: ConfettiWidget(
                            confettiController: _confettiController,
                            blastDirectionality: BlastDirectionality.explosive,
                            numberOfParticles: 40,
                            gravity: 0.22,
                            colors: const [
                              AppColors.primary,
                              AppColors.secondary,
                              AppColors.success,
                              Colors.white,
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.05, end: 0),
            )
          : const SizedBox(width: double.infinity),
    );
  }
}

// ── Focus content (default state) ─────────────────────────────────────────────

class _FocusContent extends StatelessWidget {
  final String focusAction;
  final bool isCompleting;
  final VoidCallback onMarkComplete;

  const _FocusContent({
    super.key,
    required this.focusAction,
    required this.isCompleting,
    required this.onMarkComplete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── "Today's Commitment" chip ─────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: 3,
          ),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.my_location_rounded,
                  color: AppColors.primary, size: 12),
              const SizedBox(width: 4),
              Text(
                AppStrings.focusCardChip,
                style:
                    AppTextStyles.overline.copyWith(color: AppColors.primary),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.sm),

        Text(AppStrings.focusCardTitle, style: AppTextStyles.headlineSmall),

        const SizedBox(height: AppSpacing.sm),

        Text(
          focusAction,
          style: AppTextStyles.bodyLarge.copyWith(
            height: 1.5,
            color: AppColors.textPrimary,
          ),
        ),

        const SizedBox(height: AppSpacing.lg),

        // ── Mark Complete button ──────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: isCompleting ? null : onMarkComplete,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(vertical: AppSpacing.md),
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(AppSpacing.radiusMd),
              ),
            ),
            icon: isCompleting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.check_circle_outline_rounded, size: 18),
            label: Text(
              isCompleting ? 'Saving…' : 'Mark Complete',
              style:
                  AppTextStyles.labelLarge.copyWith(color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Success content (celebration state) ───────────────────────────────────────

class _SuccessContent extends StatelessWidget {
  const _SuccessContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: AppSpacing.sm),
        const Icon(
          Icons.check_circle_rounded,
          color: AppColors.secondary,
          size: 56,
        )
            .animate()
            .scale(
              begin: const Offset(0.3, 0.3),
              end: const Offset(1.0, 1.0),
              curve: Curves.elasticOut,
              duration: 600.ms,
            )
            .fadeIn(duration: 200.ms),
        const SizedBox(height: AppSpacing.md),
        Text(
          AppStrings.focusCompletedTitle,
          style: AppTextStyles.headlineSmall.copyWith(
            color: AppColors.secondary,
          ),
          textAlign: TextAlign.center,
        ).animate().fadeIn(delay: 150.ms, duration: 300.ms),
        const SizedBox(height: AppSpacing.xs),
        Text(
          AppStrings.focusCompletedSubtitle,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ).animate().fadeIn(delay: 250.ms, duration: 300.ms),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }
}
