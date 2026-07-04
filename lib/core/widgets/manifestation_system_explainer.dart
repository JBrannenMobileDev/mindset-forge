import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';
import '../constants/app_strings.dart';
import '../constants/app_text_styles.dart';
import 'app_button.dart';
import 'app_card.dart';

/// Static, educational explainer for the 4-layer manifestation system
/// (Subconscious -> Thoughts -> Actions -> Results). The single source of truth
/// for this content, shown both as an onboarding step and on-demand via
/// [showManifestationSystemSheet]. No profile/score dependency.
class ManifestationSystemExplainer extends StatelessWidget {
  /// When true, renders the title + intro header. The bottom sheet sets this
  /// false because it provides its own header treatment.
  final bool showHeader;

  const ManifestationSystemExplainer({super.key, this.showHeader = true});

  static const _layers = <_LayerData>[
    _LayerData(
      index: 1,
      name: AppStrings.manifestationLayer1Name,
      tagline: AppStrings.manifestationLayer1Tagline,
      description: AppStrings.manifestationLayer1Desc,
      fedBy: AppStrings.manifestationLayer1FedBy,
      book: AppStrings.manifestationLayer1Book,
      icon: Icons.auto_fix_high_rounded,
      color: AppColors.primary,
      container: AppColors.primaryContainer,
    ),
    _LayerData(
      index: 2,
      name: AppStrings.manifestationLayer2Name,
      tagline: AppStrings.manifestationLayer2Tagline,
      description: AppStrings.manifestationLayer2Desc,
      fedBy: AppStrings.manifestationLayer2FedBy,
      book: AppStrings.manifestationLayer2Book,
      icon: Icons.lightbulb_outline_rounded,
      color: AppColors.secondary,
      container: AppColors.secondaryContainer,
    ),
    _LayerData(
      index: 3,
      name: AppStrings.manifestationLayer3Name,
      tagline: AppStrings.manifestationLayer3Tagline,
      description: AppStrings.manifestationLayer3Desc,
      fedBy: AppStrings.manifestationLayer3FedBy,
      book: AppStrings.manifestationLayer3Book,
      icon: Icons.bolt_rounded,
      color: AppColors.warning,
      container: AppColors.warningContainer,
    ),
    _LayerData(
      index: 4,
      name: AppStrings.manifestationLayer4Name,
      tagline: AppStrings.manifestationLayer4Tagline,
      description: AppStrings.manifestationLayer4Desc,
      fedBy: AppStrings.manifestationLayer4FedBy,
      book: AppStrings.manifestationLayer4Book,
      icon: Icons.flag_rounded,
      color: AppColors.success,
      container: AppColors.successContainer,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];

    if (showHeader) {
      children.addAll([
        Text(AppStrings.manifestationSystemTitle, style: AppTextStyles.displaySmall)
            .animate()
            .fadeIn(duration: 350.ms),
        const SizedBox(height: AppSpacing.sm),
        Text(
          AppStrings.manifestationSystemIntro,
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
        ).animate().fadeIn(delay: 80.ms, duration: 350.ms),
        const SizedBox(height: AppSpacing.lg),
        const _QuoteBlock(
          quote: AppStrings.manifestationQuote,
          author: AppStrings.manifestationQuoteAuthor,
        ).animate().fadeIn(delay: 140.ms, duration: 350.ms),
        const SizedBox(height: AppSpacing.xl),
      ]);
    }

    for (var i = 0; i < _layers.length; i++) {
      final delay = Duration(milliseconds: 60 + i * 70);
      children.add(
        _TimelineTile(
          layer: _layers[i],
          isLast: i == _layers.length - 1,
        )
            .animate()
            .fadeIn(delay: delay, duration: 350.ms)
            .slideY(begin: 0.15, end: 0, delay: delay, duration: 350.ms),
      );
    }

    children.addAll([
      const SizedBox(height: AppSpacing.lg),
      const _InsightCard(
        icon: Icons.trending_up_rounded,
        title: AppStrings.manifestationUpstreamTitle,
        body: AppStrings.manifestationUpstreamBody,
        accent: AppColors.primary,
      ).animate().fadeIn(delay: 380.ms, duration: 350.ms),
      const SizedBox(height: AppSpacing.md),
      const _InsightCard(
        icon: Icons.bedtime_rounded,
        title: AppStrings.manifestationWindowTitle,
        body: AppStrings.manifestationWindowBody,
        accent: AppColors.warning,
      ).animate().fadeIn(delay: 440.ms, duration: 350.ms),
      const SizedBox(height: AppSpacing.xl),
      const _KeyCard().animate().fadeIn(delay: 500.ms, duration: 350.ms),
    ]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

/// Opens the explainer as a draggable bottom sheet with a "Got it" dismiss.
Future<void> showManifestationSystemSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    barrierColor: AppColors.scrim,
    isScrollControlled: true,
    useRootNavigator: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
    ),
    builder: (sheetContext) => DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (_, controller) => Column(
        children: [
          const SizedBox(height: AppSpacing.sm),
          const _DragHandle(),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: SingleChildScrollView(
              controller: controller,
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.xxl + MediaQuery.of(sheetContext).padding.bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _HeroBadge()
                      .animate()
                      .fadeIn(duration: 400.ms)
                      .scale(
                        begin: const Offset(0.85, 0.85),
                        end: const Offset(1, 1),
                        duration: 400.ms,
                        curve: Curves.easeOutBack,
                      ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    AppStrings.manifestationSystemTitle,
                    style: AppTextStyles.headlineMedium,
                  ).animate().fadeIn(delay: 80.ms, duration: 350.ms),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    AppStrings.manifestationSystemIntro,
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.textSecondary),
                  ).animate().fadeIn(delay: 140.ms, duration: 350.ms),
                  const SizedBox(height: AppSpacing.lg),
                  const _QuoteBlock(
                    quote: AppStrings.manifestationQuote,
                    author: AppStrings.manifestationQuoteAuthor,
                  ).animate().fadeIn(delay: 200.ms, duration: 350.ms),
                  const SizedBox(height: AppSpacing.xl),
                  const ManifestationSystemExplainer(showHeader: false),
                  const SizedBox(height: AppSpacing.xl),
                  AppPrimaryButton(
                    label: AppStrings.manifestationSystemCta,
                    onPressed: () => Navigator.of(sheetContext).pop(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Fixed grab handle pinned at the top of the sheet.
class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.border,
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        ),
      ),
    );
  }
}

