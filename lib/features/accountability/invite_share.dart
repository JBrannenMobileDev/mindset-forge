import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../providers/accountability_provider.dart';

/// Creates a partner invite link and opens the OS share sheet so the user can
/// send it via their own apps. Shows a success/error SnackBar.
///
/// Takes the [AccountabilityNotifier] directly so it works from both widgets
/// (`WidgetRef`) and providers (`Ref`).
///
/// Returns true if a link was created and the share sheet was presented.
Future<bool> shareInvite(
  BuildContext context,
  AccountabilityNotifier notifier, {
  String? name,
  String? email,
}) async {
  try {
    final link = await notifier.createInvite(
      partnerEmail: email ?? '',
      partnerName: name ?? '',
    );
    if (!context.mounted) return false;

    if (link.isEmpty) {
      _showSnack(context, AppStrings.inviteCreateError, isError: true);
      return false;
    }

    final partnerLabel = (name != null && name.isNotEmpty) ? name : 'there';
    await Share.share(
      AppStrings.inviteShareText(partnerLabel, link),
      subject: AppStrings.inviteShareSubject,
    );
    if (!context.mounted) return true;

    _showSnack(context, AppStrings.inviteCreatedSuccess);
    return true;
  } catch (_) {
    if (!context.mounted) return false;
    _showSnack(context, AppStrings.inviteCreateError, isError: true);
    return false;
  }
}

void _showSnack(BuildContext context, String message, {bool isError = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: isError ? AppColors.error : AppColors.surfaceElevated,
      content: Text(message),
    ),
  );
}
