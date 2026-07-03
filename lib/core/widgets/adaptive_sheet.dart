import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';
import '../utils/breakpoints.dart';

/// Shows a modal that adapts to the viewport: a slide-up bottom sheet on narrow
/// (phone/native) widths and a centered, bounded dialog on wide (tablet/desktop
/// web) widths. The same [builder] content is reused for both — sheet content
/// built with `mainAxisSize: MainAxisSize.min` and internal scrolling drops
/// straight into the dialog.
Future<T?> showAdaptiveSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool useRootNavigator = true,
  double dialogMaxWidth = 560,
}) {
  if (Breakpoints.isWide(context)) {
    return showDialog<T>(
      context: context,
      useRootNavigator: useRootNavigator,
      barrierColor: AppColors.scrim,
      builder: (dialogContext) => Dialog(
        backgroundColor: AppColors.surface,
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          side: const BorderSide(color: AppColors.border),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: dialogMaxWidth,
            maxHeight: MediaQuery.of(dialogContext).size.height * 0.9,
          ),
          child: builder(dialogContext),
        ),
      ),
    );
  }

  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppSpacing.radiusXl),
      ),
    ),
    builder: builder,
  );
}
