import 'package:flutter_test/flutter_test.dart';
import 'package:mindsetforge/core/constants/app_strings.dart';
import 'package:mindsetforge/models/daily_completion.dart';
import 'package:mindsetforge/models/user_profile.dart';
import 'package:mindsetforge/models/widget_payload.dart';

/// A `DailyCompletion` with all 9 required items done (a perfect day).
DailyCompletion _perfect(String date) => DailyCompletion(
      date: date,
      habitsCompleted: true,
      dayPlanned: true,
      focusCompleted: true,
      affirmationsMorning: true,
      affirmationsEvening: true,
      futureSelfCompleted: true,
      journalCompleted: true,
      chatCompleted: true,
      identityRead: true,
    );

void main() {
  // Fixed reference times on 2026-06-27 across the three day phases.
  final morning = DateTime(2026, 6, 27, 9, 0);
  final midday = DateTime(2026, 6, 27, 14, 0); // transition phase
  final evening = DateTime(2026, 6, 27, 20, 0);
  const today = '2026-06-27';

  UserProfile profile({
    String focus = '',
    String focusDate = '',
    bool focusComplete = false,
    String journalPreference = 'both',
    List<DailyCompletion> completions = const [],
  }) {
    return UserProfile.create(
      uid: 'u1',
      email: 'a@b.com',
      displayName: 'Jordan Smith',
    ).copyWith(
      dailyFocusAction: focus,
      dailyFocusActionDate: focusDate,
      // Focus completion is now derived from the completed list.
      completedPriorityActions:
          focusComplete && focus.isNotEmpty ? [focus] : const [],
      journalPreference: journalPreference,
      dailyCompletions: completions,
    );
  }

  group('WidgetPayload next-action resolution (parity with hero arc)', () {
    test('morning, nothing done -> first morning step (Identity)', () {
      final p = WidgetPayload.fromProfile(profile(), now: morning);
      expect(p.state, 'morning');
      expect(p.accentKind, 'morning');
      expect(p.actionField, 'identityRead');
      expect(p.headline, 'Identity');
      expect(p.sessionLabel, 'MORNING SESSION');
      expect(p.deepLink, 'mindsetforge://action/identityRead');
      expect(p.canCompleteInWidget, false);
    });

    test('morning, morning routine done + focus open -> focus_open', () {
      final p = WidgetPayload.fromProfile(
        profile(
          focus: 'Ship the widget',
          focusDate: today,
          completions: [_perfect(today)],
        ),
        now: morning,
      );
      expect(p.state, 'focus_open');
      expect(p.accentKind, 'focus');
      expect(p.actionField, 'focus');
      expect(p.headline, 'Ship the widget');
      expect(p.canCompleteInWidget, true);
      expect(p.deepLink, 'mindsetforge://focus');
    });

    test('transition, no focus set -> set_focus', () {
      final p = WidgetPayload.fromProfile(profile(), now: midday);
      expect(p.state, 'set_focus');
      expect(p.accentKind, 'set_focus');
      expect(p.actionField, 'setFocus');
      expect(p.hasFocusToday, false);
      expect(p.focusText, '');
      expect(p.canCompleteInWidget, false);
      expect(p.deepLink, 'mindsetforge://focus');
    });

    test('transition, focus set + not complete -> focus_open with text', () {
      final p = WidgetPayload.fromProfile(
        profile(focus: 'Ship the widget', focusDate: today),
        now: midday,
      );
      expect(p.state, 'focus_open');
      expect(p.accentKind, 'focus');
      expect(p.hasFocusToday, true);
      expect(p.focusCompleted, false);
      expect(p.headline, 'Ship the widget');
      expect(p.focusText, 'Ship the widget');
      expect(p.canCompleteInWidget, true);
    });

    test('focus for an earlier day is not today -> set_focus at midday', () {
      final p = WidgetPayload.fromProfile(
        profile(focus: 'Ship the widget', focusDate: '2026-06-26'),
        now: midday,
      );
      expect(p.state, 'set_focus');
      expect(p.hasFocusToday, false);
      expect(p.focusText, '');
    });

    test('evening, routine unfinished -> first evening step', () {
      final p = WidgetPayload.fromProfile(
        profile(journalPreference: 'morning'),
        now: evening,
      );
      expect(p.state, 'evening');
      expect(p.accentKind, 'evening');
      // journal lives in the morning for this pref, so the first evening
      // required step is the evening affirmations session.
      expect(p.actionField, 'affirmationsEvening');
      expect(p.headline, 'Affirmations');
      expect(p.sessionLabel, 'EVENING SESSION');
      expect(p.deepLink, 'mindsetforge://action/affirmationsEvening');
      expect(p.canCompleteInWidget, false);
    });

    test('transition, focus complete -> on_track (done accent, no CTA)', () {
      final p = WidgetPayload.fromProfile(
        profile(
          focus: 'Ship the widget',
          focusDate: today,
          focusComplete: true,
          completions: const [
            DailyCompletion(date: today, journalCompleted: true)
          ],
        ),
        now: midday,
      );
      expect(p.state, 'on_track');
      expect(p.accentKind, 'done');
      expect(p.isDone, true);
      expect(p.canCompleteInWidget, false);
      expect(p.completedCount, 1);
    });

    test('evening, perfect day + focus complete -> on_track', () {
      final p = WidgetPayload.fromProfile(
        profile(
          focus: 'Ship the widget',
          focusDate: today,
          focusComplete: true,
          completions: [_perfect(today)],
        ),
        now: evening,
      );
      expect(p.state, 'on_track');
      expect(p.accentKind, 'done');
      expect(p.completedCount, 9);
      expect(p.totalCount, 9);
    });
  });

  group('WidgetPayload grace period (just-after-midnight day)', () {
    // 12:30 AM on the 28th still belongs to the 27th's "active day" (4 AM–4 AM),
    // so the prior evening's progress and focus must NOT reset at midnight.
    final justAfterMidnight = DateTime(2026, 6, 28, 0, 30);
    const priorDay = '2026-06-27';

    // Morning routine + evening affirmations done on the 27th, but the evening
    // journal is still outstanding (journalPreference 'evening').
    const inProgress = DailyCompletion(
      date: priorDay,
      habitsCompleted: true,
      dayPlanned: true,
      affirmationsMorning: true,
      affirmationsEvening: true,
      futureSelfCompleted: true,
      chatCompleted: true,
      identityRead: true,
    );

    test('keeps the prior day completion instead of resetting at midnight', () {
      final p = WidgetPayload.fromProfile(
        profile(
          journalPreference: 'evening',
          completions: const [inProgress],
        ),
        now: justAfterMidnight,
      );

      // Progress carries over from the 27th rather than reading as a fresh 0/8.
      expect(p.completedCount, inProgress.completedCount);
      expect(p.completedCount, greaterThan(0));
    });

    test('still on the evening session (journal) just after midnight', () {
      final p = WidgetPayload.fromProfile(
        profile(
          journalPreference: 'evening',
          completions: const [inProgress],
        ),
        now: justAfterMidnight,
      );

      expect(p.sessionPeriod, 'evening');
      expect(p.state, 'evening');
      expect(p.accentKind, 'evening');
      expect(p.actionField, 'journalCompleted');
      expect(p.sessionLabel, 'EVENING SESSION');
    });

    test('focus set on the prior day still counts as today after midnight', () {
      final p = WidgetPayload.fromProfile(
        profile(
          focus: 'Ship the widget',
          focusDate: priorDay,
          journalPreference: 'morning',
          completions: const [inProgress],
        ),
        now: justAfterMidnight,
      );

      expect(p.hasFocusToday, true);
      expect(p.focusText, 'Ship the widget');
    });
  });

  group('WidgetPayload session period + identity', () {
    test('morning hour -> morning period', () {
      final p = WidgetPayload.fromProfile(profile(), now: morning);
      expect(p.sessionPeriod, 'morning');
    });

    test('evening hour -> evening period', () {
      final p = WidgetPayload.fromProfile(profile(), now: evening);
      expect(p.sessionPeriod, 'evening');
    });

    test('first name derived from display name', () {
      final p = WidgetPayload.fromProfile(profile(), now: morning);
      expect(p.firstName, 'Jordan');
      expect(p.displayName, 'Jordan Smith');
    });
  });

  group('WidgetPayload 7-day streak chain', () {
    // A `DailyCompletion` with exactly 5 of 9 required wins — the streak
    // threshold (`countsForStreak == true`).
    DailyCompletion qualifying(String date) => DailyCompletion(
          date: date,
          habitsCompleted: true,
          dayPlanned: true,
          focusCompleted: true,
          journalCompleted: true,
          identityRead: true,
        );

    test('weekStreak is always 7 days, ending on today (index 6)', () {
      final p = WidgetPayload.fromProfile(
        profile(completions: [qualifying(today)]),
        now: midday,
      );
      expect(p.weekStreak.length, 7);
      expect(p.weekLabels.length, 7);
      // Today qualifies (5/9), so the final cell is filled.
      expect(p.weekStreak.last, true);
    });

    test('today not yet qualifying -> last cell false', () {
      final p = WidgetPayload.fromProfile(
        profile(
          completions: const [
            DailyCompletion(date: today, journalCompleted: true)
          ],
        ),
        now: midday,
      );
      expect(p.weekStreak.last, false);
    });

    test('caption switches on the 5/9 threshold', () {
      final safe = WidgetPayload.fromProfile(
        profile(completions: [qualifying(today)]),
        now: midday,
      );
      expect(safe.weekCaption, AppStrings.widgetStreakSafe);

      final inProgress = WidgetPayload.fromProfile(
        profile(
          completions: const [
            DailyCompletion(date: today, journalCompleted: true)
          ],
        ),
        now: midday,
      );
      expect(inProgress.weekCaption, contains(AppStrings.widgetStreakFinish));
      expect(inProgress.weekCaption, contains('1/9'));
    });

    test('a prior qualifying day fills its cell', () {
      final p = WidgetPayload.fromProfile(
        profile(completions: [qualifying('2026-06-25')]),
        now: midday,
      );
      // 2026-06-25 is two days before today (index 4 in a 7-day window).
      expect(p.weekStreak[4], true);
      expect(p.weekStreak.last, false); // today still empty
    });
  });

  group('WidgetPayload JSON round trip', () {
    test('encodes and decodes losslessly', () {
      final original = WidgetPayload.fromProfile(
        profile(focus: 'Ship the widget', focusDate: today),
        now: midday,
      );
      final restored = WidgetPayload.fromJson(original.toJson());
      expect(restored.state, original.state);
      expect(restored.focusText, original.focusText);
      expect(restored.hasFocusToday, original.hasFocusToday);
      expect(restored.sessionPeriod, original.sessionPeriod);
      expect(restored.completedCount, original.completedCount);
      expect(restored.firstName, original.firstName);
      expect(restored.actionField, original.actionField);
      expect(restored.sessionLabel, original.sessionLabel);
      expect(restored.headline, original.headline);
      expect(restored.subline, original.subline);
      expect(restored.accentKind, original.accentKind);
      expect(restored.canCompleteInWidget, original.canCompleteInWidget);
      expect(restored.deepLink, original.deepLink);
      expect(restored.weekStreak, original.weekStreak);
      expect(restored.weekLabels, original.weekLabels);
      expect(restored.weekCaption, original.weekCaption);
    });

    test('empty payload has sane defaults', () {
      final p = WidgetPayload.empty(now: morning);
      expect(p.state, 'set_focus');
      expect(p.accentKind, 'set_focus');
      expect(p.totalCount, DailyCompletion.totalCount);
      expect(p.streak, 0);
      expect(p.deepLink, 'mindsetforge://focus');
    });
  });
}
