/// User-controllable notification preferences. Pure data — no Flutter/Firebase.
///
/// Times are stored as "minutes since local midnight" (0–1439) so they survive
/// JSON round-trips without timezone ambiguity and are trivial to compare.
class NotificationPrefs {
  // ── Sensible defaults (also used by the scheduler for adaptive-timing) ─────
  static const int defaultMorningMinutes = 8 * 60; // 08:00
  static const int defaultEveningMinutes = 20 * 60; // 20:00
  static const int defaultStreakMinutes = 21 * 60 + 30; // 21:30
  static const int defaultQuietStartMinutes = 21 * 60 + 30; // 21:30
  static const int defaultQuietEndMinutes = 7 * 60; // 07:00

  /// Master kill-switch. When false, no local reminders are scheduled.
  final bool masterEnabled;

  /// Per-category opt-outs.
  final bool routineEnabled;
  final bool streakEnabled;
  final bool partnerEnabled;
  final bool lifecycleEnabled;

  /// Reminder times (minutes since local midnight).
  final int morningReminderMinutes;
  final int eveningReminderMinutes;
  final int streakReminderMinutes;

  /// Quiet-hours window (minutes since local midnight). The window may wrap past
  /// midnight (start > end), e.g. 21:30 → 07:00.
  final int quietHoursStart;
  final int quietHoursEnd;

  /// Primary user's consent to let their accountability partner be notified
  /// when they slip. Defaults on — that is the point of accountability — but is
  /// disclosed at invite time and toggleable here.
  final bool notifyPartnerOnSlip;

  const NotificationPrefs({
    this.masterEnabled = true,
    this.routineEnabled = true,
    this.streakEnabled = true,
    this.partnerEnabled = true,
    this.lifecycleEnabled = true,
    this.morningReminderMinutes = defaultMorningMinutes,
    this.eveningReminderMinutes = defaultEveningMinutes,
    this.streakReminderMinutes = defaultStreakMinutes,
    this.quietHoursStart = defaultQuietStartMinutes,
    this.quietHoursEnd = defaultQuietEndMinutes,
    this.notifyPartnerOnSlip = true,
  });

  /// True when [minutes] (since midnight) falls inside the quiet-hours window.
  /// Handles windows that wrap past midnight.
  bool isWithinQuietHours(int minutes) {
    if (quietHoursStart == quietHoursEnd) return false;
    if (quietHoursStart < quietHoursEnd) {
      return minutes >= quietHoursStart && minutes < quietHoursEnd;
    }
    // Wraps midnight (e.g. 21:30 → 07:00).
    return minutes >= quietHoursStart || minutes < quietHoursEnd;
  }

  /// True when the morning/evening times are still at their defaults, so the
  /// scheduler is free to apply adaptive timing learned from the user's habits.
  bool get morningIsDefault => morningReminderMinutes == defaultMorningMinutes;
  bool get eveningIsDefault => eveningReminderMinutes == defaultEveningMinutes;

  NotificationPrefs copyWith({
    bool? masterEnabled,
    bool? routineEnabled,
    bool? streakEnabled,
    bool? partnerEnabled,
    bool? lifecycleEnabled,
    int? morningReminderMinutes,
    int? eveningReminderMinutes,
    int? streakReminderMinutes,
    int? quietHoursStart,
    int? quietHoursEnd,
    bool? notifyPartnerOnSlip,
  }) {
    return NotificationPrefs(
      masterEnabled: masterEnabled ?? this.masterEnabled,
      routineEnabled: routineEnabled ?? this.routineEnabled,
      streakEnabled: streakEnabled ?? this.streakEnabled,
      partnerEnabled: partnerEnabled ?? this.partnerEnabled,
      lifecycleEnabled: lifecycleEnabled ?? this.lifecycleEnabled,
      morningReminderMinutes:
          morningReminderMinutes ?? this.morningReminderMinutes,
      eveningReminderMinutes:
          eveningReminderMinutes ?? this.eveningReminderMinutes,
      streakReminderMinutes:
          streakReminderMinutes ?? this.streakReminderMinutes,
      quietHoursStart: quietHoursStart ?? this.quietHoursStart,
      quietHoursEnd: quietHoursEnd ?? this.quietHoursEnd,
      notifyPartnerOnSlip: notifyPartnerOnSlip ?? this.notifyPartnerOnSlip,
    );
  }

  factory NotificationPrefs.fromJson(Map<String, dynamic> json) {
    return NotificationPrefs(
      masterEnabled: json['masterEnabled'] as bool? ?? true,
      routineEnabled: json['routineEnabled'] as bool? ?? true,
      streakEnabled: json['streakEnabled'] as bool? ?? true,
      partnerEnabled: json['partnerEnabled'] as bool? ?? true,
      lifecycleEnabled: json['lifecycleEnabled'] as bool? ?? true,
      morningReminderMinutes:
          (json['morningReminderMinutes'] as num?)?.toInt() ??
              defaultMorningMinutes,
      eveningReminderMinutes:
          (json['eveningReminderMinutes'] as num?)?.toInt() ??
              defaultEveningMinutes,
      streakReminderMinutes:
          (json['streakReminderMinutes'] as num?)?.toInt() ??
              defaultStreakMinutes,
      quietHoursStart: (json['quietHoursStart'] as num?)?.toInt() ??
          defaultQuietStartMinutes,
      quietHoursEnd:
          (json['quietHoursEnd'] as num?)?.toInt() ?? defaultQuietEndMinutes,
      notifyPartnerOnSlip: json['notifyPartnerOnSlip'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'masterEnabled': masterEnabled,
        'routineEnabled': routineEnabled,
        'streakEnabled': streakEnabled,
        'partnerEnabled': partnerEnabled,
        'lifecycleEnabled': lifecycleEnabled,
        'morningReminderMinutes': morningReminderMinutes,
        'eveningReminderMinutes': eveningReminderMinutes,
        'streakReminderMinutes': streakReminderMinutes,
        'quietHoursStart': quietHoursStart,
        'quietHoursEnd': quietHoursEnd,
        'notifyPartnerOnSlip': notifyPartnerOnSlip,
      };
}
