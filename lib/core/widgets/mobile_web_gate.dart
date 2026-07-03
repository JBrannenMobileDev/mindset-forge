import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';
import '../constants/app_strings.dart';
import '../constants/app_text_styles.dart';
import 'app_button.dart';
import 'store_buttons.dart';

/// Full-screen gate shown to web visitors on small (phone-width) viewports.
///
/// The mobile layout is native-only: rather than rendering the phone UI in a
/// cramped browser window, web users below [AppSpacing.tabletBreakpoint] are
/// pointed to the app stores (with an "open the app" deep-link fallback for
/// people who already have it installed). Only used on web — the native app
/// always renders the real UI.
class MobileWebGate extends StatelessWidget {
  const MobileWebGate({super.key});

  Future<void> _openApp(BuildContext context) async {
    final uri = Uri.parse(AppStrings.appOpenDeepLink);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication)
        .catchError((_) => false);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.mobileGateOpenError)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPaddingH,
              vertical: AppSpacing.xxl,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _GateLogo(),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    AppStrings.mobileGateTitle,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.displaySmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    AppStrings.mobileGateSubtitle,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    AppStrings.mobileGateDownloadLabel,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.overline,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const StoreButtons(),
                  const SizedBox(height: AppSpacing.md),
                  AppTextButton(
                    label: AppStrings.mobileGateOpenCta,
                    onPressed: () => _openApp(context),
                  ),
                ],
              ).animate().fadeIn(duration: 400.ms),
            ),
          ),
        ),
      ),
    );
  }
}

/// The gradient wordmark badge, sized up as the gate's centered hero mark.
class _GateLogo extends StatelessWidget {
  const _GateLogo();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
            boxShadow: const [
              BoxShadow(color: AppColors.primaryGlow, blurRadius: 32),
            ],
          ),
          child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 40),
        ),
        const SizedBox(height: AppSpacing.md),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: AppStrings.appNamePrefix,
                style: AppTextStyles.headlineMedium,
              ),
              TextSpan(
                text: AppStrings.appNameAccent,
                style: AppTextStyles.headlineMedium
                    .copyWith(color: AppColors.primary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
