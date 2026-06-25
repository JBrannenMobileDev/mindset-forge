import 'package:flutter/foundation.dart';
import '../../models/daily_completion.dart';
import '../../models/user_profile.dart';
import '../utils/app_date_utils.dart';
import 'notification_service.dart';

/// A single actionable routine item the user still has to do, with the in-app
/// route a reminder should deep-link to.
class _Item {
  final String label;
  final String route;
  const _Item(this.label, this.route);
}

/// Decides which local reminders to schedule and what they say, then hands the
/// concrete times to [NotificationService]. Re-run on every app resume so
/// already-completed items are suppressed and times stay fresh.
///
/// Strategy:
/// - Morning + evening routine reminders are scheduled as a rolling 7-day
///   window of one-shots (so they keep firing even if the app isn't opened),
///   with today's instance suppressed when its items are already done.
/// - Streak protection is today-only (it depends on today's live state) and,
///   when it fires, replaces today's evening reminder to honour the 2/day cap.
class NotificationScheduler {
  final NotificationService _service;
  NotificationScheduler(this._service);

  static const int _morningBase = 1000; // + day offset (0..6)
  static const int _eveningBase = 2000; // + day offset (0..6)
  static const int _streakId = 3000; // today only
  static const int _windowDays = 7;
  static const int _streakReminderAt = 5; // need <5/8 today to be "at risk"
  static const int _minStreakToProtect = 2;

  /// Cancels everything we own, then reschedules from the current profile.
  Future<void> rescheduleAll(UserProfile profile) async {
    await _cancelAllReminders();
    final prefs = profile.notificationPrefs;
    if (!prefs.masterEnabled) return;

    final now = DateTime.now();
    final today = _todayCompletion(profile);

    final streakScheduledToday = await _scheduleStreak(profile, now, today);

    if (prefs.routineEnabled) {
      await _scheduleRoutineWindow(profile, now, today, streakScheduledToday);
    }
  }

  /// Convenience: clear all reminders (e.g. on logout).
  Future<void> cancelEverything() => _cancelAllReminders();

  // ── Streak protection ─────────────────────────────────────────────────────

  Future<bool> _scheduleStreak(
      UserProfile profile, DateTime now, DailyCompletion today) async {
    final prefs = profile.notificationPrefs;
    if (!prefs.streakEnabled) return false;
    if (today.completedCount >= _streakReminderAt) return false;

    final streak = profile.currentStreak;
    if (streak < _minStreakToProtect) return false;

    final when = _atMinutes(now, prefs.streakReminderMinutes);
    if (!when.isAfter(now)) return false;

    // Streak protection is allowed to cross quiet hours by design.
    await _service.scheduleAt(
      id: _streakId,
      when: when,
      title: 'Keep your $streak-day streak alive',
      body:
          "You're close. One more practice before midnight keeps your streak going.",
      category: 'streak',
      route: '/dashboard',
    );
    return true;
  }

  // ── Routine window ────────────────────────────────────────────────────────

  Future<void> _scheduleRoutineWindow(
    UserProfile profile,
    DateTime now,
    DailyCompletion today,
    bool streakScheduledToday,
  ) async {
    final prefs = profile.notificationPrefs;
    final morningMin = _morningMinutes(profile);
    final eveningMin = _eveningMinutes(profile);
    final base = DateTime(now.year, now.month, now.day);

    for (int offset = 0; offset < _windowDays; offset++) {
      final day = base.add(Duration(days: offset));

      // ── Morning ──
      final mWhen = _atMinutes(day, morningMin);
      if (!prefs.isWithinQuietHours(morningMin) && mWhen.isAfter(now)) {
        if (offset == 0) {
          final items = _morningItems(today, profile.journalPreference);
          if (items.isNotEmpty) {
            await _service.scheduleAt(
              id: _morningBase + offset,
              when: mWhen,
              title: 'Good morning',
              body: 'Start your day: ${items.first.label}.',
              category: 'routine',
              route: items.first.route,
            );
          }
        } else {
          await _service.scheduleAt(
            id: _morningBase + offset,
            when: mWhen,
            title: 'Good morning',
            body: 'Begin your morning practice.',
            category: 'routine',
            route: '/dashboard',
          );
        }
      }

      // ── Evening ── (today's is dropped if the streak reminder is firing)
      final eWhen = _atMinutes(day, eveningMin);
      final skipEveningToday = offset == 0 && streakScheduledToday;
      if (!skipEveningToday &&
          !prefs.isWithinQuietHours(eveningMin) &&
          eWhen.isAfter(now)) {
        if (offset == 0) {
          final items = _eveningItems(today, profile.journalPreference);
          if (items.isNotEmpty) {
            await _service.scheduleAt(
              id: _eveningBase + offset,
              when: eWhen,
              title: 'Evening check-in',
              body: 'Close out your day: ${items.first.label}.',
              category: 'routine',
              route: items.first.route,
            );
          }
        } else {
          await _service.scheduleAt(
            id: _eveningBase + offset,
            when: eWhen,
            title: 'Evening check-in',
            body: 'Wind down with your evening practice.',
            category: 'routine',
            route: '/dashboard',
          );
        }
      }
    }
  }

