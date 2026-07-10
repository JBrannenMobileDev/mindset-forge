import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';

/// Branded system UI overlay styles (status bar, navigation bar).
abstract final class AppSystemChrome {
  /// Dark-app default: transparent status bar, white icons on [AppColors.background].
  static const SystemUiOverlayStyle dark = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: AppColors.background,
    systemNavigationBarIconBrightness: Brightness.light,
  );

  static Future<void> applyDark() async {
    SystemChrome.setSystemUIOverlayStyle(dark);
  }

  static Future<void> setEdgeToEdge() => SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.edgeToEdge,
      );
}
