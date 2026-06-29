import 'dart:ui';

import 'package:flutter/material.dart';

/// Full-bleed nebula backdrop shared across the auth flow (splash, login,
/// signup). Renders the purple-top / cyan-bottom nebula image with an optional
/// blur.
///
/// On the splash this stays sharp ([blurSigma] == 0) — it's only on screen
/// briefly during cold launch and its content sits on the calm centre band.
/// On the mobile login/signup screens a subtle blur ([blurSigma] > 0) pushes
/// the busy texture back so the form reads as the focus.
class NebulaBackground extends StatelessWidget {
  /// Gaussian blur sigma applied to the image. 0 leaves the nebula sharp.
  final double blurSigma;

  const NebulaBackground({super.key, this.blurSigma = 0});

  @override
  Widget build(BuildContext context) {
    const image = Image(
      image: AssetImage('assets/images/splash_nebula.jpg'),
      fit: BoxFit.cover,
      alignment: Alignment.center,
    );

    if (blurSigma <= 0) {
      return const Positioned.fill(child: image);
    }

    return Positioned.fill(
      child: ImageFiltered(
        // TileMode.clamp keeps the blur from sampling transparent pixels at the
        // edges, which would otherwise leave a faint dark border.
        imageFilter: ImageFilter.blur(
          sigmaX: blurSigma,
          sigmaY: blurSigma,
          tileMode: TileMode.clamp,
        ),
        child: image,
      ),
    );
  }
}