/// Gradient icon badge that anchors the sheet header.
class _HeroBadge extends StatelessWidget {
  const _HeroBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        boxShadow: const [
          BoxShadow(color: AppColors.primaryGlow, blurRadius: 24),
        ],
      ),
      child: const Icon(Icons.insights_rounded, color: Colors.white, size: 28),
    );
  }
}

class _LayerData {
  final int index;
  final String name;
  final String tagline;
  final String description;
  final String fedBy;
  final String book;
  final IconData icon;
  final Color color;
  final Color container;

  const _LayerData({
    required this.index,
    required this.name,
    required this.tagline,
    required this.description,
    required this.fedBy,
    required this.book,
    required this.icon,
    required this.color,
    required this.container,
  });
}

/// A single step in the layer timeline: a numbered node on a continuous spine
/// with a lightened body to the right.
class _TimelineTile extends StatelessWidget {
  final _LayerData layer;
  final bool isLast;

  const _TimelineTile({required this.layer, required this.isLast});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Spine gutter: numbered node + connector running to the next node.
          SizedBox(
            width: 36,
            child: Column(
              children: [
                _LayerNode(
                  index: layer.index,
                  color: layer.color,
                  container: layer.container,
                ),
                if (!isLast)
                  const SizedBox(height: AppSpacing.xs),
                if (!isLast)
                  Expanded(
                    child: Container(width: 2, color: AppColors.border),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.xl),
              child: _LayerBody(layer: layer),
            ),
          ),
        ],
      ),
    );
  }
}

/// Circular numbered node on the timeline spine.
class _LayerNode extends StatelessWidget {
  final int index;
  final Color color;
  final Color container;

  const _LayerNode({
    required this.index,
    required this.color,
    required this.container,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: container,
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Text(
        '$index',
        style: AppTextStyles.labelLarge.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Lightened layer content: leads with name + tagline, demotes the supporting
/// detail (description, "fed by", book citation) so the timeline reads cleanly.
class _LayerBody extends StatelessWidget {
  final _LayerData layer;

  const _LayerBody({required this.layer});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(layer.name, style: AppTextStyles.headlineSmall),
            ),
            const SizedBox(width: AppSpacing.sm),
            Icon(layer.icon, size: 18, color: layer.color),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          layer.tagline,
          style: AppTextStyles.labelSmall.copyWith(color: layer.color),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          layer.description,
          style: AppTextStyles.bodySmall
              .copyWith(color: AppColors.textSecondary, height: 1.5),
        ),
        const SizedBox(height: AppSpacing.md),
        // Fed by — light inline row instead of a filled pill.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.add_circle_outline_rounded, size: 14, color: layer.color),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                'Fed by ${layer.fedBy}',
                style: AppTextStyles.labelSmall
                    .copyWith(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        // Book citation — light muted caption, no bordered box.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.menu_book_rounded, size: 14, color: AppColors.textMuted),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                layer.book,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textMuted,
                  height: 1.4,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuoteBlock extends StatelessWidget {
  final String quote;
  final String author;

  const _QuoteBlock({required this.quote, required this.author});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: const BoxDecoration(
        border: Border(
          left: BorderSide(color: AppColors.primary, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '"$quote"',
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.textPrimary,
              fontStyle: FontStyle.italic,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '- $author',
            style: AppTextStyles.labelSmall.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _KeyCard extends StatelessWidget {
  const _KeyCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      borderColor: AppColors.primary.withValues(alpha: 0.30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.vpn_key_rounded, size: 20, color: AppColors.primary),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  AppStrings.manifestationKeyTitle,
                  style: AppTextStyles.headlineSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            AppStrings.manifestationKeyBody,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Color accent;

  const _InsightCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      backgroundColor: AppColors.surface,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: accent),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.labelLarge),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  body,
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
