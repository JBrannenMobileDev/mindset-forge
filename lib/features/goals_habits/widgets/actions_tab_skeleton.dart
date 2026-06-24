import 'package:flutter/material.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/widgets/shimmer_widget.dart';

/// Profile-loading skeleton shared by the Goals and Habits tabs. Mirrors the
/// dashboard skeleton: a short header bar followed by a few card placeholders.
class ActionsTabSkeleton extends StatelessWidget {
  const ActionsTabSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPaddingH,
        AppSpacing.lg,
        AppSpacing.screenPaddingH,
        100,
      ),
      children: const [
        ShimmerBox(width: 140, height: 16, borderRadius: AppSpacing.radiusSm),
        SizedBox(height: AppSpacing.md),
        ShimmerCard(height: 120),
        SizedBox(height: AppSpacing.md),
        ShimmerCard(height: 120),
        SizedBox(height: AppSpacing.md),
        ShimmerCard(height: 120),
      ],
    );
  }
}
