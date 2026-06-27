import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/breakpoints.dart';

/// Shared layout shell for the auth flow (welcome / login / signup / download).
///
/// Viewport-driven, mirroring the rest of the app: on wide screens it renders a
/// branded [AuthBrandHero] beside a centered glass form pane; on mobile it
/// collapses to the familiar centered single column (an optional [mobileHeader]
/// brand is shown above the form there, since the side hero is hidden).
class AuthScaffold extends StatelessWidget {
  /// The main interactive content (form, CTAs, etc.) shown on the right on wide
  /// screens and as the centered column on mobile.
  final Widget form;

  /// Optional brand block shown above [form] on mobile only. On wide screens the
  /// brand lives in the side hero instead, so this is ignored there.
  final Widget? mobileHeader;

  /// Max width of the form pane card / mobile column.
  final double formMaxWidth;

  /// When true, paints the ambient brand glow behind the mobile column (used by
  /// the landing screen to preserve its hero backdrop).
  final bool mobileGlow;

  const AuthScaffold({
    super.key,
    required this.form,
    this.mobileHeader,
    this.formMaxWidth = 440,
    this.mobileGlow = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (Breakpoints.isWideWidth(constraints.maxWidth)) {
            return Row(
              children: [
                const Expanded(flex: 5, child: AuthBrandHero()),
                Expanded(
                  flex: 4,
                  child: _FormPane(maxWidth: formMaxWidth, child: form),
                ),
              ],
            );
          }

          final mobileColumn = SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenPaddingH,
                  vertical: AppSpacing.screenPaddingV,
                ),
                child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (mobileHeader != null) mobileHeader!,
                      form,
                    ],
                  ),
                ),
              ),
            ),
          );

          if (!mobileGlow) return mobileColumn;
          return Stack(
            children: [
              const Positioned.fill(child: _AmbientGlow()),
              mobileColumn,
            ],
          );
        },
      ),
    );
  }
}

/// Right-hand pane on wide screens: a vertically centered, width-capped,
/// scrollable glass card that floats over the page background.
class _FormPane extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const _FormPane({required this.child, required this.maxWidth});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.screenPaddingV,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 40,
                    offset: const Offset(0, 16),
                  ),
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.06),
                    blurRadius: 48,
                    spreadRadius: -8,
                  ),
                ],
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Full-height branded marketing panel shown on the left of the wide auth
/// layout: a layered aurora background with a left-aligned value proposition
/// and three feature highlights.
class AuthBrandHero extends StatelessWidget {
  const AuthBrandHero({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: _HeroBackground()),
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _BrandLockup()
                    .animate()
                    .fadeIn(duration: 500.ms)
                    .slideX(begin: -0.15, end: 0, duration: 500.ms),
                Expanded(
                  child: Center(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: const _HeroContent(),
                      ),
                    ),
                  ),
                ),
                Text(
                  AppStrings.authFooterNote,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textMuted),
                ).animate().fadeIn(delay: 700.ms, duration: 500.ms),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BrandLockup extends StatelessWidget {
  const _BrandLockup();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/images/splash_logo.png',
          width: 44,
          height: 44,
          fit: BoxFit.contain,
        ),
        const SizedBox(width: AppSpacing.sm),
        Text.rich(
          TextSpan(
            style: AppTextStyles.headlineSmall,
            children: const [
              TextSpan(text: AppStrings.appNamePrefix),
              TextSpan(
                text: AppStrings.appNameAccent,
                style: TextStyle(color: AppColors.primary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeroContent extends StatelessWidget {
  const _HeroContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppStrings.authEyebrow,
          style: AppTextStyles.overline.copyWith(
            color: AppColors.primary,
            letterSpacing: 1.6,
          ),
        )
            .animate()
            .fadeIn(delay: 150.ms, duration: 500.ms)
            .slideY(begin: 0.3, end: 0, delay: 150.ms, duration: 500.ms),
        const SizedBox(height: AppSpacing.md),
        Text(
          AppStrings.authHeadline,
          style: AppTextStyles.displayLarge.copyWith(height: 1.05),
        )
            .animate()
            .fadeIn(delay: 250.ms, duration: 600.ms)
            .slideY(begin: 0.25, end: 0, delay: 250.ms, duration: 600.ms),
        const SizedBox(height: AppSpacing.lg),
        Text(
          AppStrings.authSubheadline,
          style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textSecondary),
        ).animate().fadeIn(delay: 400.ms, duration: 600.ms),
        const SizedBox(height: AppSpacing.xxl),
        ..._features.asMap().entries.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                child: _HeroFeature(
                  icon: e.value.$1,
                  title: e.value.$2,
                  body: e.value.$3,
                )
                    .animate()
                    .fadeIn(
                      delay: (500 + e.key * 120).ms,
                      duration: 500.ms,
                    )
                    .slideX(
                      begin: 0.15,
                      end: 0,
                      delay: (500 + e.key * 120).ms,
                      duration: 500.ms,
                    ),
              ),
            ),
      ],
    );
  }

  static const List<(IconData, String, String)> _features = [
    (
      Icons.psychology_rounded,
      AppStrings.authFeature1Title,
      AppStrings.authFeature1Body,
    ),
    (
      Icons.wb_twilight_rounded,
      AppStrings.authFeature2Title,
      AppStrings.authFeature2Body,
    ),
    (
      Icons.track_changes_rounded,
      AppStrings.authFeature3Title,
      AppStrings.authFeature3Body,
    ),
  ];
}

