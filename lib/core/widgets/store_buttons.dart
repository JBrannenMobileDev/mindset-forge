import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_spacing.dart';
import '../constants/app_strings.dart';
import 'app_button.dart';

/// iOS App Store + Google Play buttons used wherever we direct web users to the
/// mobile app (download screen, web pricing gate). Opens the store URL in an
/// external browser/app and surfaces a snackbar on failure.
class StoreButtons extends StatelessWidget {
  const StoreButtons({super.key});

  Future<void> _launch(BuildContext context, String url) async {
    final parsed = Uri.parse(url);
    final ok = await canLaunchUrl(parsed);
    if (ok) {
      await launchUrl(parsed, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open $url')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppPrimaryButton(
          label: AppStrings.downloadIosCta,
          icon: Icons.apple_rounded,
          onPressed: () => _launch(context, AppStrings.iosAppStoreUrl),
        ),
        const SizedBox(height: AppSpacing.md),
        AppSecondaryButton(
          label: AppStrings.downloadAndroidCta,
          icon: Icons.shop_rounded,
          onPressed: () => _launch(context, AppStrings.androidPlayStoreUrl),
        ),
      ],
    );
  }
}
