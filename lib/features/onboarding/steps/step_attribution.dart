import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/shimmer_widget.dart';
import '../../../models/attribution_source.dart';
import '../../../providers/attribution_provider.dart';

/// Marketing attribution step: "How did you hear about us?"
///
/// Deliberately a single tap with no text entry and no reward attached. The
/// app stores sever the link between a marketing click and the resulting
/// install, and asking someone to carry a referral code across that gap
/// converts far worse than asking them to remember a person, which they just
/// did. Selecting an option records the answer and advances immediately.
///
/// The option list is remote-configured (see [attributionSourcesProvider]) so
/// a new referral partner can be added without an App Store release.
class StepAttribution extends ConsumerStatefulWidget {
  /// Pre-selected id when a deterministic source was already resolved, e.g.
  /// the Play Install Referrer on Android.
  final String? initialSourceId;

  /// Raw referrer payload to persist alongside the choice, when present.
  final String? sourceDetail;

  final void Function(String sourceId) onNext;
  final VoidCallback onBack;

  const StepAttribution({
    super.key,
    this.initialSourceId,
    this.sourceDetail,
    required this.onNext,
    required this.onBack,
  });

  @override
  ConsumerState<StepAttribution> createState() => _StepAttributionState();
}

class _StepAttributionState extends ConsumerState<StepAttribution> {
  String? _selectedId;
  bool _advancing = false;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.initialSourceId;
  }

  /// Records the choice, then advances after a beat so the selected state is
  /// visible rather than the screen appearing to jump on contact.
  Future<void> _select(AttributionSource source) async {
    if (_advancing) return;
    setState(() {
      _selectedId = source.id;
      _advancing = true;
    });

    // Fire and forget: a failed write must not stall onboarding.
    unawaited(
      ref
          .read(attributionServiceProvider)
          .record(source.id, detail: widget.sourceDetail),
    );

    await Future<void>.delayed(const Duration(milliseconds: 260));
    if (!mounted) return;
    widget.onNext(source.id);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final sourcesAsync = ref.watch(attributionSourcesProvider);

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPaddingH,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.xl),
                Text(
                  AppStrings.onboardingAttributionTitle,
                  style: AppTextStyles.headlineLarge,
                ).animate().fadeIn(duration: 400.ms),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  AppStrings.onboardingAttributionSubtitle,
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary),
                ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
                const SizedBox(height: AppSpacing.lg),
                sourcesAsync.when(
                  loading: () => const ShimmerList(count: 5, itemHeight: 56),
                  // The provider swallows its own errors and falls back to
                  // defaults, so this branch is defensive only.
                  error: (_, __) => _buildOptions(kDefaultAttributionSources),
                  data: _buildOptions,
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.screenPaddingH,
            AppSpacing.md,
            AppSpacing.screenPaddingH,
            bottomInset + AppSpacing.md,
          ),
          child: Row(
            children: [
              AppSecondaryButton(
                label: AppStrings.onboardingBack,
                width: 100,
                onPressed: _advancing ? null : widget.onBack,
              ),
            ],
          ).animate().fadeIn(delay: 300.ms, duration: 400.ms),
        ),
      ],
    );
  }

  Widget _buildOptions(List<AttributionSource> sources) {
    return Column(
      children: [
        for (var i = 0; i < sources.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _SourceTile(
              label: sources[i].label,
              isSelected: sources[i].id == _selectedId,
              onTap: () => _select(sources[i]),
            ),
          ).animate().fadeIn(
                delay: Duration(milliseconds: i * 50),
                duration: 300.ms,
              ),
      ],
    );
  }
}

class _SourceTile extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SourceTile({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryContainer
              : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.labelLarge.copyWith(
                  color: isSelected
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                size: 20,
                color: AppColors.primary,
              ),
          ],
        ),
      ),
    );
  }
}