class _HeroFeature extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _HeroFeature({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.primaryContainer,
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
          child: Icon(icon, size: 18, color: AppColors.primary),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.labelLarge),
              const SizedBox(height: 2),
              Text(
                body,
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Layered aurora backdrop for the wide hero: a base gradient, two offset
/// radial glows (violet + cyan), and a faint dot-grid texture.
class _HeroBackground extends StatelessWidget {
  const _HeroBackground();

  @override
  Widget build(BuildContext context) {
    return const Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.background, AppColors.surface],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-0.7, -0.8),
                radius: 1.1,
                colors: [AppColors.primaryGlow, Color(0x009B40FF)],
                stops: [0.0, 1.0],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.9, 0.95),
                radius: 0.95,
                colors: [AppColors.secondaryGlow, Color(0x0000E5FF)],
                stops: [0.0, 1.0],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: CustomPaint(painter: _DotGridPainter()),
        ),
      ],
    );
  }
}

class _DotGridPainter extends CustomPainter {
  const _DotGridPainter();

  static const double _spacing = 28.0;
  static const double _radius = 1.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.border.withValues(alpha: 0.35);
    for (double y = _spacing; y < size.height; y += _spacing) {
      for (double x = _spacing; x < size.width; x += _spacing) {
        canvas.drawCircle(Offset(x, y), _radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotGridPainter oldDelegate) => false;
}

/// The brand lockup itself (breathing logo mark + app name + tagline), without
/// any background. Reused as the mobile header on the landing screen.
class AuthBrandBlock extends StatelessWidget {
  const AuthBrandBlock({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _LogoMark(),
        const SizedBox(height: 28),
        Text.rich(
          TextSpan(
            style: AppTextStyles.displayMedium
                .copyWith(color: AppColors.textPrimary),
            children: const [
              TextSpan(text: AppStrings.appNamePrefix),
              TextSpan(
                text: AppStrings.appNameAccent,
                style: TextStyle(color: AppColors.primary),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Text(
          AppStrings.appTagline,
          textAlign: TextAlign.center,
          style:
              AppTextStyles.bodyLarge.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _AmbientGlow extends StatelessWidget {
  const _AmbientGlow();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.35),
          radius: 0.9,
          colors: [
            Color(0x269B40FF),
            Color(0x000A0A0F),
          ],
          stops: [0.0, 1.0],
        ),
      ),
    );
  }
}

class _LogoMark extends StatelessWidget {
  const _LogoMark();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.40),
                  blurRadius: 56,
                  spreadRadius: 8,
                ),
              ],
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scaleXY(
                begin: 0.88,
                end: 1.18,
                duration: 2000.ms,
                curve: Curves.easeInOut,
              )
              .fade(begin: 0.4, end: 1.0, duration: 2000.ms),
          Image.asset(
            'assets/images/splash_logo.png',
            width: 200,
            height: 200,
            fit: BoxFit.contain,
          ),
        ],
      ),
    );
  }
}
