import 'package:flutter/material.dart';

abstract final class AppColors {
  // Background layers
  static const Color background = Color(0xFF0A0A0F);
  static const Color surface = Color(0xFF13131A);
  static const Color surfaceElevated = Color(0xFF1C1C27);
  static const Color surfaceHighest = Color(0xFF252535);
  static const Color border = Color(0xFF2A2A3A);
  static const Color borderSubtle = Color(0xFF1E1E2E);

  // Primary — violet-magenta
  static const Color primary = Color(0xFF9B40FF);
  static const Color primaryLight = Color(0xFFB56FFF);
  static const Color primaryDark = Color(0xFF7028CC);
  static const Color primaryGlow = Color(0x339B40FF);
  static const Color primaryContainer = Color(0x1A9B40FF);

  // Secondary — electric cyan
  static const Color secondary = Color(0xFF00E5FF);
  static const Color secondaryGlow = Color(0x3300E5FF);
  static const Color secondaryContainer = Color(0x1A00E5FF);

  // Semantic
  static const Color warning = Color(0xFFFFB547);
  static const Color warningContainer = Color(0x1AFFB547);
  static const Color error = Color(0xFFFF5E6C);
  static const Color errorContainer = Color(0x1AFF5E6C);
  static const Color success = Color(0xFF4CAF7D);
  static const Color successContainer = Color(0x1A4CAF7D);

  // Text
  static const Color textPrimary = Color(0xFFF0EFF8);
  static const Color textSecondary = Color(0xFF8B8BA0);
  static const Color textMuted = Color(0xFF4A4A60);
  static const Color textDisabled = Color(0xFF333345);

  // Future Self warm tones
  static const Color futureSelfBackground = Color(0xFF0F0A0A);
  static const Color futureSelfSurface = Color(0xFF1A1010);
  static const Color futureSelfAccent = Color(0xFFD4A055);
  static const Color futureSelfGlow = Color(0x33D4A055);

  // Category colors
  static const Color categoryCareer = Color(0xFF9B40FF);
  static const Color categoryHealth = Color(0xFF4CAF7D);
  static const Color categoryRelationships = Color(0xFFFF6B9D);
  static const Color categoryFinances = Color(0xFFFFB547);
  static const Color categoryPersonalGrowth = Color(0xFF00E5FF);
  static const Color categorySpirituality = Color(0xFF8B7CFF);
  static const Color categoryLearning = Color(0xFF4D9FFF);

  // Chart colors
  static const List<Color> chartGradient = [primary, secondary];
  static const Color chartGrid = Color(0xFF1E1E2E);
  static const Color chartAxisLabel = Color(0xFF4A4A60);

  // Shimmer
  static const Color shimmerBase = Color(0xFF1C1C27);
  static const Color shimmerHighlight = Color(0xFF2A2A3A);

  // Overlay
  static const Color scrim = Color(0xCC0A0A0F);
  static const Color frostedGlass = Color(0xE60A0A0F);
}
