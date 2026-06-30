import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../models/user_profile.dart';
import '../../../models/daily_completion.dart';
import '../../../providers/affirmations_provider.dart';
import '../../../providers/daily_completion_provider.dart';
import '../../mindset/affirmations_tab.dart';
import 'evidence_log_widget.dart';
import 'gratitude_log_widget.dart';
import 'plan_day_bottom_sheet.dart';

// ── Win item descriptor ───────────────────────────────────────────────────────

/// A single daily-win checklist item. Shared by the dashboard hero card and the
/// daily routine card so both render and resolve the same set of actions.
class WinItem {
  final String field;
  final String label;
  final String subtitle;
  final IconData icon;
  final bool isBonus;
  // When true: completion status is read-only (no manual checkbox tap)
  final bool sessionOnly;

  const WinItem(
    this.field,
    this.label,
    this.subtitle,
    this.icon, {
    this.isBonus = false,
    this.sessionOnly = false,
  });
}

const morningWins = [
  WinItem('identityRead', 'Identity', 'Read who you\'re becoming', Icons.person_outline_rounded),
  WinItem('affirmationsMorning', 'Affirmations', 'Start Day', Icons.wb_sunny_outlined, sessionOnly: true),
  WinItem('futureSelfCompleted', 'Future Self', 'Practice', Icons.auto_awesome_rounded),
  WinItem('journalCompleted', 'Journal', 'Prime Mind', Icons.edit_note_rounded),
  WinItem('dayPlanned', 'Plan Day', 'Select Focus', Icons.check_circle_outline_rounded),
  WinItem('gratitudeLogged', 'Gratitude', 'Something you\'re grateful for', Icons.favorite_border_rounded, isBonus: true),
];

const eveningWins = [
  WinItem('affirmationsEvening', 'Affirmations', 'End Day', Icons.nightlight_round, sessionOnly: true),
  // Habits live in their own DailyHabitsCard below the tracker. The
  // `habitsCompleted` flag is auto-derived in HabitsNotifier and still counts
  // toward the streak / perfect day.
  WinItem('chatCompleted', 'Coach Chat', 'Check In', Icons.chat_bubble_outline_rounded),
  WinItem('evidenceLogged', 'Evidence Log', 'Act like your future self', Icons.emoji_events_outlined, isBonus: true),
];

/// Canonical list of the required daily wins (field, label) that make up a
/// perfect day, in routine order. Single source of truth for explainer UIs so
/// the "what counts" sheet never drifts from [DailyCompletion.isPerfectDay].
const requiredWinSummary = <(String, String)>[
  ('identityRead', 'Read your identity'),
  ('affirmationsMorning', 'Morning affirmations'),
  ('futureSelfCompleted', 'Future Self practice'),
  ('journalCompleted', 'Journal'),
  ('dayPlanned', 'Plan day — pick your #1 focus'),
  ('focusCompleted', 'Complete your #1 focus'),
  ('habitsCompleted', 'Daily habits'),
  ('affirmationsEvening', 'Evening affirmations'),
  ('chatCompleted', 'Coach check-in'),
];

// ── Field access helpers ──────────────────────────────────────────────────────

/// Reads the boolean completion flag for [field] off a [DailyCompletion].
bool getCompletionField(DailyCompletion c, String field) {
  return switch (field) {
    'habitsCompleted' => c.habitsCompleted,
    'dayPlanned' => c.dayPlanned,
    'focusCompleted' => c.focusCompleted,
    'priorityActionsCompleted' => c.priorityActionsCompleted,
    'affirmationsMorning' => c.affirmationsMorning,
    'affirmationsEvening' => c.affirmationsEvening,
    'futureSelfCompleted' => c.futureSelfCompleted,
    'journalCompleted' => c.journalCompleted,
    'chatCompleted' => c.chatCompleted,
    'identityRead' => c.identityRead,
    'gratitudeLogged' => c.gratitudeLogged,
    'evidenceLogged' => c.evidenceLogged,
    _ => false,
  };
}

/// First item in [items] whose completion flag is still false, or null.
WinItem? firstIncomplete(DailyCompletion c, List<WinItem> items) {
  for (final w in items) {
    if (!getCompletionField(c, w.field)) return w;
  }
  return null;
}

/// Toggles a daily-win flag. Affirmation fields are session-driven and ignored.
void toggleField(WidgetRef ref, String field, bool currentValue) {
  if (field == 'affirmationsMorning' || field == 'affirmationsEvening') return;
  ref.read(dailyCompletionProvider.notifier).toggle(field, !currentValue);
}

/// Best (longest) historical streak across all recorded daily completions.
int bestStreak(List<DailyCompletion> completions) {
  if (completions.isEmpty) return 0;
  final sorted = [...completions]..sort((a, b) => a.date.compareTo(b.date));
  int best = 0;
  int current = 0;
  DateTime? prev;

  for (final c in sorted) {
    if (!c.countsForStreak) {
      current = 0;
      prev = null;
      continue;
    }
    final parts = c.date.split('-');
    final date = DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
    if (prev == null || date.difference(prev).inDays == 1) {
      current++;
    } else {
      current = 1;
    }
    if (current > best) best = current;
    prev = date;
  }
  return best;
}

// ── Navigation / sheet launchers ──────────────────────────────────────────────

