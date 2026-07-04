import 'package:confetti/confetti.dart';

/// App-wide lock so at most one confetti celebration ever animates at a time.
///
/// Several independent moments in the app (perfect day, flawless week, goal
/// completed) can each want to celebrate, and on occasion two can become true
/// in the same session. Without coordination each one plays its own burst
/// independently, which reads as confetti "double-firing." This gate makes
/// that impossible: if a burst is already playing, a new request is simply
/// dropped — never queued or deferred — so the user only ever sees one at a
/// time.
class ConfettiGate {
  ConfettiGate._();

  static bool _isPlaying = false;

  /// Plays [controller] only if nothing else is currently animating. Silently
  /// drops the request otherwise. [duration] should match the controller's
  /// own blast duration so the lock releases once the burst finishes.
  static void play(ConfettiController controller, Duration duration) {
    if (_isPlaying) return;
    _isPlaying = true;
    controller.play();
    Future.delayed(duration, () => _isPlaying = false);
  }
}
