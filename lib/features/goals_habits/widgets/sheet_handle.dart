import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// Standard 40x4 bottom-sheet drag handle used across the app's modals.
class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
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
