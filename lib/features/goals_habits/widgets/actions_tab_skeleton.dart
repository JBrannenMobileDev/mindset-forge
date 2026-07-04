import 'package:flutter/material.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/widgets/shimmer_widget.dart';
import '../actions_layout.dart';

/// Profile-loading skeleton for Actions tabs. Mirrors mobile list shape or the
/// desktop column layout depending on [layoutContext].
class ActionsTabSkeleton extends StatelessWidget {
  final ActionsLayoutContext layoutContext;

  const ActionsTabSkeleton({
    super.key,
    this.layoutContext = ActionsLayoutContext.mobileTab,
  });

  @override
  Widget build(BuildContext context) {
    if (layoutContext == ActionsLayoutContext.mobileTab) {
      return ListView(
        padding: actionsTabPadding(layoutContext),
        children: const [
          ShimmerBox(
              width: 140, height: 16, borderRadius: AppSpacing.radiusSm),
          SizedBox(height: AppSpacing.md),
          ShimmerCard(height: 120),
          SizedBox(height: AppSpacing.md),
          ShimmerCard(height: 120),
          SizedBox(height: AppSpacing.md),
          ShimmerCard(height: 120),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ShimmerBox(
            width: 100, height: 12, borderRadius: AppSpacing.radiusSm),
        const SizedBox(height: AppSpacing.md),
        const ShimmerCard(height: 100),
        const SizedBox(height: AppSpacing.md),
        const ShimmerCard(height: 100),
      ],
    );
  }
}

/// Full-page desktop skeleton mirroring the Actions reflow grid.
class ActionsDesktopSkeleton extends StatelessWidget {
  const ActionsDesktopSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    Widget columnSkeleton() => const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShimmerBox(
                width: 80, height: 12, borderRadius: AppSpacing.radiusSm),
            SizedBox(height: AppSpacing.md),
            ShimmerCard(height: 120),
            SizedBox(height: AppSpacing.md),
            ShimmerCard(height: 100),
          ],
        );

    return LayoutBuilder(
      builder: (context, constraints) {
        final threeColumn =
            constraints.maxWidth >= kActionsThreeColumnMinWidth;
        final twoColumn = constraints.maxWidth >= kActionsTwoColumnMinWidth;

        final header = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ShimmerBox(
                width: 120, height: 28, borderRadius: AppSpacing.radiusSm),
            const SizedBox(height: AppSpacing.xs),
            const ShimmerBox(
                width: 160, height: 14, borderRadius: AppSpacing.radiusSm),
          ],
        );

        if (threeColumn) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              header,
              const SizedBox(height: AppSpacing.sectionGap),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: columnSkeleton()),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(flex: 3, child: columnSkeleton()),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(flex: 2, child: columnSkeleton()),
                ],
              ),
            ],
          );
        }

        if (twoColumn) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              header,
              const SizedBox(height: AppSpacing.sectionGap),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: columnSkeleton()),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      children: [
                        columnSkeleton(),
                        const SizedBox(height: AppSpacing.sectionGap),
                        columnSkeleton(),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            header,
            const SizedBox(height: AppSpacing.sectionGap),
            columnSkeleton(),
            const SizedBox(height: AppSpacing.sectionGap),
            columnSkeleton(),
            const SizedBox(height: AppSpacing.sectionGap),
            columnSkeleton(),
          ],
        );
      },
    );
  }
}
