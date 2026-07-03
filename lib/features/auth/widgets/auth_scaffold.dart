import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/breakpoints.dart';
import '../../../core/widgets/brand_backdrop.dart';
import '../../../core/widgets/glass_pane.dart';

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

  const AuthScaffold({
    super.key,
    required this.form,
    this.mobileHeader,
    this.formMaxWidth = 440,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (Breakpoints.isWideWidth(constraints.maxWidth)) {
            // Wide/web shares the mobile auth backdrop: full-bleed nebula,
            // softened with a blur + dark scrim and the ambient brand glow, so
            // the whole logged-out flow (splash → welcome → login) reads as one
            // brand. The hero and glass form float over it.
            return BrandBackdrop(
              child: Row(
                children: [
                  const Expanded(flex: 5, child: AuthBrandHero()),
                  Expanded(
                    flex: 4,
                    child: _FormPane(maxWidth: formMaxWidth, child: form),
                  ),
                ],
              ),
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
                      if (mobileHeader != null) ...[
                        mobileHeader!,
                        const SizedBox(height: AppSpacing.xl),
                      ],
                      GlassPane(child: form)
                          .animate()
                          .fadeIn(duration: 400.ms)
                          .slideY(begin: 0.04, end: 0, duration: 400.ms),
                    ],
                  ),
                ),
              ),
            ),
          );

          // Mobile auth screens share the splash backdrop: full-bleed nebula
          // image, here softened with a subtle blur and a dark scrim so the
          // form reads as the focus, with the ambient brand glow on top.
          return BrandBackdrop(child: mobileColumn);
        },
      ),
    );
  }
}

/// Right-hand pane on wide screens: a vertically centered, width-capped,
/// scrollable frosted-glass card that floats over the shared nebula backdrop —
/// the same `GlassPane` used on mobile, for a consistent brand.
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
            child: GlassPane(child: child),
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
        // The nebula + glow come from the shared page backdrop now; the hero
        // only lays a soft left-side scrim so its value-prop text stays legible
        // over the busier left region of the nebula.
        const Positioned.fill(child: _HeroLegibilityScrim()),
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

/// Soft left-to-right dark scrim behind the wide hero content. The shared page
/// nebula/glow provide the colour; this only lifts text legibility over the
/// busier left region, fading to transparent toward the form so the nebula
/// still shows through the centre.
class _HeroLegibilityScrim extends StatelessWidget {
  const _HeroLegibilityScrim();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            AppColors.background.withValues(alpha: 0.55),
            AppColors.background.withValues(alpha: 0.20),
            Colors.transparent,
          ],
          stops: const [0.0, 0.55, 1.0],
        ),
      ),
    );
  }
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
        const AuthLogoMark(size: 200),
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

/// Compact brand header for the mobile login / signup screens: a small
/// breathing logo mark above the wordmark, centered. Keeps those form-heavy
/// screens from feeling top-heavy while still sitting the brand above the
/// glass card for a consistent composition.
class AuthBrandHeaderCompact extends StatelessWidget {
  const AuthBrandHeaderCompact({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const AuthLogoMark(size: 88),
        const SizedBox(height: AppSpacing.sm),
        Text.rich(
          TextSpan(
            style: AppTextStyles.headlineMedium
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
      ],
    );
  }
}

/// Breathing brain logo mark shared across the auth flow (splash brand block,
/// login, signup). The brain PNG fills [size]; the glow halo and shadow scale
/// proportionally so it reads consistently at any size.
class AuthLogoMark extends StatelessWidget {
  /// Edge length of the (square) logo. The PNG has generous transparent
  /// padding baked in, so the visible brain mark is roughly 40% of this.
  final double size;

  const AuthLogoMark({super.key, this.size = 160});

  @override
  Widget build(BuildContext context) {
    final glowSize = size * 0.6;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: glowSize,
            height: glowSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.40),
                  blurRadius: size * 0.28,
                  spreadRadius: size * 0.04,
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
            width: size,
            height: size,
            fit: BoxFit.contain,
          ),
        ],
      ),
    );
  }
}