/// Builds the tap callback for a given win [field] — navigation or a bottom
/// sheet. Shared so the hero card and routine rows route identically.
VoidCallback winNavCallback({
  required BuildContext context,
  required WidgetRef ref,
  required UserProfile profile,
  required String field,
}) {
  return switch (field) {
    'identityRead' => () => showIdentitySheet(context, profile),
    'affirmationsMorning' => () {
        final active =
            ref.read(affirmationsProvider).where((a) => a.isActive).toList();
        if (active.isEmpty) {
          context.push('/affirmations');
        } else {
          launchAffirmationSession(
            context: context,
            ref: ref,
            affirmations: active,
            sessionType: 'morning',
          );
        }
      },
    'affirmationsEvening' => () {
        final active =
            ref.read(affirmationsProvider).where((a) => a.isActive).toList();
        if (active.isEmpty) {
          context.push('/affirmations');
        } else {
          launchAffirmationSession(
            context: context,
            ref: ref,
            affirmations: active,
            sessionType: 'evening',
          );
        }
      },
    'futureSelfCompleted' => () => context.push('/future-self'),
    'journalCompleted' => () => context.go('/journal/new'),
    'dayPlanned' => () => showPlanDaySheet(context, ref, profile),
    'habitsCompleted' => () => context.go('/actions?tab=habits'),
    'chatCompleted' => () => context.go('/chat'),
    'gratitudeLogged' => () => showModalBottomSheet(
          context: context,
          backgroundColor: AppColors.surface,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppSpacing.radiusXl),
            ),
          ),
          builder: (_) => GratitudeLogWidget(profile: profile),
        ),
    'evidenceLogged' => () => showEvidenceLogSheet(context, profile),
    _ => () {},
  };
}

/// Explains what counts toward a perfect day: lists every required win with its
/// current completion state and flags the #1 focus as the key action. Opened
/// from the dashboard momentum strip so "what's required" is never a mystery.
void showDailyWinsInfoSheet(BuildContext context, DailyCompletion completion) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppSpacing.radiusXl),
      ),
    ),
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.md,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(AppStrings.dailyWinsInfoTitle,
                style: AppTextStyles.headlineSmall),
            const SizedBox(height: AppSpacing.xs),
            Text(
              AppStrings.dailyWinsInfoBody,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary, height: 1.5),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              '${completion.completedCount} / ${DailyCompletion.totalCount} done today',
              style:
                  AppTextStyles.labelSmall.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final win in requiredWinSummary)
              _DailyWinInfoRow(
                label: win.$2,
                done: getCompletionField(completion, win.$1),
                isFocus: win.$1 == 'focusCompleted',
              ),
          ],
        ),
      ),
    ),
  );
}

class _DailyWinInfoRow extends StatelessWidget {
  final String label;
  final bool done;
  final bool isFocus;

  const _DailyWinInfoRow({
    required this.label,
    required this.done,
    required this.isFocus,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Icon(
            done
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 20,
            color: done ? AppColors.success : AppColors.textMuted,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.bodyMedium.copyWith(
                color: done ? AppColors.textPrimary : AppColors.textSecondary,
              ),
            ),
          ),
          if (isFocus)
            const Icon(Icons.star_rounded,
                size: 16, color: AppColors.primary),
        ],
      ),
    );
  }
}

/// Opens the Evidence Log bottom sheet. Shared so the daily-win row and the
/// on-track hero's embodiment trait open it identically.
void showEvidenceLogSheet(BuildContext context, UserProfile profile) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppSpacing.radiusXl),
      ),
    ),
    builder: (_) => EvidenceLogWidget(profile: profile),
  );
}

/// Bottom sheet showing the user's identity statement with a read-confirm CTA.
void showIdentitySheet(BuildContext context, UserProfile profile) {
  showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppSpacing.radiusXl),
      ),
    ),
    builder: (sheetCtx) => Consumer(
      builder: (sheetCtx, sheetRef, _) {
        final completion = sheetRef.watch(dailyCompletionProvider);
        final alreadyRead = completion.identityRead;

        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (_, scrollCtrl) => SingleChildScrollView(
            controller: scrollCtrl,
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                const Icon(
                  Icons.person_outline_rounded,
                  color: AppColors.primary,
                  size: 48,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Your Identity', style: AppTextStyles.headlineMedium),
                const SizedBox(height: AppSpacing.lg),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    profile.identityStatement.isNotEmpty
                        ? profile.identityStatement
                        : 'No identity statement set yet.',
                    style: AppTextStyles.headlineSmall.copyWith(
                      fontStyle: FontStyle.italic,
                      height: 1.8,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Read this slowly. Let it sink in. This is who you are.',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xxl),
                if (!alreadyRead)
                  SizedBox(
                    width: double.infinity,
                    height: AppSpacing.buttonHeight,
                    child: ElevatedButton(
                      onPressed: () {
                        sheetRef
                            .read(dailyCompletionProvider.notifier)
                            .toggle('identityRead', true);
                        Navigator.pop(sheetCtx);
                      },
                      child: const Text('Done — I\'ve read this'),
                    ),
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Identity read for today',
                        style: AppTextStyles.labelLarge
                            .copyWith(color: AppColors.primary),
                      ),
                    ],
                  ),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        );
      },
    ),
  );
}
