import 'package:confetti/confetti.dart';

/// App-wide lock so at most one confetti celebration ever animates at a time.
///
/// Several independent moments in the app (perfect day, flawless week, habit
/// milestone, goal completed) can each want to celebrate, and on occasion
/// several can become true within moments of each other — e.g. checking off
/// multiple habits/actions quickly. Without coordination each one plays its
/// own burst independently, which reads as confetti "double-firing." This
/// gate makes that impossible: if a burst is already playing or still within
/// the cooldown window, a new request is simply dropped — never queued or
/// deferred — so the user only ever sees one at a time.
class ConfettiGate {
  ConfettiGate._();

  static bool _isPlaying = false;

  /// Floor on how long the lock is held, regardless of the calling burst's
  /// own duration — keeps distinct genuine celebrations from chaining
  /// back-to-back when several land within moments of each other.
  static const Duration _minCooldown = Duration(seconds: 8);

  /// Plays [controller] only if nothing else is currently animating or within
  /// the cooldown window. Silently drops the request otherwise. [duration]
  /// should match the controller's own blast duration; the lock is held for
  /// at least [_minCooldown] so successive distinct events can't fire in
  /// rapid succession.
  static void play(ConfettiController controller, Duration duration) {
    if (_isPlaying) return;
    _isPlaying = true;
    controller.play();
    final lock = duration > _minCooldown ? duration : _minCooldown;
    Future.delayed(lock, () => _isPlaying = false);
  }
}
