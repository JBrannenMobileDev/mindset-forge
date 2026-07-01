import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';
import '../constants/app_text_styles.dart';
import '../../providers/consent_provider.dart';

/// Bottom cookie-consent banner shown on the web app until the user accepts or
/// declines non-essential (analytics) cookies. Renders nothing on mobile or
/// once a choice has been made.
class CookieConsentBanner extends ConsumerWidget {
  const CookieConsentBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!kIsWeb) return const SizedBox.shrink();
    final consent = ref.watch(consentProvider);
    if (consent != AnalyticsConsent.unknown) return const SizedBox.shrink();

    final notifier = ref.read(consentProvider.notifier);

    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'We value your privacy',
                    style: AppTextStyles.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    children: [
                      Text(
                        'We use essential cookies to run the app and, with your '
                        'consent, analytics cookies to understand usage and '
                        'improve MindsetForge. See our ',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textSecondary),
                      ),
                      GestureDetector(
                        onTap: () => context.push('/privacy'),
                        child: Text(
                          'Privacy Policy',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.primary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      Text(
                        '.',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: notifier.decline,
                        child: Text(
                          'Decline',
                          style: AppTextStyles.labelLarge
                              .copyWith(color: AppColors.textSecondary),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _AcceptButton(onPressed: notifier.accept),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AcceptButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _AcceptButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm + 2,
          ),
          child: Text(
            'Accept',
            style: AppTextStyles.labelLarge.copyWith(color: Colors.white),
          ),
        ),
      ),
    );
  }
}
