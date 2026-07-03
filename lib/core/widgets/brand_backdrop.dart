import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'nebula_background.dart';

/// Shared branded backdrop used across the logged-out / onboarding flow: a
/// blurred full-bleed nebula, a dark scrim to lift foreground legibility, and
/// an ambient violet glow. Foreground content is layered on top via [child].
class BrandBackdrop extends StatelessWidget {
  /// Optional foreground laid over the backdrop layers.
  final Widget? child;

  /// Gaussian blur applied to the nebula image.
  final double blurSigma;

  const BrandBackdrop({super.key, this.child, this.blurSigma = 8});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        NebulaBackground(blurSigma: blurSigma),
        const Positioned.fill(child: _NebulaScrim()),
        const Positioned.fill(child: _AmbientGlow()),
        if (child != null) Positioned.fill(child: child!),
      ],
    );
  }
}

/// Soft dark scrim layered over the blurred nebula. Slightly darker at the
/// vertical edges (where the nebula is busiest) and lighter through the centre,
/// lifting foreground legibility without flattening the backdrop.
class _NebulaScrim extends StatelessWidget {
  const _NebulaScrim();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.background.withValues(alpha: 0.45),
            AppColors.background.withValues(alpha: 0.20),
            AppColors.background.withValues(alpha: 0.45),
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
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
