import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/nebula_background.dart';

/// Splash intentionally mounts twice on cold launch — once directly by
/// `_InitApp` (`main.dart`) while startup steps run, then again as the routed
/// `SplashScreen` while auth/profile resolve — so the native-to-Flutter
/// handoff is seamless. The one-shot entrance animation below should only
/// ever play once per process; otherwise a slow startup step lets it finish
/// before the second mount replays it, making the splash visibly "reload."
bool _introAnimationPlayed = false;

/// Pure-presentation branded splash visuals: dark background, glowing logo,
/// app name + tagline, and a subtle loading indicator.
///
/// Intentionally free of providers and navigation so it can render both before
/// the [ProviderScope] is mounted (during app init) and inside the routed
/// [SplashScreen]. This keeps the cold-launch sequence visually seamless.
class SplashView extends StatelessWidget {
  /// When false, hides the bottom loading dots (e.g. for a static preview).
  final bool showProgress;

  const SplashView({super.key, this.showProgress = true});

  @override
  Widget build(BuildContext context) {
    final animateIntro = !_introAnimationPlayed;
    _introAnimationPlayed = true;

    final wordmark = Text.rich(
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
    );

    final tagline = Text(
      AppStrings.appTagline,
      textAlign: TextAlign.center,
      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Full-screen nebula backdrop — purple top, cyan bottom, calm dark
          // centre band — matching the store feature graphic / app icon. Kept
          // sharp here (no blur) since the splash is brief and its content sits
          // on the calm centre band.
          const NebulaBackground(),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _LogoMark(animateIntro: animateIntro),
                const SizedBox(height: 28),
                animateIntro
                    ? wordmark
                        .animate()
                        .fadeIn(delay: 400.ms, duration: 600.ms)
                        .slideY(
                            begin: 0.3,
                            end: 0,
                            delay: 400.ms,
                            duration: 600.ms)
                    : wordmark,
                const SizedBox(height: 10),
                animateIntro
                    ? tagline.animate().fadeIn(delay: 600.ms, duration: 600.ms)
                    : tagline,
              ],
            ),
          ),
          if (showProgress)
            Positioned(
              left: 0,
              right: 0,
              bottom: 56,
              child: animateIntro
                  ? const _LoadingDots()
                      .animate()
                      .fadeIn(delay: 900.ms, duration: 600.ms)
                  : const _LoadingDots(),
            ),
        ],
      ),
    );
  }
}

class _LogoMark extends StatelessWidget {
  final bool animateIntro;

  const _LogoMark({required this.animateIntro});

  @override
  Widget build(BuildContext context) {
    final glyph = Image.asset(
      'assets/images/splash_logo.png',
      width: 200,
      height: 200,
      fit: BoxFit.contain,
    );

    return SizedBox(
      // The glyph asset has generous padding baked in (~60% of the square is
      // transparent), so a 200px container yields a visually ~80px brain mark —
      // matching what the native splash shows.
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Breathing glow halo — same violet primary glow as in-app cards.
          // Always looping (ambient, not a one-shot reveal), so it keeps
          // running unconditionally across both splash mounts.
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
          // Brain glyph — transparent PNG, no clip, no rounding, matches native.
          animateIntro
              ? glyph.animate().fadeIn(duration: 600.ms).scale(
                    begin: const Offset(0.85, 0.85),
                    end: const Offset(1, 1),
                    duration: 600.ms,
                    curve: Curves.easeOut,
                  )
              : glyph,
        ],
      ),
    );
  }
}

class _LoadingDots extends StatelessWidget {
  const _LoadingDots();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        return Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 5),
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
        )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .fade(
              begin: 0.25,
              end: 1.0,
              duration: 600.ms,
              delay: (i * 200).ms,
              curve: Curves.easeInOut,
            )
            .scaleXY(begin: 0.85, end: 1.15, duration: 600.ms);
      }),
    );
  }
}
