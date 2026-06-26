import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
/// Returns true if a link was created (regardless of whether the native share
/// sheet or the clipboard fallback was used).
Future<bool> shareInvite(
  BuildContext context,
  AccountabilityNotifier notifier, {
  String? name,
  String? email,
}) async {
  String link;
  try {
    link = await notifier.createInvite(
      partnerEmail: email ?? '',
      partnerName: name ?? '',
    );
  } catch (e) {
    debugPrint('shareInvite: createInvite failed: $e');
    if (context.mounted) {
      _showSnack(context, AppStrings.inviteCreateError, isError: true);
    }
    return false;
  }

  if (link.isEmpty) {
    debugPrint('shareInvite: createInvite returned an empty link');
    if (context.mounted) {
      _showSnack(context, AppStrings.inviteCreateError, isError: true);
    }
    return false;
  }

  // The link was created successfully. From here a failure to invoke the native
  // share sheet (unsupported platform, no user gesture on web, iPad origin,
  // missing plugin, etc.) must NOT look like a failed invite. Fall back to the
  // clipboard so the user always walks away with a usable link.
  final partnerLabel = (name != null && name.isNotEmpty) ? name : 'there';
  final shareText = AppStrings.inviteShareText(partnerLabel, link);

  // iPad requires an anchor rect for the share popover or the share sheet
  // throws. Derive it from the triggering context's render box.
  final box = context.findRenderObject() as RenderBox?;
  final sharePositionOrigin = (box != null && box.hasSize)
      ? box.localToGlobal(Offset.zero) & box.size
      : null;

  try {
    await Share.share(
      shareText,
      subject: AppStrings.inviteShareSubject,
      sharePositionOrigin: sharePositionOrigin,
    );
    if (context.mounted) {
      _showSnack(context, AppStrings.inviteCreatedSuccess);
    }
    return true;
  } catch (e) {
    debugPrint('shareInvite: native share failed, copying to clipboard: $e');
    await Clipboard.setData(ClipboardData(text: link));
    if (context.mounted) {
      _showSnack(context, AppStrings.inviteLinkCopied);
    }
    return true;
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
