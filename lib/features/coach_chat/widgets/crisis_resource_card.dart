import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/crisis_resources.dart';

/// Surfaced beneath a coach message when a safety crisis is detected.
/// Replaces coaching with immediate, tappable support resources.
class CrisisResourceCard extends StatelessWidget {
  const CrisisResourceCard({super.key});

  Future<void> _launch(BuildContext context, String uri) async {
    final parsed = Uri.parse(uri);
    final ok = await canLaunchUrl(parsed);
    if (ok) {
      await launchUrl(parsed, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open $uri')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.favorite_rounded,
                  size: 18, color: AppColors.error),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'You don\'t have to go through this alone',
                  style: AppTextStyles.labelLarge
                      .copyWith(color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Please reach out right now. Help is free, confidential, and one tap away.',
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          ...CrisisResources.all.map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _ResourceButton(
                resource: r,
                onTap: () => _launch(context, r.uri),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResourceButton extends StatelessWidget {
  final CrisisResource resource;
  final VoidCallback onTap;

  const _ResourceButton({required this.resource, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceHighest,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    resource.label,
                    style: AppTextStyles.labelLarge
                        .copyWith(color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    resource.description,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