  // ── Incomplete-item resolution ────────────────────────────────────────────

  List<_Item> _morningItems(DailyCompletion c, String journalPref) {
    final items = <_Item>[];
    if (!c.identityRead) {
      items.add(const _Item('read your identity statement', '/mindset'));
    }
    if (!c.affirmationsMorning) {
      items.add(const _Item('morning affirmations', '/affirmations'));
    }
    if (!c.futureSelfCompleted) {
      items.add(const _Item('your future-self visualization', '/future-self'));
    }
    if ((journalPref == 'morning' || journalPref == 'both') &&
        !c.journalCompleted) {
      items.add(const _Item("today's journal", '/journal/new'));
    }
    if (!c.dayPlanned) {
      items.add(const _Item('plan your day', '/actions'));
    }
    return items;
  }

  List<_Item> _eveningItems(DailyCompletion c, String journalPref) {
    final items = <_Item>[];
    if ((journalPref == 'evening' || journalPref == 'both') &&
        !c.journalCompleted) {
      items.add(const _Item("today's journal", '/journal/new'));
    }
    if (!c.affirmationsEvening) {
      items.add(const _Item('evening affirmations', '/affirmations'));
    }
    if (!c.chatCompleted) {
      items.add(const _Item('a check-in with your coach', '/chat'));
    }
    if (!c.habitsCompleted) {
      items.add(const _Item('your habits', '/actions'));
    }
    return items;
  }

  // ── Adaptive timing (Phase 3) ─────────────────────────────────────────────

  int _morningMinutes(UserProfile profile) {
    final prefs = profile.notificationPrefs;
    if (!prefs.morningIsDefault) return prefs.morningReminderMinutes;
    return _adaptiveMinutes(
          profile,
          const ['affirmationsMorning', 'identityRead', 'futureSelfCompleted'],
          maxMinute: 12 * 60,
        ) ??
        prefs.morningReminderMinutes;
  }

  int _eveningMinutes(UserProfile profile) {
    final prefs = profile.notificationPrefs;
    if (!prefs.eveningIsDefault) return prefs.eveningReminderMinutes;
    return _adaptiveMinutes(
          profile,
          const ['affirmationsEvening', 'chatCompleted'],
          minMinute: 12 * 60,
        ) ??
        prefs.eveningReminderMinutes;
  }

  /// Average historical completion time (minutes-since-midnight) for [keys] over
  /// recent days, shifted 15 minutes earlier. Returns null if there isn't enough
  /// signal to be trustworthy.
  int? _adaptiveMinutes(
    UserProfile profile,
    List<String> keys, {
    int minMinute = 0,
    int maxMinute = 24 * 60,
    int minSamples = 4,
  }) {
    final recent = [...profile.dailyCompletions]
      ..sort((a, b) => b.date.compareTo(a.date));
    final sample = recent.take(14);
    final mins = <int>[];
    for (final c in sample) {
      for (final k in keys) {
        final iso = c.completionTimes[k];
        if (iso == null) continue;
        final t = DateTime.tryParse(iso);
        if (t == null) continue;
        final m = t.hour * 60 + t.minute;
        if (m >= minMinute && m < maxMinute) mins.add(m);
      }
    }
    if (mins.length < minSamples) return null;
    final avg = mins.reduce((a, b) => a + b) ~/ mins.length;
    return (avg - 15).clamp(0, 1439);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  DailyCompletion _todayCompletion(UserProfile profile) {
    final key = AppDateUtils.todayString();
    return profile.dailyCompletions.firstWhere(
      (c) => c.date == key,
      orElse: DailyCompletion.forToday,
    );
  }

  DateTime _atMinutes(DateTime day, int minutes) {
    return DateTime(day.year, day.month, day.day, minutes ~/ 60, minutes % 60);
  }

  Future<void> _cancelAllReminders() async {
    try {
      for (int i = 0; i < _windowDays; i++) {
        await _service.cancel(_morningBase + i);
        await _service.cancel(_eveningBase + i);
      }
      await _service.cancel(_streakId);
    } catch (e) {
      debugPrint('NotificationScheduler: cancel failed: $e');
    }
  }
}
