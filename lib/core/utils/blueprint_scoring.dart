import '../constants/app_strings.dart';
import '../../models/user_profile.dart';
import 'app_date_utils.dart';

/// Calibration-window day math for the Mindset Blueprint.
///
/// The Blueprint stays exactly as self-rated on Day 0 through the 10-day
/// calibration window — no formula is blended into the displayed chart, since
/// behavioral signal is too sparse this early (and for several traits,
/// generally) to responsibly override a self-rating. The first real
/// adjustment happens via the weekly AI recalculation once calibration ends.
abstract final class BlueprintScoring {
  static const int defaultWindowDays = 10;

  static DateTime _graceAnchor() {
    final now = DateTime.now();
    final adjusted = now.hour < 4 ? now.subtract(const Duration(days: 1)) : now;
    return DateTime(adjusted.year, adjusted.month, adjusted.day);
  }

  static DateTime? _calibrationStartDate(UserProfile p) {
    final raw = p.blueprintCalibrationStartedAt;
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  /// Days since calibration began (0 on the start day).
  static int daysSinceCalibrationStart(UserProfile p) {
    final start = _calibrationStartDate(p);
    if (start == null) return 0;
    final anchor = DateTime(start.year, start.month, start.day);
    final today = _graceAnchor();
    final diff = today.difference(anchor).inDays;
    return diff < 0 ? 0 : diff;
  }

  /// 1-based day index inside the calibration window (day 1 = start day).
  static int calibrationDay(UserProfile p) => daysSinceCalibrationStart(p) + 1;

  /// True while the user is still inside the initial 10-day calibration window.
  static bool isCalibrating(UserProfile p,
      {int windowDays = defaultWindowDays}) {
    if (_calibrationStartDate(p) == null) return false;
    return daysSinceCalibrationStart(p) < windowDays - 1;
  }

  /// Status line for the last automatic update, shared by the Blueprint tab
  /// and the Mindset hub's Blueprint row so both stay consistent.
  static String updateStatusLine(UserProfile p) {
    final lastRaw = p.blueprintLastRecalculatedAt ?? p.mindsetBlueprintSnapshotAt;
    if (lastRaw == null || lastRaw.isEmpty) {
      return AppStrings.blueprintNextUpdateSunday;
    }
    final parsed = DateTime.tryParse(lastRaw);
    if (parsed == null) return AppStrings.blueprintNextUpdateSunday;
    return '${AppStrings.blueprintLastUpdated(AppDateUtils.formatRelative(parsed))} · ${AppStrings.blueprintNextUpdateSunday}';
  }
}
