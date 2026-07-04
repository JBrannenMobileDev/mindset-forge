import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/breakpoints.dart';

/// Standard 40x4 bottom-sheet drag handle used across the app's modals.
/// Hidden in centered dialog mode on wide viewports.
class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    if (Breakpoints.isWide(context)) return const SizedBox.shrink();
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.border,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
